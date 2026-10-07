pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

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
    property real safety: 90              // bu sıcaklıkta özel modlardaki fanlar %100'e çıkar
    readonly property var temps: [45, 55, 65, 75, 85]

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
        if (runner.running || queue.length === 0) return
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
    function startService() { sudo(["nbfc", "start"].concat(readOnly ? ["-r"] : []), "Yönetici izni bekleniyor…") }
    function stopService() { sudo(["nbfc", "stop"], "Yönetici izni bekleniyor…") }
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
        const from = cfgFromDir.length > 0 ? " (/usr/share/nbfc/configs)" : cfgFromCli.length > 0 ? " (nbfc config -l)" : ""
        configNote = (all.length > 0 ? all.length + " config" + from : "Liste alınamadı") + (cfgNoteCli !== "" ? " · " + cfgNoteCli : "")
    }
    function loadConfigs() {
        enqueue("cfg:list", ["nbfc", "config", "-l"], (code, out, err) => {
            console.log("[ccenter] nbfc config -l (çıkış " + code + "): " + root.lines(out).length + " satır " + err)
            root.cfgFromCli = code === 0 ? root.lines(out) : []
            root.cfgNoteCli = code === 0 ? "" : "nbfc config -l başarısız (kod " + code + "): " + root.firstLine(err !== "" ? err : out)
            root.mergeConfigs()
        })
        enqueue("cfg:dir", ["sh", "-c", 'for d in /usr/share/nbfc/configs /etc/nbfc/configs; do [ -d "$d" ] && ls -1 "$d"; done | grep "\\.json$" | sed "s/\\.json$//"'], (code, out) => {
            root.cfgFromDir = root.lines(out)
            root.mergeConfigs()
        })
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
        if (statusCmd.running) return
        statusCmd.go(["nbfc", "status", "-a"], (code, out, err) => {
            if (!root.logged) {
                root.logged = true
                console.log("[ccenter] nbfc status -a (çıkış " + code + "):\n" + out + err)
            }
            root.running = code === 0
            if (code === 0) {
                root.applyStatus(root.parseStatus(out))
                root.control()
            } else {
                root.temp = NaN
            }
        })
    }

    // ---------- fan kontrolü ----------
    function tempOf(i) {
        const t = fans[i] ? fans[i].temp : NaN
        return isFinite(t) ? t : temp
    }

    function curveAt(pts, T) {
        const xs = temps
        if (T <= xs[0]) return pts[0] * 100
        for (let i = 1; i < xs.length; i++) {
            if (T <= xs[i])
                return (pts[i - 1] + (pts[i] - pts[i - 1]) * (T - xs[i - 1]) / (xs[i] - xs[i - 1])) * 100
        }
        return pts[pts.length - 1] * 100
    }

    // idx = fan index, -1 = tüm fanlar. st = { mode: 0 oto | 1 sabit | 2 eğri, fixed: 0..1, curve: [0..1 x5] }
    function applyTarget(idx, st) {
        const ids = idx < 0 ? fans.map((f, i) => i) : [idx]
        const t = Object.assign({}, targets)
        for (const i of ids) {
            lastSent[i] = undefined
            if (st.mode === 0) delete t[i]; else t[i] = st
        }
        targets = t
        if (st.mode === 0) {
            enqueue(idx < 0 ? "auto:all" : "auto:" + idx,
                    idx < 0 ? ["nbfc", "set", "-a"] : ["nbfc", "set", "-f", String(idx), "-a"], null)
        } else {
            control()
        }
    }

    // Her durum okumasından sonra çalışır: Sabit/Eğri modundaki fanlara hız yazar
    function control() {
        if (!root.running || readOnly) return
        for (let i = 0; i < fans.length; i++) {
            const t = targets[i]
            if (!t) continue
            if (fans[i].auto) lastSent[i] = undefined   // servis auto'ya dönmüşse yeniden yaz
            const T = tempOf(i)
            let pct
            if (isFinite(T) && T >= safety) pct = 100
            else if (t.mode === 1) pct = t.fixed * 100
            else if (isFinite(T)) pct = curveAt(t.curve, T)
            else continue
            pct = Math.max(0, Math.min(100, Math.round(pct)))
            const last = lastSent[i]
            if (last === undefined || Math.abs(pct - last) >= 2 || (pct !== last && (pct === 0 || pct === 100))) {
                lastSent[i] = pct
                enqueue("spd:" + i, ["nbfc", "set", "-f", String(i), "-s", String(pct)], null)
            }
        }
    }

    // ---------- altyapı ----------
    Cmd { id: runner }
    Cmd { id: statusCmd }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.poll() }

    FileView {
        path: "/etc/nbfc/nbfc.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.configId = JSON.parse(text()).SelectedConfigId || "" }
            catch (e) { root.configId = "" }
        }
    }

    onConfigIdChanged: mergeConfigs()
    Component.onCompleted: { loadConfigs(); refreshBoot() }
}
