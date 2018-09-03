#!/bin/bash

# nsupdate-auth-hook.sh -- This is an authentication hook for #certbot that
# performs DNS-01 chanllenge authentication via RFC-2136 dynamic #updates
# managed via the nsupdate tool.
#
# © 2017-2018 Luis E. Muñoz -- All Rights Reserved

set -e
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin

# Configuration parameters / where to find tools

NSUPDATE=${NSUPDATE:=`which nsupdate`}
NSUPDATE_OPTS=${NSUPDATE_OPTS:=}
TSIGKEYFILE=${TSIGKEYFILE:=~/mykey.conf}
MASTER=${MASTER:=}

# Prerequisite checking code below

missing=''

function check_prerreq {
  tool=$1
  binary=$2
  msg=$3

  if [ ! -x "${binary}" ]; then
    echo ${tool} missing
    if [ "${msg}" = "" ]; then
      echo "  Please install ${binary} or provide its location via environment variables"
    else
      echo "  " ${msg}
    fi

    missing=1
  fi
}

check_prerreq nsupdate "${NSUPDATE}"

if [ ! -f "${TSIGKEYFILE}" ]; then
  echo "Please use env variable TSIGKEYFILE to specify the TSIG key to use for NS updates"
fi

if [ "${CERTBOT_DOMAIN}" == "" ]; then
  cat <<__EOF__
Prerequisites seem to be present and in order, however this program should
be invoked as a certbot hook, via the --manual-auth-hook and --manual-cleanup-hook
command line options.
__EOF__
  exit 1
fi

if [ "${missing}" != "" ]; then
  echo "Missing prerequisites prevent execution. Please correct the issue."
  exit 2
fi

challenge="_acme-challenge.${CERTBOT_DOMAIN}"

function perform_cleanup {
  (  [ "${MASTER}" == "" ] || echo "server ${MASTER}";
    echo "update delete ${challenge} ${TXT}";
    echo send
  ) | "${NSUPDATE}" -k "${TSIGKEYFILE}" ${NSUPDATE_OPTS}
}

function perform_authorization {
    (
      [ "${MASTER}" != "" ] || echo "server ${MASTER}";
      echo "update add ${challenge} 0 TXT ${CERTBOT_VALIDATION}";
      echo send
    ) | "${NSUPDATE}" -k "${TSIGKEYFILE}" ${NSUPDATE_OPTS}
}

if [ "${CERTBOT_AUTH_OUTPUT}" == "" ]; then
  perform_authorization
else
  perform_cleanup
fi

exit 0;
