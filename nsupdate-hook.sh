#!/bin/bash

# nsupdate-auth-hook.sh -- This is an authentication hook for #certbot that
# performs DNS-01 chanllenge authentication via RFC-2136 dynamic #updates
# managed via the nsupdate tool.
#
# © 2017-2022 Luis E. Muñoz -- All Rights Reserved

set -e
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin

# Configuration parameters / where to find tools

DIG=${DIG:=/usr/bin/dig}
GREP=${GREP:=/bin/grep}
LOGGER=${LOGGER:=/usr/bin/logger}
NSUPDATE=${NSUPDATE:=`which nsupdate`}

PROXY_MODE=${PROXY_MODE:=''}

DIG_OPTS=${DIG_OPTS:=+noidnout}
LOGGER_OPTS=${LOGGER_OPTS:=-p local3.info -t nsupdate-hook}
NSUPDATE_OPTS=${NSUPDATE_OPTS:=}
LEROOT=${LEROOT:=/etc/letsencrypt}

if [ -f "${LEROOT}/proxy/domain/${CERTBOT_DOMAIN}" ]; then
  CHALLENGE_DOMAIN=$(cat -- "${LEROOT}/proxy/domain/${CERTBOT_DOMAIN}" )
  PROXY_MODE='domain'
else
  CHALLENGE_DOMAIN=${CHALLENGE_DOMAIN:=${CERTBOT_DOMAIN}}
fi

if [ "${PROXY_MODE}" = "domain" ]; then
  CHALLENGE=${CHALLENGE:=_acme-challenge.${CERTBOT_DOMAIN}.${CHALLENGE_DOMAIN}}
else
  CHALLENGE=${CHALLENGE:=_acme-challenge.${CHALLENGE_DOMAIN}}
fi

FOREIGNNS=${FOREIGNNS:=8.8.8.8}
MASTER=${MASTER:=}
AUTHNS=${AUTHNS:=}
SLEEPSECS=${SLEEPSECS:=5}
TSIGKEYFILE=${TSIGKEYFILE:=~/mykey.conf}
TTL=${TTL:=2}

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
      echo "  ${msg}"
    fi

    missing=1
  fi
}

check_prerreq dig      "${DIG}"
check_prerreq grep     "${GREP}"
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

function perform_cleanup {
  ${LOGGER} ${LOGGER_OPTS} "cleanup ${CHALLENGE} ${CERTBOT_VALIDATION}"
  if (  [ "${MASTER}" == "" ] || echo "server ${MASTER}";
    echo "update delete ${CHALLENGE} TXT \"${CERTBOT_VALIDATION}\"";
    echo send
  ) | ${NSUPDATE} -k "${TSIGKEYFILE}" ${NSUPDATE_OPTS}
  then
    ${LOGGER} ${LOGGER_OPTS} "removal of ${CHALLENGE} ${CERTBOT_VALIDATION} successful"
    if [ "${VERBOSE}" == "" ]; then
      echo Removed challenge ${CHALLENGE}
    fi
  else
    ${LOGGER} ${LOGGER_OPTS} "failed removal of ${CHALLENGE} ${CERTBOT_VALIDATION}"
    echo Failed to remove challenge ${CHALLENGE}
  fi
}

function verify_authorization {
  domain=$1
  token=$2

  nslist="/tmp/nslist-$$"
  rm -f "${nslist}"

  [ "${FOREIGNNS}" == "" ] || ( echo "${FOREIGNNS}" > "${nslist}" )
  [ "${AUTHNS}" == "" ] || ( echo "${AUTHNS}" | tr , '\n' >> "${nslist}" )

  ${DIG} ${DIG_OPTS} +noall +answer NS "${CHALLENGE_DOMAIN}" \
    | egrep '\WNS\W' \
    | awk '{ print $5 }' \
    | sed 's/\.+$//' >> "${nslist}"

  sort -i "${nslist}" -o "${nslist}" -u

  for ns in `cat "${nslist}"`; do
    if ${DIG} ${DIG_OPTS} +short IN TXT ${CHALLENGE} @${ns} | ${GREP} -F -- "${token}" > /dev/null
    then
      ${LOGGER} ${LOGGER_OPTS} "validation of ${CHALLENGE} ${token} via ${ns} successful"
      if [ "${VERBOSE}" == "" ]; then
        echo "Validation of ${CHALLENGE} via ${ns} was successful"
      fi
    else
      ${LOGGER} ${LOGGER_OPTS} "failed validation of ${CHALLENGE} ${token} via ${ns}"
      echo "Failed validation for ${CHALLENGE} -- retrying"
      rm -f "${nslist}"
      sleep 1
      return 255
    fi
  done

  rm -f "${nslist}"
  return 0
}

function perform_authorization {
  if [ "${MASTER}" == "" ]; then
    ${LOGGER} ${LOGGER_OPTS} "initialize challenge ${CHALLENGE} ${CERTBOT_VALIDATION}"
  else
    ${LOGGER} ${LOGGER_OPTS} "initialize challenge ${CHALLENGE} ${CERTBOT_VALIDATION} with master ${MASTER}"
  fi

  if (
    [ "${MASTER}" == "" ] || echo "server ${MASTER}";
    echo "update add ${CHALLENGE} ${TTL} TXT \"${CERTBOT_VALIDATION}\"";
    echo send
  ) | "${NSUPDATE}" -k "${TSIGKEYFILE}" ${NSUPDATE_OPTS}
  then
    ${LOGGER} ${LOGGER_OPTS} "challenge ${CHALLENGE} ${CERTBOT_VALIDATION} added successfully"
    if [ "${VERBOSE}" == "" ]; then
      echo Added challenge ${CHALLENGE}
    fi

    while ! verify_authorization "${CERTBOT_DOMAIN}" "${CERTBOT_VALIDATION}"; do
      ${LOGGER} ${LOGGER_OPTS} "retry verification of ${CHALLENGE} ${CERTBOT_VALIDATION}"
      sleep ${SLEEPSECS};
    done

  else
    ${LOGGER} ${LOGGER_OPTS} "failed to add challenge ${CHALLENGE} ${CERTBOT_VALIDATION}"
    echo Failed to add challenge ${CHALLENGE}
    exit 255
  fi
}

${LOGGER} ${LOGGER_OPTS} "domain=${CERTBOT_DOMAIN} validation=${CERTBOT_VALIDATION}"

if [ "${CERTBOT_AUTH_OUTPUT}" == "" ]; then
  perform_authorization
else
  perform_cleanup
fi

exit 0;
