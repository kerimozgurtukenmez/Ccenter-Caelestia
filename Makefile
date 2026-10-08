# Ccenter kurulumu
#   sudo make install      kurar
#   sudo make uninstall    kaldırır (kullanıcı ayarları ~/.config/ccenter'a dokunmaz)
# Paketleme için: make DESTDIR=/paket/kökü PREFIX=/usr install

PREFIX  ?= /usr
DESTDIR ?=

APPDIR  = $(DESTDIR)$(PREFIX)/share/ccenter
BINDIR  = $(DESTDIR)$(PREFIX)/bin
APPSDIR = $(DESTDIR)$(PREFIX)/share/applications
ICONDIR = $(DESTDIR)$(PREFIX)/share/icons/hicolor/scalable/apps
UNITDIR = $(DESTDIR)$(PREFIX)/lib/systemd/user

# Uygulamanın çalışması için gereken dosyalar (CLAUDE.md, README, dist vb. kurulmaz)
APP_FILES = shell.qml VERSION
APP_DIRS  = components modules services utils scripts assets

.PHONY: install uninstall

install:
	install -d $(APPDIR)
	install -m 644 $(APP_FILES) $(APPDIR)/
	cp -r --no-preserve=ownership $(APP_DIRS) $(APPDIR)/
	find $(APPDIR) -type d -exec chmod 755 {} +
	find $(APPDIR) -type f -exec chmod 644 {} +
	chmod 755 $(APPDIR)/scripts/*.sh $(APPDIR)/scripts/*.py
	install -Dm 755 bin/ccenter $(BINDIR)/ccenter
	install -Dm 644 dist/ccenter.desktop $(APPSDIR)/ccenter.desktop
	install -Dm 644 assets/ccenter.svg $(ICONDIR)/ccenter.svg
	install -Dm 644 dist/ccenter.service $(UNITDIR)/ccenter.service
	@echo
	@echo "Ccenter kuruldu. Başlatmak için: ccenter   (ya da uygulama menüsünden)"

uninstall:
	rm -rf $(APPDIR)
	rm -f $(BINDIR)/ccenter $(APPSDIR)/ccenter.desktop $(ICONDIR)/ccenter.svg $(UNITDIR)/ccenter.service
	@echo
	@echo "Ccenter kaldırıldı. Ayarların duruyor: ~/.config/ccenter (silmek istersen elle sil)."
	@echo "Arka plan servisini etkinleştirdiysen: systemctl --user disable ccenter.service"
