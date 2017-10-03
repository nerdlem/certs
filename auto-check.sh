#!/bin/bash
#
# auto-check.sh -- automatically check and report certificate expiration
#
# © 2017 Luis E. Muñoz -- All Rights Reserved

set -e

export SSLCERTCHECK=${SSLCERTCHECK:=/usr/bin/ssl-cert-check}
export LEROOT=${LEROOT:=/etc/letsencrypt}
export LIVEPATH=${LIVEPATH:=${LEROOT}/live}
export SEEDFILE=${SEEDFILE:=`mktemp`}
export MINDAYS=${MINDAYS:=30}

find ${LIVEPATH} -mindepth 1 -maxdepth 1 \
  | sed -e 's,^.*/,,' -e 's,$, 443,' > ${SEEDFILE}

${SSLCERTCHECK} -x ${MINDAYS} -f ${SEEDFILE} -q -a -e certificates@lem.click
