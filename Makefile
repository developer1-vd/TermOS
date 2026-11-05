# TermOS Makefile
#
#   make install       install TermOS tools (PREFIX=/usr/local by default)
#   make uninstall     remove them
#   make iso           build the live ISO (needs root on Fedora; see iso/build-iso.sh)
#   make iso-container build the live ISO inside a Fedora container
#   make ks            only generate build/termos.ks
#   make lint          bash -n + shellcheck + ksvalidator
#   make clean         remove build/

PREFIX  ?= /usr/local
DESTDIR ?=
BINDIR   = $(DESTDIR)$(PREFIX)/bin
SHAREDIR = $(DESTDIR)$(PREFIX)/share/termos

SCRIPTS  = bin/termos-fetch bin/termos-run iso/build-iso.sh

.PHONY: all install uninstall iso iso-container ks lint clean

all:
	@sed -n '3,9s/^# \{0,1\}//p' Makefile

install:
	install -Dm755 bin/termos-fetch               $(BINDIR)/termos-fetch
	install -Dm755 bin/termos-run                 $(BINDIR)/termos-run
	install -Dm644 branding/logo-matrix.txt       $(SHAREDIR)/logo-matrix.txt
	install -Dm644 branding/logo-termite.txt      $(SHAREDIR)/logo-termite.txt
	install -Dm644 config/fastfetch/config.jsonc  $(SHAREDIR)/fastfetch/config.jsonc
	install -Dm644 config/neofetch/config.conf    $(SHAREDIR)/neofetch/config.conf

uninstall:
	rm -f  $(BINDIR)/termos-fetch $(BINDIR)/termos-run
	rm -rf $(SHAREDIR)

iso:
	sudo iso/build-iso.sh

iso-container:
	iso/build-iso.sh --container

ks:
	iso/build-iso.sh --ks-only

lint: ks
	bash -n $(SCRIPTS)
	shellcheck $(SCRIPTS)
	ksvalidator build/termos.ks

clean:
	rm -rf build
