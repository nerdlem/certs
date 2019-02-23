#!/bin/bash
#
# tlsa-auto-deploy.sh -- Generate TLSA records and automatically deploy them
# to selected DNS zones.
#
# © 2019 Luis E. Muñoz -- All Rights Reserved

set -e
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin

# Configuration parameters / where to find tools

LOGGER=${LOGGER:=/usr/bin/logger}
NSUPDATE=${NSUPDATE:=`which nsupdate`}
OPENSSL=${OPENSSL:=`which openssl`}
SHA512=${SHA512:=`which sha512sum`}

MASTER=${MASTER:=}
TSIGKEYFILE=${TSIGKEYFILE:=~/mykey.conf}
TTL=${TTL:=86400}

PUBKEYS=${PUBKEYS:=}
PORT=${PORT:=*}

LOGGER_OPTS=${LOGGER_OPTS:=-p local3.info -t tlsa-auto-deploy}
NSUPDATE_OPTS=${NSUPDATE_OPTS:=}

function check_prerreq {
  tool=$1
  binary=$2
  msg=$3

  if [ ! -x "${binary}" ]; then
    echo ${tool} missing
    if [ "${msg}" = "" ]; then
      echo "  Please install ${binary} or provide its location via environment variables"
    else
      echo "  ${msg}"
    fi

    missing=1
  fi
}

function add_tlsa_records {
  domain=$1
  if [ "${MASTER}" == "" ]; then
    ${LOGGER} ${LOGGER_OPTS} "Add TLSA records for ${domain}"
  else
    ${LOGGER} ${LOGGER_OPTS} "Add TLSA records for ${domain} with master ${MASTER}"
  fi

  if [ "${PORT}" == "*" ]; then
    portspec=${PORT}._tcp
  else
    portspec=_${PORT}._tcp
  fi

  if (
    [ "${MASTER}" == "" ] || echo "server ${MASTER}";
    for pk in ${PUBKEYS}; do
      hash=`( ${OPENSSL} rsa -pubin -in "${pk}" -outform DER \
      | ${SHA512} | awk '{ print $1 }' ) 2>/dev/null`;
      echo "update add ${portspec}.${domain}. ${TTL} TLSA 3 1 2 ${hash}";
    done;
    echo send
  ) | tee /tmp/commands | "${NSUPDATE}" -k "${TSIGKEYFILE}" ${NSUPDATE_OPTS}
  then
    ${LOGGER} ${LOGGER_OPTS} "TLSA record for ${domain}/${portspec} added successfully"
  else
    ${LOGGER} ${LOGGER_OPTS} "failed to add TLSA record for ${domain}/${portspec}"
    exit 255
  fi
}

check_prerreq nsupdate     "${NSUPDATE}"
check_prerreq openssl      "${OPENSSL}"
check_prerreq sha512sum    "${SHA512}"

if [ "${PUBKEYS}" == "" ]; then
  cat <<__EOF__
Prerequisites seem to be present and in order, however this program requires
that public keys be supplied via the PUBKEYS environment variable.
__EOF__
  exit 1
fi

if [ "${missing}" != "" ]; then
  echo "Missing prerequisites prevent execution. Please correct the issue."
  exit 2
fi

for domain in $*; do
  add_tlsa_records "${domain}"
done

exit 0
