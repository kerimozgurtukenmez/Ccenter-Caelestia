pragma Singleton
import Quickshell
import QtQuick

// Fan ayarlarının tek kaynağı (arayüzden bağımsız, her zaman çalışır).
// Arayüz (FanCard/ProfileCard) sadece bunu gösterir ve buraya değişiklik bildirir; pencere kapalıyken
// arayüz bellekten silinse de fan kontrolü, profiller, terminal (IPC) ve tepsi buradan çalışır.
// st = { mode: 0 oto | 1 sabit | 2 eğri, fixed: 0..1, curve: [{t,s}], smooth, src: cpu|gpu|max, hyst }
Singleton {
    id: root

    readonly property var defaultCurve: [{ t: 45, s: 20 }, { t: 55, s: 40 }, { t: 65, s: 60 }, { t: 75, s: 80 }, { t: 85, s: 100 }]
    readonly property var autoSt: ({ mode: 0, fixed: 0.5, curve: defaultCurve, smooth: true, src: "cpu", hyst: 3 })
    // Eksik alanları varsayılanla tamamlar (kayıttan/profilden gelen st'ler)
    function full(s) {
        const o = Object.assign({}, autoSt, s || {})
        if (!o.curve || o.curve.length < 2) o.curve = defaultCurve
        return o
    }

    property var fanSt: []                   // fan sırasıyla st
    property var globalSt: autoSt
    property bool globalOn: false
    property bool restored: false
    property bool applying: false            // kayıttan/profilden yüklerken "elle değişti" sayılmasın

    // ---------- açılış: kayıtlı ayarları geri yükle ----------
    // Kaydı olmayan fanlara komut gönderilmez; NBFC'deki mevcut durumları gösterilir.
    function restore() {
        if (Nbfc.fans.length === 0) return
        if (restored && fanSt.length === Nbfc.fans.length) return
        restored = true
        applying = true
        const id = Nbfc.configId
        const sts = [], saved = []
        for (let i = 0; i < Nbfc.fans.length; i++) {
            const s = Settings.fanOf(id, i)
            if (s) { sts.push(full(s)); saved.push(i) }
            else {
                const f = Nbfc.fans[i]
                sts.push(full(f.auto ? { mode: 0 } : { mode: 1, fixed: Math.max(0, Math.min(1, f.target / 100)) }))
            }
        }
        fanSt = sts
        const g = Settings.globalOf(id)
        if (g) globalSt = full(g.st)
        globalOn = !!(g && g.on)
        if (globalOn) Nbfc.applyTarget(-1, globalSt)
        else for (const i of saved) Nbfc.applyTarget(i, fanSt[i])
        applying = false
    }
    Connections {
        target: Nbfc
        function onFansChanged() { Qt.callLater(root.restore) }
    }

    // ---------- arayüzden gelen değişiklikler ----------
    function setFan(i, st) {
        const a = fanSt.slice()
        a[i] = full(st)
        fanSt = a
        if (!globalOn) Nbfc.applyTarget(i, a[i])
        Settings.setFan(Nbfc.configId, i, a[i])
        manualEdit()
    }
    function setGlobal(st) {
        globalSt = full(st)
        if (globalOn) Nbfc.applyTarget(-1, globalSt)
        Settings.setGlobal(Nbfc.configId, globalOn, globalSt)
        manualEdit()
    }
    // Global açılınca global ayar tüm fanlara yazılır; kapanınca her fan kendi ayarına döner
    function setGlobalOn(on) {
        if (globalOn === on) return
        globalOn = on
        reapply()
        Settings.setGlobal(Nbfc.configId, globalOn, globalSt)
        manualEdit()
    }
    function reapply() {
        if (globalOn) Nbfc.applyTarget(-1, globalSt)
        else for (let i = 0; i < fanSt.length; i++) Nbfc.applyTarget(i, fanSt[i])
    }
    function manualEdit() { if (!applying) Settings.setActive(Nbfc.configId, "") }

    // ---------- profiller ----------
    function curveSt(pts, hyst) { return { mode: 2, fixed: 0.5, curve: pts, smooth: true, src: "max", hyst: hyst } }
    // Hazır profiller: tüm fanlara Global üzerinden aynı eğri, CPU ve GPU'dan sıcak olana bakar
    readonly property var builtins: [
        { name: "NBFC Otomatik", icon: "auto_mode", fans: {}, global: null },
        { name: "Sessiz", icon: "volume_off",
          global: { on: true, st: curveSt([{ t: 45, s: 0 }, { t: 55, s: 25 }, { t: 65, s: 40 }, { t: 75, s: 60 }, { t: 85, s: 100 }], 4) } },
        { name: "Dengeli", icon: "balance",
          global: { on: true, st: curveSt([{ t: 45, s: 20 }, { t: 55, s: 35 }, { t: 65, s: 55 }, { t: 75, s: 75 }, { t: 85, s: 100 }], 3) } },
        { name: "Performans", icon: "bolt",
          global: { on: true, st: curveSt([{ t: 40, s: 40 }, { t: 50, s: 55 }, { t: 60, s: 70 }, { t: 70, s: 85 }, { t: 80, s: 100 }], 2) } }
    ]
    function allProfiles() { return builtins.concat(Settings.profilesOf(Nbfc.configId)) }

    function snapshot(name) {
        const fans = {}
        for (let i = 0; i < fanSt.length; i++) fans[String(i)] = fanSt[i]
        return { name: name, fans: fans, global: { on: globalOn, st: globalSt } }
    }
    function applyProfile(p) {
        if (!restored) return
        applying = true
        const id = Nbfc.configId
        const a = []
        for (let i = 0; i < Nbfc.fans.length; i++) {
            const s = p.fans ? Settings.cleanSt(p.fans[String(i)]) : null
            a.push(full(s ?? { mode: 0 }))
            Settings.setFan(id, i, a[i])
        }
        fanSt = a
        const g = p.global ? Settings.cleanSt(p.global.st) : null
        if (g) globalSt = full(g)
        globalOn = !!(p.global && p.global.on && g)
        reapply()
        Settings.setGlobal(id, globalOn, globalSt)
        Settings.setActive(id, p.name)
        applying = false
    }
    // Arayüz, terminal ve tepsi profili adıyla uygular (Qt liste tiplerine takılmamak için asıl listeden alınır)
    function applyByName(name, fromIpc) {
        const key = String(name).trim().toLocaleLowerCase()
        const p = allProfiles().find(x => x.name.toLocaleLowerCase() === key)
        if (!p) return "Profil bulunamadı: " + name + "\n" + profileList()
        if (!restored) return "Fanlar henüz okunmadı (NBFC çalışıyor mu?), tekrar dene"
        if (!Nbfc.running) return "NBFC servisi çalışmıyor"
        if (Nbfc.readOnly) return "NBFC salt-okunur modda, fan hızı yazılamaz"
        applyProfile(p)
        if (fromIpc && Notify.profiles) Notify.send("Fan profili: " + p.name, "", "low", "dialog-information")
        return "Uygulandı: " + p.name
    }
    function profileList() {
        const active = Settings.activeOf(Nbfc.configId)
        return allProfiles().map(p => (p.name === active ? "* " : "  ") + p.name).join("\n")
    }
    function statusText() {
        const modes = ["Otomatik", "Sabit", "Eğri"]
        const active = Settings.activeOf(Nbfc.configId)
        const lines = [
            "Servis: " + (Nbfc.running ? "çalışıyor" : "durdu") + (Nbfc.readOnly ? " (salt-okunur)" : ""),
            "Config: " + (Nbfc.configId || "-"),
            "Profil: " + (active || "özel ayarlar"),
            "CPU: " + (isFinite(Nbfc.temp) ? Nbfc.temp.toFixed(1) + "°C" : "-") + "   GPU: " + (isFinite(Sensors.gpu) ? Sensors.gpu.toFixed(0) + "°C" : "-"),
            "Global: " + (globalOn ? "açık (" + modes[globalSt.mode] + ")" : "kapalı")
                + (Nbfc.boosting ? "   Maksimum fan: açık" : "")
        ]
        for (let i = 0; i < Nbfc.fans.length; i++) {
            const f = Nbfc.fans[i]
            const m = globalOn ? globalSt.mode : (fanSt[i] ? fanSt[i].mode : 0)
            lines.push("Fan " + (i + 1) + " (" + f.name + "): " + modes[m] + " · NBFC " + (f.auto ? "oto" : "elle")
                       + " · anlık %" + Math.round(f.current) + " · hedef %" + Math.round(f.target))
        }
        return lines.join("\n")
    }
}
