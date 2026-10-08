#!/bin/sh
# Ccenter'ı kaldırır (install.sh ile kurulanı). Sadece Ccenter'a ait olduğu doğrulanan dosyaları siler.
# Klavye izni ve ayarlar için ayrıca sorar.
set -eu

data=${XDG_DATA_HOME:-$HOME/.local/share}
config=${XDG_CONFIG_HOME:-$HOME/.config}
app=$data/ccenter
launcher=$app/bin/ccenter
rule=/etc/udev/rules.d/90-ccenter.rules

say() { printf '%s\n' "$*"; }
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

# Silinecekler: yalnızca Ccenter'a ait olanlar (menü kaydı/servis bizim uygulama yolunu içeriyorsa,
# terminal komutu bizim uygulamaya bağlantıysa)
files=""
for f in "$data/applications/ccenter.desktop" "$data/systemd/user/ccenter.service" "$config/systemd/user/ccenter.service"; do
    [ -f "$f" ] && grep -q "$app" "$f" && files="$files $f"
done
[ -L "$HOME/.local/bin/ccenter" ] && [ "$(readlink -f "$HOME/.local/bin/ccenter")" = "$launcher" ] && files="$files $HOME/.local/bin/ccenter"

say "Ccenter kaldırılıyor"
say "===================="
if [ ! -d "$app" ] && [ -z "$files" ]; then
    say "Kurulu bir Ccenter bulunamadı ($app yok)."
else
    say "Silinecekler:"
    [ -d "$app" ] && say "  $app/"
    for f in $files; do say "  $f"; done
    ask "Devam edilsin mi?" e || { say "İptal edildi, hiçbir şey değişmedi."; exit 0; }

    # Çalışıyorsa düzgün kapat (klavye efekti sabit renge, fanlar NBFC'ye döner)
    if qs list --all 2>/dev/null | grep -q "$app/shell.qml"; then
        say "Çalışan Ccenter kapatılıyor…"
        qs ipc -p "$app" call cc quit >/dev/null 2>&1 || true
        sleep 2
    fi
    # Arka plan servisi açıksa kapat
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user disable --now ccenter.service >/dev/null 2>&1 || true
    fi
    rm -rf "$app"
    for f in $files; do rm -f "$f"; done
    command -v systemctl >/dev/null 2>&1 && systemctl --user daemon-reload 2>/dev/null || true
    say "Uygulama kaldırıldı."
fi

# Klavye ışığı izni
if [ -f "$rule" ]; then
    say ""
    say "Klavye ışığı izni ($rule) duruyor."
    if ask "Bu izin de kaldırılsın mı? (yönetici şifresi istenecek)" e; then
        if sudo rm -f "$rule" && sudo udevadm control --reload-rules; then
            for f in /sys/class/leds/*::kbd_backlight/brightness /sys/class/leds/*::kbd_backlight/multi_intensity; do
                [ -e "$f" ] && sudo chmod 0644 "$f"
            done
            say "Klavye izni kaldırıldı (ışık dosyaları yine sadece root tarafından yazılabilir)."
        else
            say "Kaldırılamadı. Elle: sudo rm $rule"
        fi
    fi
fi

# Ayarlar
cfg=$config/ccenter
if [ -d "$cfg" ]; then
    say ""
    if ask "Ayarların ($cfg: fan profilleri, eğriler, klavye) da silinsin mi?" h; then
        rm -rf "$cfg"
        say "Ayarlar silindi."
    else
        say "Ayarlar duruyor; tekrar kurarsan kaldığın yerden devam eder."
    fi
fi
say ""
say "Tamam."
