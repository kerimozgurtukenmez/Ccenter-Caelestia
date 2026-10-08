#!/bin/sh
# Ccenter kurulumu: senin kullanıcı klasörüne kurar, yönetici şifresi GEREKMEZ.
# Her şey uygulamanın kendi klasöründe (~/.local/share/ccenter) durur; menü kaydı, arka plan servisi ve
# terminal komutu (~/.local/bin/ccenter) yazılabildikleri yerlere eklenir, yazılamayan atlanır (kurulum bozulmaz).
# Tek isteğe bağlı yönetici adımı klavye ışığı izni: anlatılır, sorulur (varsayılan hayır).
# Kaldırmak için: ./uninstall.sh
set -eu

src=$(cd "$(dirname "$0")" && pwd)
data=${XDG_DATA_HOME:-$HOME/.local/share}
config=${XDG_CONFIG_HOME:-$HOME/.config}
app=$data/ccenter
launcher=$app/bin/ccenter                     # menü kaydı ve servis bunu tam yoluyla çağırır
rule=/etc/udev/rules.d/90-ccenter.rules

say() { printf '%s\n' "$*"; }
# ask "soru" varsayılan(e|h) -> 0 = evet
ask() {
    if [ "$2" = e ]; then hint="[E/h]"; else hint="[e/H]"; fi
    printf '%s %s ' "$1" "$hint"
    read -r ans || ans=""
    case "$ans" in
        [eEyY]*) return 0 ;;
        [hHnN]*) return 1 ;;
        *) [ "$2" = e ] ;;
    esac
}
# Klasöre (ya da henüz yoksa oluşturulacağı en yakın üst klasöre) yazılabiliyor mu?
# (POSIX sh'de yerel değişken yok: fonksiyonlar çağıranın değişkenlerini ezmesin diye _cw_ önekli adlar)
can_write() {
    _cw_d=$1
    while [ ! -e "$_cw_d" ]; do _cw_d=$(dirname "$_cw_d"); done
    [ -d "$_cw_d" ] && [ -w "$_cw_d" ]
}
owner() { _cw_d=$1; while [ ! -e "$_cw_d" ]; do _cw_d=$(dirname "$_cw_d"); done; stat -c %U "$_cw_d"; }

say "Ccenter kurulumu"
say "================"
say ""

# ---------- ön kontroller ----------
missing=""
command -v qs >/dev/null 2>&1 || missing="$missing quickshell"
[ -d /usr/lib/qt6/qml/Caelestia ] || missing="$missing caelestia-shell"
command -v nbfc >/dev/null 2>&1 || say "Not: nbfc-linux bulunamadı; fan kontrolü için gerekli."
if [ -n "$missing" ]; then
    say "Eksik:$missing"
    say "Ccenter bunlar olmadan çalışmaz. Önce kur, sonra tekrar dene."
    exit 1
fi
if [ -f /usr/share/ccenter/shell.qml ]; then
    say "Sistem genelinde kurulu bir Ccenter var (/usr/share/ccenter). İki kurulum karışmasın diye önce onu kaldır."
    exit 1
fi
if qs list --all 2>/dev/null | grep -qiE 'ccenter/shell\.qml'; then
    say "Ccenter şu an çalışıyor. Önce kapat (uygulamada 'Tamamen kapat' ya da: ccenter quit), sonra tekrar dene."
    exit 1
fi

# ---------- plan: her parça nereye, yazılabiliyor mu ----------
if ! can_write "$app"; then
    say "Uygulama klasörü oluşturulamıyor: $app (sahibi: $(owner "$app"))."
    say "Bu, kullanıcı klasörünün kendisinin yazılamadığı anlamına gelir; kurulum hiçbir şeye dokunmadan durduruldu."
    exit 1
fi
# Aynı adla başka bir programa ait dosya varsa (içinde bizim uygulama yolu yoksa) ona dokunma
foreign() { [ -e "$1" ] && ! grep -q "$app" "$1" 2>/dev/null; }
desktop=""; desktop_note="$data/applications yazılamıyor"
if foreign "$data/applications/ccenter.desktop"; then
    desktop_note="$data/applications/ccenter.desktop başka bir programa ait; ona dokunulmayacak"
elif can_write "$data/applications"; then
    desktop=$data/applications/ccenter.desktop
fi
unitdir=""; unit_note="systemd kullanıcı klasörleri yazılamıyor"
for ud in "$data/systemd/user" "$config/systemd/user"; do
    if foreign "$ud/ccenter.service"; then unit_note="$ud/ccenter.service başka bir programa ait; ona dokunulmayacak"; break; fi
    can_write "$ud" && { unitdir=$ud; break; }
