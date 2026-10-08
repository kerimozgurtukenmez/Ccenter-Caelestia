pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.utils

// nbfc-linux ile konuşan arka uç. Fan hızı ayarı root istemez; servis/config işlemleri pkexec ile yapılır.
Singleton {
    id: root

    // ---- durum ----
    property bool running: false
    property bool readOnly: false
    property string configId: ""
    property var fans: []                 // [{ name, temp, auto, current, target }]
    property real temp: NaN
    property bool bootEnabled: false
    property var configs: []
    property var recommended: []
    property string message: ""
    property bool messageError: false
    property real safety: isFinite(Settings.safety()) ? Settings.safety() : 90   // bu sıcaklıkta özel modlardaki fanlar %100'e çıkar

    property var targets: ({})            // fan index -> { mode, fixed, curve }  (sadece Sabit/Eğri)
    property var lastSent: ({})
    property var queue: []
    property bool logged: false

    // ---------- komut kuyruğu (komutlar sırayla çalışır) ----------
    function enqueue(key, cmd, cb) {
        const q = queue.filter(e => key === "" || e.key !== key)
        q.push({ key: key, cmd: cmd, cb: cb })
        queue = q
        pump()
    }
    function pump() {
        if (runner.busy || queue.length === 0) return
        const e = queue[0]
        queue = queue.slice(1)
        runner.go(e.cmd, (code, out, err) => {
            if (e.cb) e.cb(code, out, err)
            Qt.callLater(root.pump)
        })
    }
    function firstLine(s) { return s.trim().split("\n")[0] }
    function lines(s) { return s.split("\n").map(l => l.trim()).filter(l => l !== "") }

    // root isteyen işler
    function sudo(args, label, then) {
        message = label
        messageError = false
        enqueue("", ["pkexec"].concat(args), (code, out, err) => {
            if (code === 0) {
                root.message = ""
            } else {
                root.message = "Başarısız: " + root.firstLine(err !== "" ? err : out) + " (kod " + code + ")"
                root.messageError = true
            }
            if (then) then(code)
            root.poll()
        })
    }

    // ---------- servis ----------
    property bool userStopped: false         // servisi kullanıcı durdurduysa "beklenmedik durdu" bildirimi gitmez
    signal serviceLost()                     // çalışan servis beklenmedik şekilde durdu
    signal commandFailed(string msg)         // fan hızı yazılamadı
    signal boostEnded()                      // süreli maksimum fan bitti

    function startService() { userStopped = false; sudo(["nbfc", "start"].concat(readOnly ? ["-r"] : []), "Yönetici izni bekleniyor…") }
    function stopService() { userStopped = true; sudo(["nbfc", "stop"], "Yönetici izni bekleniyor…") }
    function restartService(ro) { sudo(["nbfc", "restart"].concat(ro ? ["-r"] : []), "Yönetici izni bekleniyor…") }
    function setReadOnly(v) {
        const was = root.running
        readOnly = v
        if (was) restartService(v)
    }
    function setBoot(v) {
        sudo(["systemctl", v ? "enable" : "disable", "nbfc_service"], "Yönetici izni bekleniyor…", () => root.refreshBoot())
    }
    function refreshBoot() {
        enqueue("boot", ["systemctl", "is-enabled", "nbfc_service"], (code, out) => { root.bootEnabled = out.trim() === "enabled" })
    }

    // ---------- config ----------
    property var cfgFromCli: []
    property var cfgFromDir: []
    property string cfgNoteCli: ""
    property string configNote: ""

    // Liste: önce config klasörü (dosya adı = config adı), yoksa `nbfc config -l`. Seçili config her zaman listede.
    function mergeConfigs() {
        const src = cfgFromDir.length > 0 ? cfgFromDir : cfgFromCli
        const seen = {}
        const all = []
        for (const c of src.concat(configId !== "" ? [configId] : [])) {
            if (!seen[c]) { seen[c] = true; all.push(c) }
        }
        all.sort((a, b) => a.localeCompare(b))
        configs = all
        const from = cfgFromDir.length > 0 ? " (" + cfgDirs + ")" : cfgFromCli.length > 0 ? " (nbfc config -l)" : ""
        const onlyCurrent = cfgFromDir.length === 0 && cfgFromCli.length === 0
        configNote = (all.length > 0 ? all.length + " config" + from : "Liste alınamadı")
                   + (onlyCurrent ? " · sadece seçili config biliniyor, config klasörü bulunamadı" : "")
                   + (cfgNoteCli !== "" && cfgFromDir.length === 0 ? " · " + cfgNoteCli : "")
    }
    property string cfgDirs: ""
    function loadConfigs() {
        // stdout + stderr birlikte; bazı sürümler listeyi stderr'e ya da farklı biçimde basabiliyor
        enqueue("cfg:list", ["sh", "-c", "nbfc config -l 2>&1"], (code, out) => {
            const ls = root.lines(out).filter(l => !/^(usage|error|warning)/i.test(l))
            console.log("[ccenter] nbfc config -l (çıkış " + code + "): " + ls.length + " satır; ilk: " + (ls[0] || "-"))
            root.cfgFromCli = code === 0 ? ls : []
            root.cfgNoteCli = code === 0 ? (ls.length === 0 ? "nbfc config -l boş döndü" : "")
                                         : "nbfc config -l başarısız (kod " + code + "): " + root.firstLine(out)
            root.mergeConfigs()
        })
        // Bilinen tüm config klasörleri; satır biçimi: klasör|dosyaadı
        enqueue("cfg:dir", ["sh", "-c",
            'for d in /usr/share/nbfc/configs /usr/local/share/nbfc/configs /var/lib/nbfc/configs /etc/nbfc/configs /opt/nbfc/configs; do ' +
            '[ -d "$d" ] && find "$d" -maxdepth 1 -name "*.json" -printf "$d|%f\\n"; done'], (code, out) => {
            const names = [], dirs = []
            for (const l of root.lines(out)) {
                const i = l.indexOf("|")
                if (i < 0) continue
                const d = l.slice(0, i)
                if (dirs.indexOf(d) < 0) dirs.push(d)
                names.push(l.slice(i + 1).replace(/\.json$/, ""))
            }
            root.cfgFromDir = names
            root.cfgDirs = dirs.join(", ")
            root.mergeConfigs()
        })
    }
    // Seçili config'in her fan için eşik tablosu, bizim eğri biçiminde (config dosyası sadece okunur).
    // [{ points: [{t, s}], hyst } | null]  — null: config eşik tablosu tanımlamıyor
    property var configCurves: []
    function loadConfigCurves() {
        const id = configId
        if (id === "") { configCurves = []; return }
        enqueue("cfg:curves", ["sh", "-c",
            'for d in /etc/nbfc/configs /usr/share/nbfc/configs /usr/local/share/nbfc/configs; do ' +
            '[ -f "$d/$1.json" ] && exec cat "$d/$1.json"; done; exit 1', "sh", id], (code, out) => {
            if (id !== root.configId) return
            try {
                root.configCurves = code === 0 ? (JSON.parse(out).FanConfigurations || []).map(f => root.toCurve(f.TemperatureThresholds)) : []
            } catch (e) {
                root.configCurves = []
            }
        })
    }
    // NBFC: sıcaklık UpThreshold'a ulaşınca FanSpeed'e çık, DownThreshold altına inince geri dön = basamaklı eğri
    function toCurve(th) {
        if (!Array.isArray(th) || th.length === 0) return null
        const rows = th.map(r => ({ up: Number(r.UpThreshold), down: Number(r.DownThreshold), s: Number(r.FanSpeed) }))
                       .filter(r => isFinite(r.up) && isFinite(r.s)).sort((a, b) => a.up - b.up)
        const pts = []
        for (const r of rows) {
            let t = Math.max(30, Math.min(100, Math.round(r.up)))     // editör aralığı 30..100
            if (pts.length && t <= pts[pts.length - 1].t) t = pts[pts.length - 1].t + 1
            if (t > 100) break
            pts.push({ t: t, s: Math.max(0, Math.min(100, Math.round(r.s))) })
        }
        if (pts.length < 2) return null
        const gaps = rows.filter(r => r.up > 0 && isFinite(r.down)).map(r => r.up - r.down)
        const hyst = gaps.length ? Math.max(0, Math.min(10, Math.round(gaps.reduce((a, b) => a + b, 0) / gaps.length))) : 3
        return { points: pts, hyst: hyst }
    }

    function recommend() {
        enqueue("cfg:rec", ["nbfc", "config", "-r"], (code, out) => {
            if (code !== 0) return
            const known = {}
            for (const c of root.configs) known[c] = true
            const found = []
            for (const l of root.lines(out)) {
                for (const c of [l, l.split(/\s{2,}|\t/)[0].trim()]) {
                    if (known[c] && found.indexOf(c) < 0) { found.push(c); break }
                }
            }
            root.recommended = found
            if (found.length === 0) { root.message = "Öneri bulunamadı"; root.messageError = false }
        })
    }
    function applyConfig(name) {
        sudo(["sh", "-c", 'nbfc config -s "$1" && nbfc restart $2', "sh", name, readOnly ? "-r" : ""], "Yönetici izni bekleniyor…")
    }

    // ---------- durum okuma ----------
    function isTrue(v) { return /^(true|yes|on|enabled|1)/i.test(v.trim()) }

    function parseStatus(txt) {
        const res = { readOnly: null, temp: NaN, fans: [] }
        let fan = null
        const fresh = name => {
            const f = { name: name, temp: NaN, auto: true, current: 0, target: 0, curSeen: false }
            res.fans.push(f)
            return f
        }
        for (const line of txt.split("\n")) {
            const i = line.indexOf(":")
            if (i < 0) continue
            const k = line.slice(0, i).trim().toLowerCase()
            const v = line.slice(i + 1).trim()
            if (k.indexOf("fan") >= 0 && k.indexOf("name") >= 0) { fan = fresh(v); continue }
            if (k.indexOf("read") >= 0 && k.indexOf("only") >= 0) { res.readOnly = root.isTrue(v); continue }
            if (k.indexOf("temp") >= 0) {
                const n = parseFloat(v)
                if (fan) fan.temp = n; else res.temp = n
                continue
            }
            if (k.indexOf("current") >= 0 && k.indexOf("speed") >= 0) {
                if (!fan || fan.curSeen) fan = fresh("Fan " + (res.fans.length + 1))
                fan.current = parseFloat(v) || 0
                fan.curSeen = true
                continue
            }
            if (!fan) continue
            if (k.indexOf("target") >= 0 && k.indexOf("speed") >= 0) fan.target = parseFloat(v) || 0
            else if (k.indexOf("auto") >= 0) fan.auto = root.isTrue(v)
        }
        return res
    }

    function applyStatus(res) {
        if (res.readOnly !== null) readOnly = res.readOnly
        const ft = res.fans.map(f => f.temp).filter(t => isFinite(t))
        temp = isFinite(res.temp) ? res.temp : (ft.length ? Math.max.apply(null, ft) : NaN)
        fans = res.fans
    }

    function poll() {
        if (statusCmd.busy) return
        statusCmd.go(["nbfc", "status", "-a"], (code, out, err) => {
            if (!root.logged) {
                root.logged = true
                console.log("[ccenter] nbfc status -a (çıkış " + code + "):\n" + out + err)
            }
            const was = root.running
            root.running = code === 0
            if (was && !root.running && !root.userStopped && !root.quitting) root.serviceLost()
            if (code === 0) {
                root.userStopped = false
                root.applyStatus(root.parseStatus(out))
                root.checkBoost()
                root.control()
                root.record()
            } else {
                root.temp = NaN
            }
        })
    }

    // ---------- fan kontrolü ----------
    // Sabit/Eğri modunda fan varsa sensörler pencere kapalıyken de okunur (güvenlik sınırı GPU'yu da izlesin)
    readonly property bool needsSensors: Object.keys(targets).length > 0
    // Ccenter fanları kontrol ediyor mu (Sabit/Eğri/maksimum): öyleyse sık okunur
    readonly property bool controlling: needsSensors || boosting
    property bool uiVisible: true             // pencere açık mı (shell.qml bağlar); gizliyken sakin tempo

    // NBFC'nin bu fan için okuduğu sıcaklık (config'teki sensör; bu makinede CPU)
    function tempOf(i) {
        const t = fans[i] ? fans[i].temp : NaN
        return isFinite(t) ? t : temp
    }
    // st.src: "cpu" (NBFC sensörü, varsayılan) | "gpu" | "max". GPU okunamıyorsa (uyku/yok) CPU'ya düşer.
    function sourceTemp(i, src) {
        const c = tempOf(i), g = Sensors.gpu
        if (src === "gpu") return isFinite(g) ? g : c
        if (src === "max") return isFinite(g) ? (isFinite(c) ? Math.max(c, g) : g) : c
        return c
    }
    // Güvenlik sınırı her zaman en sıcak olana bakar
    function hottest(i) { return sourceTemp(i, "max") }

    // st.curve = [{ t: °C, s: % }] (sıcaklığa göre sıralı), st.smooth = noktalar arası düz geçiş mi
    function curveAt(st, T) {
        const p = st.curve
        if (!p || p.length === 0) return NaN
        if (T <= p[0].t) return p[0].s
        for (let i = 1; i < p.length; i++) {
            if (T < p[i].t) {
                if (!st.smooth) return p[i - 1].s
                return p[i - 1].s + (p[i].s - p[i - 1].s) * (T - p[i - 1].t) / (p[i].t - p[i - 1].t)
            }
        }
        return p[p.length - 1].s
    }

    // Eğri modunda fanın şu anki seviyesi (%): histerezis ve kademeli yavaşlama bunun üzerinden çalışır
    property var level: ({})
    readonly property int rampDown: 5        // her kontrol turunda (2 sn) en fazla bu kadar yavaşlar

    // Hızlanma hemen; yavaşlama için sıcaklık eğrinin st.hyst °C altına inmeli, sonra kademeli iner
    function curveLevel(i, st, T) {
        const up = curveAt(st, T)
        const prev = level[i]
        if (prev === undefined || !isFinite(prev) || up >= prev) return up
        const down = curveAt(st, T + st.hyst)
        const target = Math.min(prev, Math.max(up, down))
        return Math.max(target, prev - rampDown)
    }

    // idx = fan index, -1 = tüm fanlar. st = { mode: 0 oto | 1 sabit | 2 eğri, fixed: 0..1, curve: [{t,s}], smooth }
    function applyTarget(idx, st) {
        const ids = idx < 0 ? fans.map((f, i) => i) : [idx]
        const t = Object.assign({}, targets)
        for (const i of ids) {
            lastSent[i] = undefined
            level[i] = undefined                    // ayar değişti: yeni eğri hemen geçerli
            if (st.mode === 0) delete t[i]; else t[i] = st
        }
        targets = t
        if (boosting) return                         // maksimum fan bitince her fan kendi ayarına döner
        if (st.mode === 0) {
            enqueue(idx < 0 ? "auto:all" : "auto:" + idx,
                    idx < 0 ? ["nbfc", "set", "-a"] : ["nbfc", "set", "-f", String(idx), "-a"], null)
        } else {
            control()
        }
    }

    // Her durum okumasından sonra çalışır: Sabit/Eğri modundaki fanlara hız yazar
    function control() {
        if (!root.running || readOnly || quitting) return
        for (let i = 0; i < fans.length; i++) {
            if (boosting) {                          // maksimum fan: tüm fanlar %100
                if (fans[i].auto) lastSent[i] = undefined
                if (lastSent[i] !== 100) { lastSent[i] = 100; send(i, 100) }
                continue
            }
            const t = targets[i]
            if (!t) continue
            if (fans[i].auto) lastSent[i] = undefined   // servis auto'ya dönmüşse yeniden yaz
            const T = sourceTemp(i, t.src)
            const H = hottest(i)
            let pct
            if (isFinite(H) && H >= safety) { pct = 100; level[i] = 100 }   // güvenlik her şeyin önünde
            else if (t.mode === 1) { pct = t.fixed * 100; level[i] = undefined }
            else if (isFinite(T)) { pct = curveLevel(i, t, T); level[i] = pct }
            else continue
            if (!isFinite(pct)) continue
            pct = Math.max(0, Math.min(100, Math.round(pct)))
            const last = lastSent[i]
            if (last === undefined || Math.abs(pct - last) >= 2 || (pct !== last && (pct === 0 || pct === 100))) {
                lastSent[i] = pct
                send(i, pct)
            }
        }
    }
    property double lastFailNote: 0
    function send(i, pct) {
        enqueue("spd:" + i, ["nbfc", "set", "-f", String(i), "-s", String(pct)], (code, out, err) => {
            if (code === 0) return
            root.lastSent[i] = undefined             // sonraki turda yeniden dener
            root.commandFailed("Fan " + (i + 1) + " hızı yazılamadı: " + root.firstLine(err !== "" ? err : out))
        })
    }

    // ---------- maksimum fan ----------
    // boostUntil: 0 kapalı, -1 süresiz, >0 bitiş zamanı (ms)
    property double boostUntil: 0
    readonly property bool boosting: boostUntil !== 0
    function setBoost(minutes) {
        if (minutes > 0) boostUntil = Date.now() + minutes * 60000
        else if (minutes < 0) boostUntil = -1
        else if (boosting) {
            boostUntil = 0
            // her fan kendi ayarına: kaydı olmayanlar NBFC otomatiğe, Sabit/Eğri olanlar yeniden hesaplanır
            for (let i = 0; i < fans.length; i++) {
                lastSent[i] = undefined
                level[i] = undefined
                if (!targets[i]) enqueue("auto:" + i, ["nbfc", "set", "-f", String(i), "-a"], null)
            }
        }
        control()
    }
    function checkBoost() {
        if (boostUntil > 0 && Date.now() >= boostUntil) { setBoost(0); boostEnded() }
    }

    // ---------- geçmiş (son 10 dk, her durum okumasında bir örnek) ----------
    property var history: []                 // [{ t: ms, cpu: °C, gpu: °C|NaN, fan: % (ortalama) }]
    readonly property int historyMs: 600000
    function record() {
        const now = Date.now()
        const fanAvg = fans.length ? fans.reduce((a, f) => a + f.current, 0) / fans.length : NaN
        const h = history.filter(x => now - x.t <= historyMs)
        h.push({ t: now, cpu: temp, gpu: Sensors.gpu, fan: fanAvg })
        history = h
    }

    // Uygulamayı tamamen kapat: önce kontrol ettiğimiz fanları NBFC'nin otomatik kontrolüne geri ver
    property bool quitting: false
    function releaseAndQuit() {
        if (quitting) return
        quitting = true
        // Önce klavye efektini sabit renge döndür (yarıda karanlık kalmasın), sonra fanları bırak
        Keyboard.restoreForQuit(() => root.releaseFansAndQuit())
    }
    function releaseFansAndQuit() {
        const owned = Object.keys(targets).length > 0 || boosting
        targets = ({})
        boostUntil = 0
        if (owned && running) enqueue("quit", ["nbfc", "set", "-a"], () => Qt.quit())
        else Qt.quit()
    }

    // ---------- altyapı ----------
    Cmd { id: runner }
    Cmd { id: statusCmd }
    // Pencere açıkken ya da fan kontrol ederken 2 sn; gizli ve her şey NBFC'deyken 5 sn
    Timer { interval: root.uiVisible || root.controlling ? 2000 : 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.poll() }

    FileView {
        path: "/etc/nbfc/nbfc.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.configId = JSON.parse(text()).SelectedConfigId || "" }
            catch (e) { root.configId = "" }
        }
    }

    onConfigIdChanged: { mergeConfigs(); loadConfigCurves() }
    Component.onCompleted: { loadConfigs(); refreshBoot() }
}
