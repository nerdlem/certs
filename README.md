# Filesystem hierarchy for certificate management

This is the file layout I use to manage key material for X.509 certificate management. You should keep these files in a secure computer separate from the servers where you intend to use your certificates. Remember that compromising your private keys is worse than accidentally posting your password online.

The underlying rules in the Makefiles are based in GnuTLS. For this application there's really not much of a difference with OpenSSL. My choice was based on how easy is to configure the resulting CSRs.

Please see these posts for more information on how I use this:

* [Wildcard certificates with Let's Encrypt](https://lem.click/post/wildcard-certificates-with-letsencrypt/)
* [Certificate Rotation with Let's Encrypt](https://lem.click/post/certificate-rotation-with-letsencrypt/)
* [Multiple certs with Certbot](https://lem.click/post/multiple-certs-with-certbot/)

Each domain name for which you intend to have a certificate, should have a directory containing a template file and a symlink to `Makefile.sub`. Do something like this:

```
./bootstrap.sh my.domain
```

Then, edit the file `my.domain/template.conf` to customize the parameters of your certificate. Finally, use `make`:

```
$ make
make -C my-domain
gnutls-certtool --generate-privkey --outfile cert-0.key
Generating a 3072 bit RSA private key...
gnutls-certtool --load-privkey cert-0.key --pubkey-info --outfile cert-0.pub
gnutls-certtool --generate-request --load-privkey cert-0.key --template template.conf --outfile cert-0.csr
Generating a PKCS #10 certificate request...
gnutls-certtool --generate-privkey --outfile cert-1.key
Generating a 3072 bit RSA private key...
gnutls-certtool --load-privkey cert-1.key --pubkey-info --outfile cert-1.pub
gnutls-certtool --generate-request --load-privkey cert-1.key --template template.conf --outfile cert-1.csr
   ⋮
```

After a few seconds, you should have 4 groups of CSRs, public and private keys suitable for use with any SSL / TLS application.

Key parameters can be tweaked in the `Makefile.sub` file. You can have multiple directory names representing multiple domains. This is useful to keep all your keys on a single location.

With a suitable SSH configuration, you can easily upload the required material to your server as follows. You might want to review the note on filesystem permissions prior to running this command.

```
make HOST=my.server.name upload
   ⋮
/usr/bin/rsync -avPR               \
		./lem.click/cert-0.* ⋯   \
		./lem.click/cert-?.pub ⋯ \
		root@my.server.name:/etc/letsencrypt/seed/
building file list ...
   ⋮
lem.click/
lem.click/cert-0.csr
        4372 100%    4.17MB/s    0:00:00 (xfer#7, to-check=33/45)
lem.click/cert-0.key
        8399 100%    8.01MB/s    0:00:00 (xfer#8, to-check=32/45)
lem.click/cert-0.pub
        2237 100%    2.13MB/s    0:00:00 (xfer#9, to-check=31/45)
lem.click/cert-1.pub
        2237 100%    2.13MB/s    0:00:00 (xfer#10, to-check=29/45)
lem.click/cert-2.pub
        2237 100%    2.13MB/s    0:00:00 (xfer#11, to-check=28/45)
lem.click/cert-3.pub
        2237 100%    1.07MB/s    0:00:00 (xfer#12, to-check=27/45)
```

After uploading, it's a good idea to go over the services using your certificates to ensure everything is in order. Keep in mind that many services need to be fully restarted when updating key material.

# Safekeeping your key material

The supplied `Makefile` includes targets `preserve` and `save-keys` that will assist in producing encrypted backups of your key material, for safekeeping. Note the setting of `GPGRECIPIENT` to select the GPG key to encrypt your backup to.

```
make GPGRECIPIENT=lem@lem.click preserve
make -C lem.click
make[1]: Nothing to be done for 'all'.
tar cf - ./lem.click/cert-*.key \
		| gpg --encrypt --armor --recipient lem@lem.click > privkeys.tar.gpg \
		|| exit 255
⋮

Keep the privkeys.tar.gpg in a safe place. This file contains the
private keys for all of your certificates. If you lose or compromise
this file, certificates based in these keys will no longer be secure.
```

You should now store the resulting `.gpg` file in a safe place, in case that the key material needs to be restored for any purpose, or keys need to be revoked. This is a very important – and often neglected – step.

# Clearing pre-existing ACME challenges

To assist with DNS zone hygiene, the included `clear-well-known.sh` script will delete all existing TXT DNS records under the `_acme-challenge` subdomain with configuration under `/etc/letsencrypt/seed`.

This is generally not required for installations that do not use the `dns-01` challenge. However I tend to prefer this because I tend to centrally manage my certificates. I also like wildcard certificates for many scenarios, something that currently cannot be done using the more typical `http-01` challenge.

# Selective ACME dns-01 proxy authentication

I have to deal with domain names that are served directly as well as domains served from third party authoritative DNS servers that do not support dynamic updates. In order to generate wildcard certificates for those domain names, `nsupdate-hook.sh` allows for specifying per-domain `$CHALLENGE_DOMAIN` names.

Setting the required `CNAME` record as described in [Wildcard certificates with Let's Encrypt](https://lem.click/post/wildcard-certificates-with-letsencrypt/) and placing the correct `$CHALLENGE_DOMAIN` value as the contents of the `/etc/letsencrypt/proxy/domain/$CERTBOT_DOMAIN` causes `nsupdate-hook.sh` to automatically perform updates that will satisfy the authentication requirements to issue wildcard certificates.

# Note on directory permissions

For the various environments I use, I tend to use symlinks so that different processes running under different identities can read the private keys as needed. My setup can look as follows, with each service typically having its own set of links so as to minimize changes to config files.

```
/etc/foo/tls/private.key ➜ /etc/letsencrypt/live/lem.click/privkey.pem
/etc/letsencrypt/live/lem.click/privkey.pem ➜ /etc/letsencrypt/seed/lem.click/cert-0.key
```

Prior to uploading the key material, I setup the `seed` directory on my `/etc/letsencrypt` hierarchy with default ACL entries, so that any created files will inherit the required permissions.

```bash
mkdir /etc/letsencrypt/seed
setfacl -b /etc/letsencrypt/seed
setfacl -d -m g:certs:rx                  /etc/letsencrypt/seed/
setfacl -d -m u:dovecot:rx,g:dovecot:rx   /etc/letsencrypt/seed/
setfacl -d -m u:mail:rx,g:mail:rx         /etc/letsencrypt/seed/
setfacl -d -m u:postgres:rx,g:postgres:rx /etc/letsencrypt/seed/
setfacl -d -m u:smmsp:rx,g:smmsp:rx       /etc/letsencrypt/seed/
setfacl -d -m u:smmta:rx,g:smmta:rx       /etc/letsencrypt/seed/
setfacl -d -m u:www-data:rx,g:www-data:rx /etc/letsencrypt/seed/
```

This setup minimizes the amount of changes required when restarting services, as all required processes will be able to read the certificate keys as required.

# Domain inventory

You can compile a domain catalog file which is helpful to identify domain
names being managed by underlying CSR files.

```
make domain-catalog.csv
⋮
```

The resulting `domain-catalog.csv` file will contain a CSV listing summarizing
the domains produced by each domain directory.