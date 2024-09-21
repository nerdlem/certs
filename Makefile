# Automate generation of certificate sets for a group of domains.
#
# © 2017 Luis E. Muñoz -- All Rights Reserved

SUBDIRS      ?= $(shell find . -mindepth 1 -maxdepth 1 -type d -name '[a-z]*.*')
RSYNC        ?= /usr/bin/rsync
RUSER        ?= root
HOST         ?= server
LESEED       ?= /etc/letsencrypt/seed
GPGRECIPIENT ?= me@lem.click

.PHONY: all clean preserve save-keys $(SUBDIRS)

all: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

clean:
	for p in $(SUBDIRS); do $(MAKE) -C $$p clean; done

upload: $(SUBDIRS)
	$(RSYNC) -avPR --no-perms --chmod=ug=rX               \
		$(foreach p,$(SUBDIRS),$(p)/cert-0.*)         \
		$(foreach p,$(SUBDIRS),$(p)/cert-[1-9].pub)   \
		$(foreach p,$(SUBDIRS),$(p)/add-tlsa.sh)      \
		$(RUSER)@$(HOST):$(LESEED)/

preserve: $(SUBDIRS)
	tar cf -                                        \
	  $(foreach p,$(SUBDIRS),$(p)/cert-*.key)       \
		$(foreach p,$(SUBDIRS),$(p)/add-tlsa.sh)      \
		| gpg --encrypt --armor --recipient $(GPGRECIPIENT) > privkeys.tar.gpg \
		|| exit 255
	@echo
	@echo Keep the privkeys.tar.gpg in a safe place. This file contains the
	@echo private keys for all of your certificates. If you lose or compromised
	@echo this file, certificates based in these keys will no longer be secure.

save-keys: preserve privkeys.tar.gpg
	[ -s privkeys.tar.gpg ] || exit 255
	$(RM) $(foreach p,$(SUBDIRS),$(p)/cert-*.key)
	@echo
	@echo Private keys have been deleted as they are stored in the
	@echo privkeys.tar.gpg archive. If you lose this file, your replacement
	@echo certificates are no longer usable.

clear-dns-acme:
	@[ -d /etc/letsencrypt/seed ] || ( echo "Only available at your key server"; exit 255 )
	@echo
	@echo Clearing remnant ACME DNS challenges from known domain names
	./clear-well-known.sh
