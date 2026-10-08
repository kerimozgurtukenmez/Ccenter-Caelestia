# Sistem genelinde kurulum ve paketleme içindir. Normal kullanıcı için önerilen yol: ./install.sh
# (kullanıcı klasörüne kurar, yönetici şifresi gerektirmez, klavye iznini sorar).
#   sudo make install      /usr altına kurar (klavye izni EKLEMEZ)
#   sudo make uninstall    kaldırır (kullanıcı ayarları ~/.config/ccenter'a dokunmaz)
#   sudo make udev         klavye ışığı izni (udev kuralı) — isteğe bağlı, ayrıca çalıştırılır
# Paketleme için: make DESTDIR=/paket/kökü PREFIX=/usr install

PREFIX  ?= /usr
DESTDIR ?=

APPDIR  = $(DESTDIR)$(PREFIX)/share/ccenter
BINDIR  = $(DESTDIR)$(PREFIX)/bin
APPSDIR = $(DESTDIR)$(PREFIX)/share/applications
ICONDIR = $(DESTDIR)$(PREFIX)/share/icons/hicolor/scalable/apps
UNITDIR = $(DESTDIR)$(PREFIX)/lib/systemd/user
UDEVDIR = $(DESTDIR)$(PREFIX)/lib/udev/rules.d
# Klavye ışığı dosyaları (kaldırınca izinleri 0644'e döndürmek için)
KBD_FILES = /sys/class/leds/*::kbd_backlight/brightness /sys/class/leds/*::kbd_backlight/multi_intensity

# Uygulamanın çalışması için gereken dosyalar (CLAUDE.md, README, dist vb. kurulmaz)
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
	@echo
	@echo "Ccenter kuruldu. Başlatmak için: ccenter   (ya da uygulama menüsünden)"
	@echo "Klavye ışığı izni eklenmedi. İstersen: sudo make udev   (ya da uygulamadaki 'İzin ver')"

uninstall: uninstall-udev
	rm -rf $(APPDIR)
	rm -f $(BINDIR)/ccenter $(APPSDIR)/ccenter.desktop $(ICONDIR)/ccenter.svg $(UNITDIR)/ccenter.service
	@echo
	@echo "Ccenter kaldırıldı. Ayarların duruyor: ~/.config/ccenter (silmek istersen elle sil)."
	@echo "Arka plan servisini etkinleştirdiysen: systemctl --user disable ccenter.service"

# Klavye ışığı izni: kuralı kur ve hemen uygula (DESTDIR ile paketlerken sadece kopyalanır)
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
