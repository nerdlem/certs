# Automate generation of certificate sets for a group of domains.
#
# © 2017 Luis E. Muñoz -- All Rights Reserved

SUBDIRS = $(shell find . -mindepth 1 -maxdepth 1 -type d -name '[a-z]*.*')

.PHONY: all clean $(SUBDIRS)

all: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

clean:
	for p in $(SUBDIRS); do $(MAKE) -C $$p clean; done
