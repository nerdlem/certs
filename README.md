# Certificate hierarchy

This is the file layout I use to manage key material for X509 certificate management. You should keep these files in a secure computer separate from the servers where you intend to use your certificates. Remember that compromising your private keys is worse than accidentally posting your password online.

The underlying rules in the Makefiles are based in GnuTLS. For this application there's really not much of a difference with OpenSSL. My choice was based on how easy is to configure the resulting CSRs.

Please see these posts for more information on how I use this:

* [Wildcard certificates with Let's Encrypt](https://lem.click/post/wildcard-certificates-with-letsencrypt/)
* [Certificate Rotation with Let's Encrypt](https://lem.click/post/certificate-rotation-with-letsencrypt/)
* [Multiple certs with Certbot](https://lem.click/post/multiple-certs-with-certbot/)

Each domain name for which you intent to have a certificate, should have a directory containing a template file and a symlink to `Makefile.sub`. Do something like this:

```bash
$ mkdir my.domain
$ rsync -avP ./lem.click/ ./my-domain/
   ⋮
```

Then, edit the file `my.domain/template.conf` to customize the parameters of your certificate. Finally, use `make`:

```bash
$ make
make -C my-domain
/usr/local/bin/gnutls-certtool --generate-privkey --outfile cert-0.key
Generating a 3072 bit RSA private key...
/usr/local/bin/gnutls-certtool --load-privkey cert-0.key --pubkey-info --outfile cert-0.pub
/usr/local/bin/gnutls-certtool --generate-request --load-privkey cert-0.key --template template.conf --outfile cert-0.csr
Generating a PKCS #10 certificate request...
/usr/local/bin/gnutls-certtool --generate-privkey --outfile cert-1.key
Generating a 3072 bit RSA private key...
/usr/local/bin/gnutls-certtool --load-privkey cert-1.key --pubkey-info --outfile cert-1.pub
/usr/local/bin/gnutls-certtool --generate-request --load-privkey cert-1.key --template template.conf --outfile cert-1.csr
   ⋮
```

After a few seconds, you should have 4 groups of CSRs, public and private keys suitable for use with any SSL / TLS application.

Key parameters can be tweaked in the `Makefile.sub` file. You can have multiple directory names representing multiple domains. This is useful to keep all your keys on a single location.

With a suitable SSH configuration, you can easily upload the required material to your server as follows:

```bash
make HOST=my.server.name upload
   ⋮
/usr/bin/rsync -avPR               \
		./lem.click/cert-0.* ⋯   \
		./lem.click/cert-?.pub ⋯ \
		root@background:/etc/letsencrypt/seed/
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

# Safekeeping your key material

The supplied `Makefile` includes targets `preserve` and `save-keys` that will assist in producing encrypted backups of your key material, for safekeeping. Note the setting of `GPGRECIPIENT` to select the GPG key to encrypt your backup to.

```bash
make GPGRECIPIENT=lem@lem.click preserve
/Applications/Xcode.app/Contents/Developer/usr/bin/make -C lem.click
make[1]: Nothing to be done for 'all'.
tar cf - ./lem.click/cert-*.key \
		| gpg --encrypt --armor --recipient lem@lem.click > privkeys.tar.gpg \
		|| exit 255
⋮

Keep the privkeys.tar.gpg in a safe place. This file contains the
private keys for all of your certificates. If you lose or compromised
this file, certificates based in these keys will no longer be secure.
```

The resulting `.gpg` file should now be stored in a safe place, in case that the key material needs to be restored for any purpose.

# Clearing pre-existing ACME challenges

To assist with DNS zone hygiene, the included `clear-well-known.sh` script will delete all existing TXT DNS records under the `_acme-challenge` subdomain with configuration under `/etc/letsencrypt/seed`.
