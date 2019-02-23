#!/bin/bash
#
# add-tlsa.sh -- Run periodically to ensure TLSA records are in place
#
# © 2019 Luis E. Muñoz -- All Rights Reserved

TTL=2592000 \
PUBKEYS=/etc/letsencrypt/seed/lem.click/cert-*.pub \
tlsa-auto-deploy.sh lem.click lem.link lem.sexy
