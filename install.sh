#!/bin/sh
# Ccenter installer: installs into your home folder, NO admin password needed.
# Everything lives in the app's own folder (~/.local/share/ccenter); the launcher entry, the background service and
# the terminal command (~/.local/bin/ccenter) are added where writable and skipped otherwise (the install still works).
# The only optional admin step is the keyboard light permission: explained and asked (default: no).
# To remove: ./uninstall.sh
set -eu

src=$(cd "$(dirname "$0")" && pwd)
data=${XDG_DATA_HOME:-$HOME/.local/share}
config=${XDG_CONFIG_HOME:-$HOME/.config}
app=$data/ccenter
launcher=$app/bin/ccenter                     # the launcher entry and the service call this by full path
rule=/etc/udev/rules.d/90-ccenter.rules

# Message language: CCENTER_LANG, else the language chosen in the app (settings.json), else the system locale
lang=${CCENTER_LANG:-}
if [ -z "$lang" ]; then
    grep -q '"lang": *"tr"' "$config/ccenter/settings.json" 2>/dev/null && lang=tr
    grep -q '"lang": *"en"' "$config/ccenter/settings.json" 2>/dev/null && lang=en
fi
[ -n "$lang" ] || case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in tr*) lang=tr ;; *) lang=en ;; esac

say() { printf '%s\n' "$*"; }
# t "English" "Türkçe": print the line in the chosen language
t() { if [ "$lang" = tr ]; then say "$2"; else say "$1"; fi; }
# ask "English question" "Türkçe soru" default(y|n) -> 0 = yes. Accepts y/n and e/h (evet/hayır) in both languages.
ask() {
    if [ "$lang" = tr ]; then _q=$2; _h="[E/h]"; [ "$3" = y ] || _h="[e/H]"
    else _q=$1; _h="[Y/n]"; [ "$3" = y ] || _h="[y/N]"; fi
    printf '%s %s ' "$_q" "$_h"
    read -r ans || ans=""
    case "$ans" in
        [eEyY]*) return 0 ;;
        [hHnN]*) return 1 ;;
        *) [ "$3" = y ] ;;
    esac
}
# Is the folder (or, if it doesn't exist yet, the closest existing parent) writable?
# (POSIX sh has no local variables: _cw_-prefixed names so functions don't clobber the caller's variables)
can_write() {
    _cw_d=$1
    while [ ! -e "$_cw_d" ]; do _cw_d=$(dirname "$_cw_d"); done
    [ -d "$_cw_d" ] && [ -w "$_cw_d" ]
}
owner() { _cw_d=$1; while [ ! -e "$_cw_d" ]; do _cw_d=$(dirname "$_cw_d"); done; stat -c %U "$_cw_d"; }

t "Ccenter setup" "Ccenter kurulumu"
say "================"
say ""

# ---------- pre-checks ----------
missing=""
command -v qs >/dev/null 2>&1 || missing="$missing quickshell"
[ -d /usr/lib/qt6/qml/Caelestia ] || missing="$missing caelestia-shell"
command -v nbfc >/dev/null 2>&1 || t "Note: nbfc-linux not found; it is needed for fan control." "Not: nbfc-linux bulunamadı; fan kontrolü için gerekli."
if [ -n "$missing" ]; then
    t "Missing:$missing" "Eksik:$missing"
    t "Ccenter does not work without these. Install them first, then try again." "Ccenter bunlar olmadan çalışmaz. Önce kur, sonra tekrar dene."
    exit 1
fi
if [ -f /usr/share/ccenter/shell.qml ]; then
    t "A system-wide Ccenter is installed (/usr/share/ccenter). Remove it first so the two installs don't get mixed up." \
      "Sistem genelinde kurulu bir Ccenter var (/usr/share/ccenter). İki kurulum karışmasın diye önce onu kaldır."
    exit 1
fi
if qs list --all 2>/dev/null | grep -qiE 'ccenter/shell\.qml'; then
    t "Ccenter is running right now. Quit it first (in the app 'Quit', or: ccenter quit), then try again." \
      "Ccenter şu an çalışıyor. Önce kapat (uygulamada 'Tamamen kapat' ya da: ccenter quit), sonra tekrar dene."
    exit 1
fi

# ---------- plan: where each part goes, and whether it is writable ----------
if ! can_write "$app"; then
    _o=$(owner "$app")
    t "Can't create the app folder: $app (owner: $_o)." "Uygulama klasörü oluşturulamıyor: $app (sahibi: $_o)."
    t "This means your own user folder isn't writable; the install stopped without touching anything." \
      "Bu, kullanıcı klasörünün kendisinin yazılamadığı anlamına gelir; kurulum hiçbir şeye dokunmadan durduruldu."
    exit 1
