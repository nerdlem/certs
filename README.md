# Certificate hierarchy

This is the file layout I use to build certificates for my websites.

Each domain name should have a directory containing a template file and a symlink to `Makefile.sub`. Do something like this:

```bash
$ mkdir my.domain
$ rsync -avP ./lem.click/ ./my-domain/
   ⋮
```

Then, edit the file `my.domain/template.conf` to customize the parameters of your certificate. Finally, use `make`:

```bash
$ make
make -C athena.pics
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