done
link=""; link_note=""
bindir=$HOME/.local/bin
if [ -e "$bindir/ccenter" ] && [ "$(readlink -f "$bindir/ccenter")" != "$launcher" ]; then
    link_note="$bindir/ccenter zaten var ve Ccenter'a ait değil; ona dokunulmayacak."
elif can_write "$bindir"; then
    link=$bindir/ccenter
else
    link_note="$bindir yazılamıyor (sahibi: $(owner "$bindir")); terminal komutu bağlantısı atlanacak."
fi

say "Kurulacaklar (hepsi senin kullanıcı klasöründe, yönetici şifresi gerekmez):"
say "  $app/   uygulama, komut ve ikon"
if [ -n "$desktop" ]; then say "  $desktop   uygulama menüsü kaydı"
else say "  (atlanacak) uygulama menüsü kaydı: $desktop_note"; fi
if [ -n "$unitdir" ]; then say "  $unitdir/ccenter.service   arka plan servisi (sen açmadıkça kapalı)"
else say "  (atlanacak) arka plan servisi: $unit_note"; fi
if [ -n "$link" ]; then say "  $link   terminal komutu (uygulamaya bağlantı)"
else say "  (atlanacak) terminal komutu: $link_note"; fi
say ""
ask "Devam edilsin mi?" e || { say "Kurulum iptal edildi, hiçbir şey değişmedi."; exit 0; }

# ---------- kurulum ----------
rm -rf "$app"
mkdir -p "$app/bin" "$app/dist"
cp -r "$src/shell.qml" "$src/VERSION" "$src/components" "$src/modules" "$src/services" "$src/utils" "$src/scripts" "$src/assets" "$app/"
cp "$src/dist/90-ccenter.rules" "$app/dist/"            # uygulamadaki "İzin ver" bunu kullanır
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
say "Uygulama kuruldu."
say ""

# ---------- klavye ışığı izni (isteğe bağlı) ----------
led=""
for d in /sys/class/leds/*::kbd_backlight; do [ -e "$d/brightness" ] && { led=$d; break; }; done
if [ -z "$led" ]; then
    say "Klavye ışığı bulunamadı; klavye izni adımı atlandı."
elif [ -w "$led/brightness" ]; then
    say "Klavye ışığına zaten yazılabiliyor; izin adımı gerekmiyor."
else
    say "Klavye ışığı izni (isteğe bağlı)"
    say "--------------------------------"
    say "Bulunan ışık: ${led##*/}"
    say "Ccenter'ın klavyenin rengini, parlaklığını ve efektlerini değiştirebilmesi için ışığın şu dosyalarına"
    say "yazma izni gerekir (elle 'sudo tee' ile yaptığın şeyin kalıcı hali):"
    say "  $led/brightness"
    [ -e "$led/multi_intensity" ] && say "  $led/multi_intensity"
    say ""
    say "Ne yapılır : $rule dosyası eklenir (udev kuralı); başka hiçbir dosyaya dokunulmaz."
    say "Ne değişir : bu bilgisayardaki programlar klavye ışığının rengini ve parlaklığını değiştirebilir."
    say "             Başka hiçbir şeye (fanlar, dosyalar, sistem) erişim vermez."
    say "Geri alma  : ./uninstall.sh ya da uygulamada Klavye > 'İzni kaldır'."
    say "İstersen şimdi değil, sonra uygulamadaki 'İzin ver' butonundan da verebilirsin."
    say ""
    if ask "Klavye ışığı izni verilsin mi? (yönetici şifresi istenecek)" h; then
        say "Çalıştırılacak: sudo install -Dm644 $app/dist/90-ccenter.rules $rule && sudo udevadm control --reload-rules && sudo udevadm trigger --action=change --subsystem-match=leds"
        if sudo install -Dm644 "$app/dist/90-ccenter.rules" "$rule" \
           && sudo udevadm control --reload-rules \
           && sudo udevadm trigger --action=change --subsystem-match=leds; then
            sleep 1
            if [ -w "$led/brightness" ]; then say "İzin verildi."; else say "Kural eklendi ama izin henüz görünmüyor; yeniden başlatınca geçerli olur."; fi
        else
            say "İzin verilemedi (şifre girilmedi ya da hata). Sonra uygulamadan verebilirsin."
        fi
    else
        say "Klavye izni verilmedi. Klavye sekmesindeki 'İzin ver' ile istediğin zaman verebilirsin."
    fi
fi

say ""
say "Kurulum tamam."
[ -n "$desktop" ] && say "  Başlatmak: uygulama menüsünden 'Ccenter'"
if [ -n "$link" ] && case ":$PATH:" in *":$bindir:"*) true ;; *) false ;; esac; then
    say "  Terminal: ccenter"
else
    say "  Terminal: $launcher   (kısa 'ccenter' komutu için bu klasörü PATH'e ekleyebilirsin: $app/bin)"
fi
say "  Kaldırmak: ./uninstall.sh"