fi
# If a file with the same name belongs to another program (doesn't mention our app path), leave it alone
foreign() { [ -e "$1" ] && ! grep -q "$app" "$1" 2>/dev/null; }
desktop=""; desktop_note=$(t "$data/applications is not writable" "$data/applications yazılamıyor")
if foreign "$data/applications/ccenter.desktop"; then
    desktop_note=$(t "$data/applications/ccenter.desktop belongs to another program; it won't be touched" \
                     "$data/applications/ccenter.desktop başka bir programa ait; ona dokunulmayacak")
elif can_write "$data/applications"; then
    desktop=$data/applications/ccenter.desktop
fi
unitdir=""; unit_note=$(t "the systemd user folders are not writable" "systemd kullanıcı klasörleri yazılamıyor")
for ud in "$data/systemd/user" "$config/systemd/user"; do
    if foreign "$ud/ccenter.service"; then
        unit_note=$(t "$ud/ccenter.service belongs to another program; it won't be touched" "$ud/ccenter.service başka bir programa ait; ona dokunulmayacak")
        break
    fi
    can_write "$ud" && { unitdir=$ud; break; }
done
link=""; link_note=""
bindir=$HOME/.local/bin
if [ -e "$bindir/ccenter" ] && [ "$(readlink -f "$bindir/ccenter")" != "$launcher" ]; then
    link_note=$(t "$bindir/ccenter already exists and doesn't belong to Ccenter; it won't be touched." \
                  "$bindir/ccenter zaten var ve Ccenter'a ait değil; ona dokunulmayacak.")
elif can_write "$bindir"; then
    link=$bindir/ccenter
else
    _o=$(owner "$bindir")
    link_note=$(t "$bindir is not writable (owner: $_o); the terminal command link will be skipped." \
                  "$bindir yazılamıyor (sahibi: $_o); terminal komutu bağlantısı atlanacak.")
fi

t "Will be installed (all in your home folder, no admin password needed):" "Kurulacaklar (hepsi senin kullanıcı klasöründe, yönetici şifresi gerekmez):"
t "  $app/   app, command and icon" "  $app/   uygulama, komut ve ikon"
if [ -n "$desktop" ]; then t "  $desktop   app menu entry" "  $desktop   uygulama menüsü kaydı"
else t "  (skipped) app menu entry: $desktop_note" "  (atlanacak) uygulama menüsü kaydı: $desktop_note"; fi
if [ -n "$unitdir" ]; then t "  $unitdir/ccenter.service   background service (off unless you turn it on)" "  $unitdir/ccenter.service   arka plan servisi (sen açmadıkça kapalı)"
else t "  (skipped) background service: $unit_note" "  (atlanacak) arka plan servisi: $unit_note"; fi
if [ -n "$link" ]; then t "  $link   terminal command (a link to the app)" "  $link   terminal komutu (uygulamaya bağlantı)"
else t "  (skipped) terminal command: $link_note" "  (atlanacak) terminal komutu: $link_note"; fi
say ""
ask "Continue?" "Devam edilsin mi?" y || { t "Install cancelled, nothing changed." "Kurulum iptal edildi, hiçbir şey değişmedi."; exit 0; }

# ---------- install ----------
rm -rf "$app"
mkdir -p "$app/bin" "$app/dist"
cp -r "$src/shell.qml" "$src/VERSION" "$src/LICENSE" "$src/components" "$src/modules" "$src/services" "$src/utils" "$src/scripts" "$src/assets" "$app/"
cp "$src/dist/90-ccenter.rules" "$app/dist/"            # used by the app's grant button
install -m 755 "$src/bin/ccenter" "$launcher"
if [ -n "$desktop" ]; then
    mkdir -p "$(dirname "$desktop")"
    sed -e "s|@BINDIR@/ccenter|$launcher|g" -e "s|^Icon=ccenter\$|Icon=$app/assets/ccenter.svg|" \
        "$src/dist/ccenter.desktop" > "$desktop"
fi
if [ -n "$unitdir" ]; then
    mkdir -p "$unitdir"
    sed "s|@BINDIR@/ccenter|$launcher|g" "$src/dist/ccenter.service" > "$unitdir/ccenter.service"
    command -v systemctl >/dev/null 2>&1 && systemctl --user daemon-reload 2>/dev/null || true
fi
if [ -n "$link" ]; then
    mkdir -p "$(dirname "$link")"
    ln -sf "$launcher" "$link"
