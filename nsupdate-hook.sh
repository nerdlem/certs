#!/bin/bash

# nsupdate-auth-hook.sh -- This is an authentication hook for #certbot that
# performs DNS-01 chanllenge authentication via RFC-2136 dynamic #updates
# managed via the nsupdate tool.
#
# © 2017-2018 Luis E. Muñoz -- All Rights Reserved

set -e
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin

# Configuration parameters / where to find tools

DIG=${DIG:=/usr/bin/dig}
GREP=${GREP:=/bin/grep}
MASTER=${MASTER:=}
NSUPDATE_OPTS=${NSUPDATE_OPTS:=}
NSUPDATE=${NSUPDATE:=`which nsupdate`}
TSIGKEYFILE=${TSIGKEYFILE:=~/mykey.conf}
FOREIGNNS=${FOREIGNNS:=8.8.8.8}
TTL=${TTL:=5}

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

challenge="_acme-challenge.${CERTBOT_DOMAIN}"

function perform_cleanup {
  if (  [ "${MASTER}" == "" ] || echo "server ${MASTER}";
    echo "update delete ${challenge} ${TXT}";
    echo send
  ) | "${NSUPDATE}" -k "${TSIGKEYFILE}" ${NSUPDATE_OPTS}
  then
    if [ "${VERBOSE}" == "" ]; then
      echo Removed challenge ${challenge}
    fi
  else
    echo Failed to remove challenge ${challenge}
  fi
}

function perform_authorization {
  if (
    [ "${MASTER}" == "" ] || echo "server ${MASTER}";
    echo "update add ${challenge} ${TTL} TXT ${CERTBOT_VALIDATION}";
    echo send
  ) | "${NSUPDATE}" -k "${TSIGKEYFILE}" ${NSUPDATE_OPTS}
  then
    if [ "${VERBOSE}" == "" ]; then
      echo Added challenge ${challenge}
    fi

    while :; do
      if ${DIG} +short IN TXT ${challenge} @${FOREIGNNS} | ${GREP} "${CERTBOT_VALIDATION}" > /dev/null; then
        if [ "${VERBOSE}" == "" ]; then
          echo "Validation of ${challenge} was successful"
        fi
        return
      else
        echo "Failed validation for ${challenge} -- retrying"
        sleep 1;
      fi
    done

  else
    echo Failed to add challenge ${challenge}
    exit 255
  fi
}

if [ "${CERTBOT_AUTH_OUTPUT}" == "" ]; then
  perform_authorization
else
  perform_cleanup
fi

exit 0;
