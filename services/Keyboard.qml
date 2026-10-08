pragma Singleton
import Quickshell
import QtQuick
import qs.utils

// Klavye ışığı (çekirdeğin LED arayüzü): /sys/class/leds/*::kbd_backlight
//   brightness (0..max_brightness), RGB ise multi_intensity "r g b" (0..multi_max_intensity)
// Bölge (zone) yok: tüm klavye tek renk. Yazma izni kurulumdaki udev kuralından gelir (dist/90-ccenter.rules).
Singleton {
    id: root

    property string dir: ""                   // ör. /sys/class/leds/hp::kbd_backlight
    readonly property bool available: dir !== ""
    readonly property string name: dir.slice(dir.lastIndexOf("/") + 1)
    property bool rgb: false
    property bool writable: false
    property bool ready: false                // ilk okuma bitti mi
    property int maxBrightness: 255
    property var maxIntensity: [255, 255, 255]
    property int brightness: 0
    property color color: "white"             // tam parlaklıkta renk (parlaklık ayrı)
    property string error: ""

    // ---------- okuma ----------
    function refresh() {
        // Tek seferde: dizin, yazılabilirlik, değerler. Sadece kabuk yerleşikleri (read).
        reader.go(["sh", "-c",
            'for d in /sys/class/leds/*::kbd_backlight; do [ -e "$d/brightness" ] || continue; ' +
            'echo "dir|$d"; ' +
            'for f in brightness max_brightness multi_intensity multi_max_intensity multi_index; do ' +
            '  [ -r "$d/$f" ] && { read -r v < "$d/$f"; echo "$f|$v"; }; done; ' +
            '[ -w "$d/brightness" ] && echo "w|brightness"; [ -w "$d/multi_intensity" ] && echo "w|multi_intensity"; ' +
            'break; done'], (code, out) => root.parse(out))
    }
    function parse(out) {
        const v = {}, w = {}
        for (const line of out.split("\n")) {
            const i = line.indexOf("|")
            if (i < 0) continue
            const k = line.slice(0, i), val = line.slice(i + 1)
            if (k === "w") w[val] = true
            else v[k] = val
        }
        dir = v.dir || ""
        rgb = !!v.multi_intensity && /red/.test(v.multi_index || "") && /green/.test(v.multi_index || "")
        writable = !!w.brightness && (!rgb || !!w.multi_intensity)
        maxBrightness = parseInt(v.max_brightness) || 255
        brightness = parseInt(v.brightness) || 0
        if (rgb) {
            const mx = (v.multi_max_intensity || "255 255 255").trim().split(/\s+/).map(x => parseInt(x) || 255)
            const it = v.multi_intensity.trim().split(/\s+/).map(x => parseInt(x) || 0)
            const order = (v.multi_index || "red green blue").trim().split(/\s+/)
            const ch = n => { const k = order.indexOf(n); return k < 0 ? 0 : it[k] / mx[k] }
            maxIntensity = mx
            color = Qt.rgba(ch("red"), ch("green"), ch("blue"), 1)
        }
        ready = true
    }

    // ---------- yazma ----------
    // Değişiklikler hemen arayüze yansır; dosyaya en fazla ~12 kez/sn yazılır (sürüklerken)
    property var pending: ({})
    function setBrightness(b) {
        if (!writable) { refresh(); return }  // izin yoksa durumu değiştirme; izin sonradan verilmiş olabilir, yeniden bak
        brightness = Math.max(0, Math.min(maxBrightness, Math.round(b)))
        queue("brightness", String(brightness))
    }
    function setColor(c) {
        if (!rgb) return
        if (!writable) { refresh(); return }
        c = Qt.lighter(c, 1)                  // "#rrggbb" metni de gelebilir (terminal, hazır renkler): renge çevir
        color = Qt.rgba(c.r, c.g, c.b, 1)
        const v = [c.r, c.g, c.b].map((x, i) => Math.round(Math.max(0, Math.min(1, x)) * (maxIntensity[i] ?? 255)))
        queue("multi_intensity", v.join(" "))
        // Parlaklık 0 iken renk seçmek ışığı yakmaz; kullanıcı rengi görebilsin diye aç
        if (brightness === 0) setBrightness(maxBrightness)
    }
    function queue(file, value) {
        if (!available) return
        const p = Object.assign({}, pending)
        p[file] = value
        pending = p
        if (!flush.running) flush.start()
    }
    function writeNext() {
        if (writer.busy) { flush.start(); return }
        const keys = Object.keys(pending)
        if (keys.length === 0) return
        // Renk önce, sonra parlaklık (renk değişince ışık bir an eski parlaklıkta kalmasın)
        const file = keys.indexOf("multi_intensity") >= 0 ? "multi_intensity" : keys[0]
        const value = pending[file]
        const p = Object.assign({}, pending)
        delete p[file]
        pending = p
        writer.go(["sh", "-c", 'printf "%s\\n" "$2" > "$1"', "sh", dir + "/" + file, value], (code, out, err) => {
            root.error = code === 0 ? "" : "Yazılamadı: " + (err || out).trim().split("\n")[0]
            if (code !== 0) { root.pending = ({}); root.refresh(); return }   // gerçek değeri geri oku
            if (Object.keys(root.pending).length > 0) flush.start()
        })
    }
    Timer { id: flush; interval: 80; onTriggered: root.writeNext() }

    // Terminal (IPC) için: "#rrggbb" ve yüzde
    function hex(c) {
        const h = x => ("0" + Math.round(x * 255).toString(16)).slice(-2)
        return ("#" + h(c.r) + h(c.g) + h(c.b)).toUpperCase()
    }
    function statusText() {
        if (!available) return "Klavye ışığı bulunamadı (/sys/class/leds/*::kbd_backlight yok)"
        return "Klavye ışığı: " + name + (rgb ? " (RGB, tek bölge)" : " (tek renk)")
            + "\nRenk: " + (rgb ? hex(color) : "-")
            + "\nParlaklık: %" + Math.round(brightness * 100 / maxBrightness)
            + (writable ? "" : "\nYazma izni yok: kurulum gerekli (sudo make install)")
    }

    Cmd { id: reader }
    Cmd { id: writer }
    Component.onCompleted: refresh()
}
