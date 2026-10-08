# For system-wide installs and packaging. For a normal user the recommended way is ./install.sh
# (installs into the home folder, needs no admin password, asks about the keyboard permission).
#   sudo make install      installs under /usr (does NOT add the keyboard permission)
#   sudo make uninstall    removes it (does not touch user settings in ~/.config/ccenter)
#   sudo make udev         keyboard light permission (udev rule), optional and run separately
# Packaging: make DESTDIR=/package/root PREFIX=/usr install

PREFIX  ?= /usr
DESTDIR ?=

APPDIR  = $(DESTDIR)$(PREFIX)/share/ccenter
BINDIR  = $(DESTDIR)$(PREFIX)/bin
APPSDIR = $(DESTDIR)$(PREFIX)/share/applications
ICONDIR = $(DESTDIR)$(PREFIX)/share/icons/hicolor/scalable/apps
UNITDIR = $(DESTDIR)$(PREFIX)/lib/systemd/user
UDEVDIR = $(DESTDIR)$(PREFIX)/lib/udev/rules.d
LICDIR  = $(DESTDIR)$(PREFIX)/share/licenses/ccenter
# Keyboard light files (to restore their permissions to 0644 on uninstall)
KBD_FILES = /sys/class/leds/*::kbd_backlight/brightness /sys/class/leds/*::kbd_backlight/multi_intensity

# Files the app needs at runtime (README, dist etc. are not installed; the license goes to share/licenses)
APP_FILES = shell.qml VERSION
APP_DIRS  = components modules services utils scripts assets

.PHONY: install uninstall udev uninstall-udev

install:
	install -d $(APPDIR)
	install -m 644 $(APP_FILES) $(APPDIR)/
	cp -r --no-preserve=ownership $(APP_DIRS) $(APPDIR)/
	install -Dm 644 dist/90-ccenter.rules $(APPDIR)/dist/90-ccenter.rules
	find $(APPDIR) -type d -exec chmod 755 {} +
	find $(APPDIR) -type f -exec chmod 644 {} +
	chmod 755 $(APPDIR)/scripts/*.sh $(APPDIR)/scripts/*.py
	install -Dm 755 bin/ccenter $(BINDIR)/ccenter
	install -d $(APPSDIR) $(UNITDIR)
	sed 's|@BINDIR@|$(PREFIX)/bin|g' dist/ccenter.desktop > $(APPSDIR)/ccenter.desktop
	chmod 644 $(APPSDIR)/ccenter.desktop
	install -Dm 644 assets/ccenter.svg $(ICONDIR)/ccenter.svg
	sed 's|@BINDIR@|$(PREFIX)/bin|g' dist/ccenter.service > $(UNITDIR)/ccenter.service
	chmod 644 $(UNITDIR)/ccenter.service
	install -Dm 644 LICENSE $(LICDIR)/LICENSE
	@echo
	@echo "Ccenter installed. To start it: ccenter   (or from the app menu)"
	@echo "The keyboard light permission was not added. If you want it: sudo make udev   (or 'Grant permission' in the app)"

uninstall: uninstall-udev
	rm -rf $(APPDIR)
	rm -f $(BINDIR)/ccenter $(APPSDIR)/ccenter.desktop $(ICONDIR)/ccenter.svg $(UNITDIR)/ccenter.service
	rm -rf $(LICDIR)
	@echo
	@echo "Ccenter removed. Your settings are kept in ~/.config/ccenter (delete it by hand if you want)."
	@echo "If you enabled the background service: systemctl --user disable ccenter.service"

# Keyboard light permission: install the rule and apply it right away (only copied when packaging with DESTDIR)
udev:
	install -Dm 644 dist/90-ccenter.rules $(UDEVDIR)/90-ccenter.rules
	@if [ -z "$(DESTDIR)" ] && command -v udevadm >/dev/null; then \
		udevadm control --reload-rules && udevadm trigger --action=change --subsystem-match=leds; \
	fi

uninstall-udev:
	rm -f $(UDEVDIR)/90-ccenter.rules
	@if [ -z "$(DESTDIR)" ]; then \
		command -v udevadm >/dev/null && udevadm control --reload-rules; \
		for f in $(KBD_FILES); do [ -e "$$f" ] && chmod 0644 "$$f"; done; true; \
	fi
