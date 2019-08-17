#!/bin/bash
#
# bootstrap.sh -- provide a new blank directory for certificate processing

# © 2018 Luis E. Muñoz -- All Rights Reserved

CERT_ORG=${CERT_ORG:=Default organization}
CERT_OU=${CERT_OU:=Default organizational unit}
CERT_STATE=${CERT_STATE:=Default state}
CERT_COUNTRY=${CERT_COUNTRY:=Default country}

for domain in "$@"; do
  mkdir "${domain}"
  ( cd "${domain}"; ln -s ../Makefile.sub Makefile )
  cat <<__TEMPLATE__ > "${domain}/template.conf"
# DN options
organization = "${CERT_ORG}"
unit         = "${CERT_OU}"
state        = "${CERT_STATE}"
country      = "${CERT_COUNTRY}"
cn           = "${domain}"

# X.509 v3 extensions

# DNS name(s) of the server
dns_name = "${domain}"
dns_name = "*.${domain}"

# (Optional) Server IP address
#ip_address = "192.168.1.1"

# Whether this certificate will be used for a TLS server
tls_www_server

# Whether this certificate will be used to encrypt data (needed
# in TLS RSA ciphersuites). Note that it is preferred to use different
# keys for encryption and signing.
encryption_key

__TEMPLATE__

  cat <<__ADDTLSA__ > "${domain}/add-tlsa.sh"
#!/bin/bash
#
# add-tlsa.sh -- Run periodically to ensure TLSA records are in place

# Start with a short TTL for testing. After all is ok, increase the TTL.
# Additional domains can be appended below.

TTL=60 \\
PUBKEYS=/etc/letsencrypt/seed/${domain}/cert-*.pub \\
tlsa-auto-deploy.sh ${domain}
__ADDTLSA__
done

chmod +x "${domain}/add-tlsa.sh"

