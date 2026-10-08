import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

Flickable {
    id: page
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    // Açılışta kayıtlı ayarları geri yükle (fanlar ilk kez görününce, bir kez).
    // Kaydı olmayan fanlara dokunulmaz: NBFC'deki mevcut durumları gösterilir.
    property bool restored: false
    property bool applying: false            // kayıttan/profilden yüklerken "elle değişti" sayılmasın
    function restore() {
        if (restored || Nbfc.fans.length === 0 || fanRep.count !== Nbfc.fans.length) return
        restored = true
        applying = true
        const id = Nbfc.configId
        const g = Settings.globalOf(id)
        if (g) globalCard.restore(g.st)
        const saved = []
        for (let i = 0; i < fanRep.count; i++) {
            const s = Settings.fanOf(id, i)
            if (s) { fanRep.itemAt(i).restore(s); saved.push(i) }
        }
        if (g && g.on) {
            globalCard.globalOn = true           // onGlobalOnChanged -> reapply (global ayar tüm fanlara)
        } else {
            for (const i of saved) Nbfc.applyTarget(i, fanRep.itemAt(i).st)
        }
        applying = false
    }

    // ---------- profiller ----------
    readonly property var autoSt: ({ mode: 0, fixed: 0.5, curve: null, smooth: true, src: "cpu", hyst: 3 })
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

    function snapshot(name) {
        const fans = {}
        for (let i = 0; i < fanRep.count; i++) fans[String(i)] = fanRep.itemAt(i).st
        return { name: name, fans: fans, global: { on: globalCard.globalOn, st: globalCard.st } }
    }
    function applyProfile(p) {
        if (!restored) return
        applying = true
        const id = Nbfc.configId
        for (let i = 0; i < fanRep.count; i++) {
            const s = p.fans ? Settings.cleanSt(p.fans[String(i)]) : null
            fanRep.itemAt(i).restore(s ?? autoSt)
            Settings.setFan(id, i, fanRep.itemAt(i).st)
        }
        const g = p.global ? Settings.cleanSt(p.global.st) : null
        if (g) globalCard.restore(g)
        const on = !!(p.global && p.global.on && g)
        if (globalCard.globalOn !== on) {
            globalCard.globalOn = on             // onGlobalOnChanged -> reapply + kaydet
        } else {
            reapply()
            Settings.setGlobal(id, on, globalCard.st)
        }
        Settings.setActive(id, p.name)
        applying = false
    }
    // ---------- terminal (IPC) ----------
    function allProfiles() { return builtins.concat(Settings.profilesOf(Nbfc.configId)) }
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
            "Global: " + (globalCard.globalOn ? "açık (" + modes[globalCard.st.mode] + ")" : "kapalı")
        ]
        for (let i = 0; i < Nbfc.fans.length; i++) {
            const f = Nbfc.fans[i], card = fanRep.itemAt(i)
            const m = globalCard.globalOn ? globalCard.st.mode : (card ? card.st.mode : 0)
            lines.push("Fan " + (i + 1) + " (" + f.name + "): " + modes[m] + " · NBFC " + (f.auto ? "oto" : "elle")
                       + " · anlık %" + Math.round(f.current) + " · hedef %" + Math.round(f.target))
        }
        return lines.join("\n")
    }

    function manualEdit() { if (!applying) Settings.setActive(Nbfc.configId, "") }
    Connections {
        target: Nbfc
        function onFansChanged() { Qt.callLater(page.restore) }
    }

    // Global kapanınca her fan kendi kartındaki ayara döner; açılınca global kartın ayarı hepsine yazılır
    function reapply() {
        if (globalCard.globalOn) {
            Nbfc.applyTarget(-1, globalCard.st)
        } else {
            for (let i = 0; i < fanRep.count; i++) Nbfc.applyTarget(i, fanRep.itemAt(i).st)
        }
    }

    ColumnLayout {
        id: col
        width: page.width
        spacing: 12

        TempCard {}
        HistoryCard {}
        ServiceCard {}
        ConfigCard {}

        // Servis durmuşken ya da salt-okunur modda fan ayarları kilitli
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            enabled: Nbfc.running && !Nbfc.readOnly
            opacity: enabled ? 1 : 0.35
            Behavior on opacity { Anim {} }

            StyledText {
                visible: Nbfc.fans.length === 0
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Fan bilgisi yok. Servis çalışmıyor ya da config seçilmemiş olabilir."
                color: Colours.fgDim
                font.pixelSize: 12
            }

            ProfileCard {
                visible: Nbfc.fans.length > 0
                page: page
            }

            GridLayout {
                Layout.fillWidth: true
                columns: Math.max(1, Math.min(Nbfc.fans.length, 2))
                columnSpacing: 12
                rowSpacing: 12
                Repeater {
                    id: fanRep
                    model: Nbfc.fans.length
                    FanCard {
                        Layout.alignment: Qt.AlignTop
                        fanIndex: index
                        name: "Fan " + (index + 1)
                        subtitle: info ? info.name : ""
                        info: Nbfc.fans[index]
                        active: !globalCard.globalOn
                        onEdited: { Nbfc.applyTarget(index, st); Settings.setFan(Nbfc.configId, index, st); page.manualEdit() }
                    }
                }
            }

            FanCard {
                id: globalCard
                visible: Nbfc.fans.length > 0
                isGlobal: true
                name: "Global"
                subtitle: "Açıkken tüm fanlara aynı değerler yazılır"
                onEdited: {
                    if (globalOn) Nbfc.applyTarget(-1, st)
                    Settings.setGlobal(Nbfc.configId, globalOn, st)
                    page.manualEdit()
                }
                onGlobalOnChanged: {
                    page.reapply()
                    if (page.restored) Settings.setGlobal(Nbfc.configId, globalOn, st)
                    page.manualEdit()
                }
            }
        }

        NotifyCard {}
        BackgroundCard {}
    }
}
