pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.utils

// CPU / GPU / iGPU sıcaklıkları (hwmon + NVIDIA için nvidia-smi). Sadece sayfa görünürken okur.
Singleton {
    id: root
    property bool active: true
    // fast: pencere açık ya da Ccenter fan kontrol ediyor -> 3 sn'de bir, GPU her turda.
    // Değilse 5 sn'de bir ve GPU (nvidia-smi, pahalı) 4 turda bir (~20 sn).
    property bool fast: true
    property int tick: 0
    property real lastNv: NaN
    property string lastNvNote: ""
    property var readings: []     // [{ label, model, value (°C ya da NaN), note }]
    property var hw: ({ cpu: "", cores: "", gpu: "", igpu: "" })
    // Fan kontrolü için: harici GPU sıcaklığı (uykuda / yoksa NaN)
    readonly property real gpu: { const r = readings.find(x => x.label === "GPU"); return r ? r.value : NaN }
    readonly property bool hasGpu: readings.some(x => x.label === "GPU")
    // Fan RPM: sürücü bir kez bile 0'dan büyük değer verdiyse güvenilir sayılır (bazı sürücüler hep 0 döndürür)
    property var rpms: []                    // fan sırasıyla (fan1 -> 0)
    property bool rpmWorks: false
    function rpm(i) { return rpmWorks && i < rpms.length ? rpms[i] : NaN }

    // "13th Gen Intel(R) Core(TM) i7-13700H" -> "Intel Core i7-13700H"
    function cleanCpu(n) {
        return n.replace(/\((R|TM|tm|r)\)/g, "").replace(/^\d+(st|nd|rd|th) Gen\s+/i, "")
                .replace(/\s+(CPU|Processor)\b.*$/i, "").replace(/\s+@.*$/, "").replace(/\s+/g, " ").trim()
    }
    // "Raptor Lake-P [Iris Xe Graphics]" -> "Iris Xe Graphics"; "NVIDIA GeForce RTX 3050 6GB Laptop GPU" -> "GeForce RTX 3050 6GB Laptop GPU"
    function cleanGpu(n) {
        const b = n.match(/\[([^\]]+)\]/)
        return (b ? b[1] : n).replace(/^NVIDIA\s+/, "").trim()
    }
    function parseHw(txt) {
        const h = { cpu: "", cores: "", gpu: "", igpu: "" }
        const gpus = []
        for (const line of txt.split("\n")) {
            const p = line.split("|")
            if (p[0] === "cpu" && p.length >= 3) { h.cpu = cleanCpu(p[1]); h.cores = p[2] }
            else if (p[0] === "gpu" && p.length >= 4) gpus.push({ vendor: p[1], name: cleanGpu(p.slice(3).join("|")) })
        }
        const dgpu = gpus.find(g => g.vendor === "0x10de")
        const igpu = gpus.find(g => g.vendor === "0x8086") || (dgpu ? gpus.find(g => g.vendor === "0x1002") : null)
        const other = gpus.find(g => g !== dgpu && g !== igpu)
        h.gpu = dgpu ? dgpu.name : (other ? other.name : "")
        h.igpu = igpu ? igpu.name : ""
        hw = h
    }

    function parse(txt) {
        let pkg = NaN, coreMax = NaN, amdCpu = NaN, acpi = NaN
        let nv = NaN, nvNote = "", hasNv = false, amdGpu = NaN, igpu = NaN
        let fanDrv = "", fanRpm = []
        for (const line of txt.split("\n")) {
            const p = line.split("|")
            if (p[0] === "fan" && p.length === 4) {
                if (fanDrv === "") fanDrv = p[1]          // ilk fan sürücüsü (hp, thinkpad, dell_smm…)
                if (p[1] === fanDrv) fanRpm[parseInt(p[2]) - 1] = parseInt(p[3])
                continue
            }
            if (p.length !== 3) continue
            const n = p[0], l = p[1].toLowerCase(), raw = p[2]
            if (n === "nvidia" || n === "nouveau") {
                hasNv = true
                if (raw === "atla") { nv = lastNv; nvNote = lastNvNote }    // bu tur okunmadı: son değer
                else if (raw === "uyku") nvNote = "Uykuda"
                else nv = Math.max(isFinite(nv) ? nv : -1, parseInt(raw) / 1000)
                continue
            }
            const v = parseInt(raw) / 1000
            if (!isFinite(v)) continue
            if (n === "coretemp") {
                if (l.indexOf("package") >= 0) pkg = v
                else coreMax = isFinite(coreMax) ? Math.max(coreMax, v) : v
            } else if (n === "k10temp" || n === "zenpower") {
                if (!isFinite(amdCpu) || l.indexOf("tctl") >= 0 || l.indexOf("tdie") >= 0) amdCpu = v
            } else if (n === "acpitz") {
                if (!isFinite(acpi)) acpi = v
            } else if (n === "i915" || n === "xe") {
                igpu = v
            } else if (n === "amdgpu") {
                if (!isFinite(amdGpu) || l.indexOf("edge") >= 0) amdGpu = v
            }
        }
        const cpu = isFinite(pkg) ? pkg : (isFinite(amdCpu) ? amdCpu : (isFinite(coreMax) ? coreMax : acpi))
        const out = [{ label: "CPU", model: hw.cpu, extra: hw.cores !== "" ? hw.cores + " iş parçacığı" : "", value: cpu, note: "" }]
        let gpu = nv
        if (isFinite(amdGpu)) { if (hasNv) igpu = amdGpu; else gpu = amdGpu }
        if (hasNv || isFinite(gpu) || hw.gpu !== "") out.push({ label: "GPU", model: hw.gpu, extra: "", value: gpu, note: nvNote })
        if (isFinite(igpu) || hw.igpu !== "")
            out.push({ label: "iGPU", model: hw.igpu, extra: "", value: igpu, note: isFinite(igpu) ? "" : "Sensör yok" })
        if (hasNv) { lastNv = nv; lastNvNote = nvNote }   // "atla" turlarında bu değer kullanılır
        readings = out
        rpms = Array.from(fanRpm, v => isFinite(v) ? v : NaN)
        if (rpms.some(v => v > 0)) rpmWorks = true
    }

    function poll() {
        if (cmd.busy) return
        const gpu = fast || tick % 4 === 0
        tick++
        cmd.go(["sh", Quickshell.shellPath("scripts/sensors.sh")].concat(gpu ? ["gpu"] : []), (code, out) => root.parse(out))
    }

    Cmd { id: cmd }
    Cmd { id: hwCmd }
    Component.onCompleted: hwCmd.go(["sh", Quickshell.shellPath("scripts/hwinfo.sh")], (code, out) => root.parseHw(out))
    Timer { interval: root.fast ? 3000 : 5000; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: root.poll() }
}
