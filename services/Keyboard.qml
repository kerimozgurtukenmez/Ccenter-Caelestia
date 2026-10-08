pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.utils

// Klavye ışığı (çekirdeğin LED arayüzü): /sys/class/leds/*::kbd_backlight
//   brightness (0..max_brightness), RGB ise multi_intensity "r g b" (0..multi_max_intensity)
// Bölge (zone) yok: tüm klavye tek renk. Yazma izni kurulumdaki udev kuralından gelir (dist/90-ccenter.rules).
// Efektler yazılımla çalışır (bu servis her zaman çalıştığı için pencere kapalıyken de sürer):
//   breathing: renk yoğunluğu en düşük ve en yüksek seviye arasında yumuşakça gidip gelir; renk en karanlık anda değişir.
//   cycle:     renkler arasında yanıp sönmeden, ton üzerinden sürekli ve yumuşak geçiş.
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
    property color color: "white"             // seçilen renk (tam yoğunlukta; parlaklık ayrı)
    property string error: ""

    // ---------- efekt ayarları (settings.json → kbd) ----------
    property string effect: "static"          // static | breathing | cycle
    property string source: "single"          // single (seçilen renk) | multi (renk listesi) | theme (Caelestia)
    property var colors: ["#ff0000", "#00ff00", "#0040ff"]
    property real speed: 0.5                  // 0 yavaş .. 1 hızlı
    readonly property real period: 8 - 7 * speed   // bir nefes (sn): 8 .. 1
    readonly property bool effectActive: effect !== "static" && rgb && writable
    property int cycleIndex: 0                // şu an nefes alan rengin sırası (arayüz gösterir)
    property int themeCount: 3                // Caelestia kaynağında kaç renk (3..6)
    property real minLevel: 0                 // nefesin en düşük seviyesi (0..1); 0 = tamamen söner
    property real maxLevel: 1                 // nefesin en yüksek seviyesi (0..1)

    // Caelestia renkleri LED için canlandırılır (tema pastel; doygunluk düşükse LED beyazımsı görünür)
    function vivid(c) {
        c = Qt.lighter(c, 1)
        return c.hsvSaturation < 0.05 ? Qt.rgba(1, 1, 1, 1) : Qt.hsva(c.hsvHue, Math.max(c.hsvSaturation, 0.85), 1, 1)
    }
    // Tema renkleri: önce temanın ana rengi, sonra secondary/tertiary ve temanın vurgu renkleri arasından
    // tonu öncekilere en uzak olanlar (themeCount kadar). Hepsi temadan; birbirine benzeyenler elenir.
    readonly property var themeColors: {
        const base = [vivid(Colours.primary)]
        const pool = [Colours.secondary, Colours.tertiary].concat(Colours.accents).map(vivid)
        const hue = c => c.hsvHue < 0 ? -1 : c.hsvHue
        const dist = (a, b) => { const x = Math.abs(hue(a) - hue(b)); return Math.min(x, 1 - x) }
        const out = base
        while (out.length < themeCount && pool.length > 0) {
            let best = 0, bestD = -1
            for (let i = 0; i < pool.length; i++) {
                const d = Math.min.apply(null, out.map(o => dist(o, pool[i])))
                if (d > bestD) { bestD = d; best = i }
            }
            out.push(pool.splice(best, 1)[0])
        }
        return out
    }
    // Efektin döndüğü renkler
    readonly property var cycle: source === "multi" ? colors.map(x => Qt.lighter(x, 1))
                               : source === "theme" ? themeColors : [color]

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
        if (!ready) loadSaved()               // ilk okumada kayıtlı efekt ayarlarını yükle (ayar dosyası bu noktada hazır)
        dir = v.dir || ""
        rgb = !!v.multi_intensity && /red/.test(v.multi_index || "") && /green/.test(v.multi_index || "")
        writable = !!w.brightness && (!rgb || !!w.multi_intensity)
        maxBrightness = parseInt(v.max_brightness) || 255
        brightness = parseInt(v.brightness) || 0
        if (rgb) maxIntensity = (v.multi_max_intensity || "255 255 255").trim().split(/\s+/).map(x => parseInt(x) || 255)
        // Efekt çalışırken donanımdaki renk anlık efekt karesidir; seçilen rengi onunla ezme
        if (rgb && !effectActive) {
            const it = v.multi_intensity.trim().split(/\s+/).map(x => parseInt(x) || 0)
            const order = (v.multi_index || "red green blue").trim().split(/\s+/)
            const ch = n => { const k = order.indexOf(n); return k < 0 ? 0 : it[k] / maxIntensity[k] }
            color = Qt.rgba(ch("red"), ch("green"), ch("blue"), 1)
        }
        ready = true
    }

    // ---------- yazma ----------
    // renk (0..1) × seviye -> "R G B" (donanım ölçeğinde)
    function intensity(c, level) {
        return [c.r, c.g, c.b].map((x, i) => Math.round(Math.max(0, Math.min(1, x * level)) * (maxIntensity[i] ?? 255))).join(" ")
    }
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
        Settings.setKbd({ color: hex(color) })
        if (!effectActive) queue("multi_intensity", intensity(color, 1))   // efekt varsa bir sonraki kare uygular
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
        // Renk önce, sonra parlaklık (renk değişince ışık bir an eski parlaklıkta kalmasın)
        for (const f of ["multi_intensity", "brightness"])
            if (pending[f] !== undefined) send(f, pending[f])
        pending = ({})
    }
    Timer { id: flush; interval: 80; onTriggered: root.writeNext() }

    // Sürekli açık tek yazıcı süreç (awk): her yazma için süreç başlatmak efekt sırasında (25 kare/sn) pahalı olurdu.
    // awk girdiyi tamponlu okur (bash "read" boruyu bayt bayt okuyordu, ~2 kat pahalıydı; FileView ise ~3 kat).
    // Her yazma iki satır: dosya yolu, değer. Yazılamazsa awk hata verip çıkar.
    function send(file, value) {
        if (writer.running) writer.write(dir + "/" + file + "\n" + value + "\n")
    }
    function writeFailed(why) {
        error = "Klavye ışığına yazılamadı" + (why ? ": " + why : "")
        effect = "static"                     // izin gittiyse efekti durdur (ayara yazılmaz)
        refresh()                             // gerçek değeri ve izni geri oku
    }
    Process {
        id: writer
        running: root.available
        command: ["awk", "NR % 2 { f = $0; next } { print > f; close(f) }"]
        stdinEnabled: true
        stderr: SplitParser { onRead: line => root.writeFailed(line.replace(/^.*fatal: /, "")) }
        // Çıkarsa (hata) yeniden başlat; sonraki yazmalar çalışsın
        onExited: if (root.available) restartWriter.start()
    }
    Timer { id: restartWriter; interval: 1000; onTriggered: writer.running = true }

    // ---------- efektler ----------
    function setEffect(e) {
        if (e === effect) return
        if (e === "cycle" && source === "single") setSource("multi")   // tek renkle geçiş olmaz
        effect = e
        Settings.setKbd({ effect: e })
        if (e === "static") queue("multi_intensity", intensity(color, 1))   // efekt bitince seçilen renge dön
        else { t0 = Date.now(); lastFrame = "" }
    }
    function setSource(s) { source = s; Settings.setKbd({ source: s }); lastFrame = "" }
    function setThemeCount(n) { themeCount = Math.max(3, Math.min(6, Math.round(n))); Settings.setKbd({ themeCount: themeCount }) }
    function setColors(list) { colors = list.slice(0, 6); Settings.setKbd({ colors: colors }) }
    function setSpeed(v) {
        // Hız değişince nefes kaldığı yerden devam etsin (faz korunur)
        const now = Date.now(), p = ((now - t0) / 1000) / period
        speed = Math.max(0, Math.min(1, v))
        t0 = now - p * period * 1000
        saveSpeed.restart()
    }
    Timer { id: saveSpeed; interval: 500; onTriggered: Settings.setKbd({ speed: root.speed }) }
    // En düşük/en yüksek seviye; biri diğerini geçerse onu da iter
    function setRange(lo, hi) {
        lo = Math.max(0, Math.min(1, lo))
        hi = Math.max(0, Math.min(1, hi))
        if (lo > hi) { if (lo !== minLevel) hi = lo; else lo = hi }
        minLevel = lo
        maxLevel = hi
        saveRange.restart()
    }
    Timer { id: saveRange; interval: 500; onTriggered: Settings.setKbd({ min: root.minLevel, max: root.maxLevel }) }

    function mix(a, b, f) { return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, 1) }

    property double t0: Date.now()
    property string lastFrame: ""
    // Ton üzerinden karışım: canlı renkler arasında geçişte araya koyu/bulanık renk girmesin (kırmızı→sarı→yeşil)
    function mixHsv(a, b, f) {
        if (a.hsvSaturation < 0.05 || b.hsvSaturation < 0.05) return mix(a, b, f)   // beyaz/gri: düz karışım
        let d = b.hsvHue - a.hsvHue
        if (d > 0.5) d -= 1
        if (d < -0.5) d += 1
        const h = ((a.hsvHue + d * f) % 1 + 1) % 1
        return Qt.hsva(h, a.hsvSaturation + (b.hsvSaturation - a.hsvSaturation) * f, a.hsvValue + (b.hsvValue - a.hsvValue) * f, 1)
    }
    // Çok düşük seviyede kanallar küçük tam sayılara yuvarlanınca ton kayar (pembe → [1 0 0] kırmızı gibi);
    // en güçlü kanal bu eşiğin altına inerse ışık yanlış renk göstermek yerine kapanır
    readonly property int lowCut: 8
    function frame(c, level) {
        const v = [c.r, c.g, c.b].map((x, i) => Math.max(0, Math.min(1, x * level)) * (maxIntensity[i] ?? 255))
        if (Math.max.apply(null, v) < lowCut) return "0 0 0"
        return v.map(Math.round).join(" ")
    }
    function tick() {
        const n = cycle.length
        if (n === 0) return
        const t = (Date.now() - t0) / 1000 / period
        const k = Math.floor(t)
        const f = t - k
        if (cycleIndex !== k % n) cycleIndex = k % n
        let v
        if (effect === "cycle") {
            // Renk geçişi: k. renkten bir sonrakine, yavaş başlayıp yavaş biten yumuşak geçiş; ışık sönmez
            const e = (1 - Math.cos(Math.PI * f)) / 2
            v = frame(n > 1 ? mixHsv(cycle[k % n], cycle[(k + 1) % n], e) : cycle[0], 1)
        } else {
            // Nefes: her nefes bir renk; renk en karanlık anda (f = 0) değişir, araya başka renk girmez
            const l = Math.pow((1 - Math.cos(2 * Math.PI * f)) / 2, 1.8)   // 0 → 1 → 0, koyu kısım biraz uzun (göz algısı)
            v = frame(cycle[k % n], minLevel + (maxLevel - minLevel) * l)
        }
        if (v !== lastFrame) { lastFrame = v; send("multi_intensity", v) }
    }
    Timer {
        // Nefes başına ~80 kare yeterince akıcı: hızlıda 25 kare/sn, yavaşta daha seyrek (daha az CPU)
        interval: Math.max(40, Math.min(100, root.period * 1000 / 80))
        repeat: true
        running: root.effectActive && writer.running
        onTriggered: root.tick()
    }

    // Uygulama kapanırken: efekt yarıda kalıp klavye karanlık kalmasın, seçilen sabit renge dön (sonra cb)
    function restoreForQuit(cb) {
        if (!effectActive) { cb(); return }
        effect = "static"                                   // ayara yazılmaz: açılınca efekt devam eder
        oneShot.go(["sh", "-c", 'printf "%s\\n" "$2" > "$1"', "sh", dir + "/multi_intensity", intensity(color, 1)], () => cb())
    }

    // Terminal (IPC) için: "#rrggbb" ve yüzde
    function hex(c) {
        const h = x => ("0" + Math.round(x * 255).toString(16)).slice(-2)
        return ("#" + h(c.r) + h(c.g) + h(c.b)).toUpperCase()
    }
    function statusText() {
        if (!available) return "Klavye ışığı bulunamadı (/sys/class/leds/*::kbd_backlight yok)"
        const src = { single: "seçilen renk", multi: colors.length + " renk", theme: "Caelestia teması, " + themeCount + " renk" }
        return "Klavye ışığı: " + name + (rgb ? " (RGB, tek bölge)" : " (tek renk)")
            + "\nRenk: " + (rgb ? hex(color) : "-")
            + "\nParlaklık: %" + Math.round(brightness * 100 / maxBrightness)
            + "\nEfekt: " + (effect === "breathing" ? "nefes (" + src[source] + ", " + period.toFixed(1) + " sn, %"
                + Math.round(minLevel * 100) + "–%" + Math.round(maxLevel * 100) + ")"
                : effect === "cycle" ? "renk geçişi (" + src[source] + ", renk başına " + period.toFixed(1) + " sn)" : "sabit")
            + (writable ? "" : "\nYazma izni yok: kurulum gerekli (sudo make install)")
    }

    Cmd { id: reader }
    Cmd { id: oneShot }
    function loadSaved() {
        const k = Settings.kbdOf()
        source = k.source
        colors = k.colors
        speed = k.speed
        themeCount = k.themeCount
        minLevel = k.min
        maxLevel = k.max
        if (k.color !== "") color = k.color
        effect = k.effect
        t0 = Date.now()
    }
    Component.onCompleted: refresh()
}