fi
t "App installed." "Uygulama kuruldu."
say ""

# ---------- keyboard light permission (optional) ----------
led=""
for d in /sys/class/leds/*::kbd_backlight; do [ -e "$d/brightness" ] && { led=$d; break; }; done
if [ -z "$led" ]; then
    t "No keyboard light found; skipped the keyboard permission step." "Klavye ışığı bulunamadı; klavye izni adımı atlandı."
elif [ -w "$led/brightness" ]; then
    t "The keyboard light is already writable; no permission step needed." "Klavye ışığına zaten yazılabiliyor; izin adımı gerekmiyor."
else
    t "Keyboard light permission (optional)" "Klavye ışığı izni (isteğe bağlı)"
    say "--------------------------------"
    t "Light found: ${led##*/}" "Bulunan ışık: ${led##*/}"
    t "For Ccenter to change the keyboard's color, brightness and effects it needs write access to these" \
      "Ccenter'ın klavyenin rengini, parlaklığını ve efektlerini değiştirebilmesi için ışığın şu dosyalarına"
    t "files of the light (a permanent version of what you do by hand with 'sudo tee'):" \
      "yazma izni gerekir (elle 'sudo tee' ile yaptığın şeyin kalıcı hali):"
    say "  $led/brightness"
    [ -e "$led/multi_intensity" ] && say "  $led/multi_intensity"
    say ""
    t "What is done : the file $rule is added (a udev rule); no other file is touched." \
      "Ne yapılır : $rule dosyası eklenir (udev kuralı); başka hiçbir dosyaya dokunulmaz."
    t "What changes : programs on this computer can change the keyboard light's color and brightness." \
      "Ne değişir : bu bilgisayardaki programlar klavye ışığının rengini ve parlaklığını değiştirebilir."
    t "               It gives no access to anything else (fans, files, the system)." \
      "             Başka hiçbir şeye (fanlar, dosyalar, sistem) erişim vermez."
    t "Undo         : ./uninstall.sh, or in the app Keyboard > 'Remove permission'." \
      "Geri alma  : ./uninstall.sh ya da uygulamada Klavye > 'İzni kaldır'."
    t "You can also grant it later with the 'Grant permission' button in the app." \
      "İstersen şimdi değil, sonra uygulamadaki 'İzin ver' butonundan da verebilirsin."
    say ""
    if ask "Grant the keyboard light permission? (asks for the admin password)" "Klavye ışığı izni verilsin mi? (yönetici şifresi istenecek)" n; then
        t "Will run: sudo install -Dm644 $app/dist/90-ccenter.rules $rule && sudo udevadm control --reload-rules && sudo udevadm trigger --action=change --subsystem-match=leds" \
          "Çalıştırılacak: sudo install -Dm644 $app/dist/90-ccenter.rules $rule && sudo udevadm control --reload-rules && sudo udevadm trigger --action=change --subsystem-match=leds"
        if sudo install -Dm644 "$app/dist/90-ccenter.rules" "$rule" \
           && sudo udevadm control --reload-rules \
           && sudo udevadm trigger --action=change --subsystem-match=leds; then
            sleep 1
            if [ -w "$led/brightness" ]; then t "Permission granted." "İzin verildi."
            else t "The rule was added but the permission isn't visible yet; it applies after a reboot." "Kural eklendi ama izin henüz görünmüyor; yeniden başlatınca geçerli olur."; fi
        else
            t "Could not grant the permission (no password, or an error). You can grant it later from the app." \
              "İzin verilemedi (şifre girilmedi ya da hata). Sonra uygulamadan verebilirsin."
        fi
    else
        t "Keyboard permission not granted. You can grant it any time with 'Grant permission' in the Keyboard tab." \
          "Klavye izni verilmedi. Klavye sekmesindeki 'İzin ver' ile istediğin zaman verebilirsin."
    fi
fi

say ""
t "Install complete." "Kurulum tamam."
[ -n "$desktop" ] && t "  To start: 'Ccenter' in the app menu" "  Başlatmak: uygulama menüsünden 'Ccenter'"
if [ -n "$link" ] && case ":$PATH:" in *":$bindir:"*) true ;; *) false ;; esac; then
    say "  Terminal: ccenter"
else
    t "  Terminal: $launcher   (for the short 'ccenter' command, add this folder to PATH: $app/bin)" \
      "  Terminal: $launcher   (kısa 'ccenter' komutu için bu klasörü PATH'e ekleyebilirsin: $app/bin)"
fi
t "  To remove: ./uninstall.sh" "  Kaldırmak: ./uninstall.sh"
