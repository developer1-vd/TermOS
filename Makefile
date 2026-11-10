# TermOS Makefile
#
#   make install       install TermOS tools (PREFIX=/usr/local by default)
#   make uninstall     remove them
#   make install-splash  install the TermOS boot splash and make it the default (root)
#   make install-grub    install the TermOS GRUB theme and regenerate grub.cfg (root)
#   make install-icons   use the TermOS logo in place of Fedora's logo (root)
#   make install-os-release  brand /etc/os-release as TermOS and keep it so (root)
#   make art           regenerate the wallpaper and boot splash images
#   make iso           build the live ISO (needs root on Fedora; see iso/build-iso.sh)
#   make iso-container build the live ISO inside a Fedora container
#   make ks            only generate build/termos.ks
#   make lint          bash -n + shellcheck + ksvalidator
#   make clean         remove build/

PREFIX  ?= /usr/local
DESTDIR ?=
BINDIR   = $(DESTDIR)$(PREFIX)/bin
SHAREDIR = $(DESTDIR)$(PREFIX)/share/termos
WALLDIR  = $(DESTDIR)$(PREFIX)/share/wallpapers/TermOS
# fortune only looks in its own directory, whatever PREFIX is.
FORTUNEDIR ?= $(DESTDIR)/usr/share/games/fortune

SCRIPTS  = bin/termos-fetch bin/termos-run iso/build-iso.sh \
           branding/grub/install-grub-theme.sh branding/grub/42_termos \
           branding/installer/termos-live-desktop.sh branding/icons/install-icons.sh \
           branding/os-release/termos-os-release \
           tests/install-test.sh

.PHONY: all install uninstall install-splash install-grub install-icons install-os-release art iso iso-container ks lint clean

all:
	@sed -n '3,14s/^# \{0,1\}//p' Makefile

install:
	install -Dm755 bin/termos-fetch               $(BINDIR)/termos-fetch
	install -Dm755 bin/termos-run                 $(BINDIR)/termos-run
	install -Dm644 VERSION                        $(SHAREDIR)/VERSION
	install -Dm644 branding/logo-matrix.txt       $(SHAREDIR)/logo-matrix.txt
	install -Dm644 branding/logo-termite.txt      $(SHAREDIR)/logo-termite.txt
	install -Dm644 config/fastfetch/config.jsonc  $(SHAREDIR)/fastfetch/config.jsonc
	install -Dm644 config/neofetch/config.conf    $(SHAREDIR)/neofetch/config.conf
	install -Dm644 branding/wallpaper/metadata.json $(WALLDIR)/metadata.json
	install -Dm644 -t $(WALLDIR)/contents           branding/wallpaper/contents/screenshot.png
	install -Dm644 -t $(WALLDIR)/contents/images    branding/wallpaper/contents/images/*.png
	install -Dm644 branding/fortune/termos          $(FORTUNEDIR)/termos
	if command -v strfile >/dev/null; then strfile $(FORTUNEDIR)/termos >/dev/null; fi

install-splash:
	install -Dm644 -t $(DESTDIR)/usr/share/plymouth/themes/termos branding/plymouth/termos/*
	plymouth-set-default-theme -R termos

install-grub:
	install -Dm755 branding/grub/42_termos $(DESTDIR)/etc/grub.d/42_termos
	branding/grub/install-grub-theme.sh branding/grub/termos --mkconfig

install-icons:
	branding/icons/install-icons.sh branding/icons/hicolor $(DESTDIR)/usr/local/share/icons/hicolor

install-os-release:
	install -Dm755 branding/os-release/termos-os-release $(DESTDIR)/usr/libexec/termos/termos-os-release
	install -Dm644 -t $(DESTDIR)/etc/systemd/system \
		branding/os-release/termos-os-release.service branding/os-release/termos-os-release.path
	test -f $(DESTDIR)/etc/termos-release || \
		printf 'NAME=TermOS\nVERSION_ID=%s\nPRETTY_NAME="TermOS %s"\n' "$$(cat VERSION)" "$$(cat VERSION)" \
		> $(DESTDIR)/etc/termos-release
	systemctl daemon-reload
	systemctl enable --now termos-os-release.service termos-os-release.path

art:
	python3 branding/make-art.py

uninstall:
	rm -f  $(BINDIR)/termos-fetch $(BINDIR)/termos-run
	rm -rf $(SHAREDIR) $(WALLDIR)
	rm -f  $(FORTUNEDIR)/termos $(FORTUNEDIR)/termos.dat

iso:
	sudo iso/build-iso.sh

iso-container:
	iso/build-iso.sh --container

ks:
	iso/build-iso.sh --ks-only

lint: ks
	for f in $(SCRIPTS); do bash -n "$$f" || exit 1; done
	shellcheck $(SCRIPTS)
	ksvalidator build/termos.ks

clean:
	rm -rf build
