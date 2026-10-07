pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// CPU / GPU / iGPU sıcaklıkları (hwmon + NVIDIA için nvidia-smi). Sadece sayfa görünürken okur.
Singleton {
    id: root
    property bool active: true
    property var readings: []     // [{ label, value (°C ya da NaN), note }]

    function parse(txt) {
        let pkg = NaN, coreMax = NaN, amdCpu = NaN, acpi = NaN
        let nv = NaN, nvNote = "", hasNv = false, amdGpu = NaN, igpu = NaN
        for (const line of txt.split("\n")) {
            const p = line.split("|")
            if (p.length !== 3) continue
            const n = p[0], l = p[1].toLowerCase(), raw = p[2]
            if (n === "nvidia" || n === "nouveau") {
                hasNv = true
                if (raw === "uyku") nvNote = "Uykuda"
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
        const out = [{ label: "CPU", value: cpu, note: "" }]
        let gpu = nv
        if (isFinite(amdGpu)) { if (hasNv) igpu = amdGpu; else gpu = amdGpu }
        if (hasNv || isFinite(gpu)) out.push({ label: "GPU", value: gpu, note: nvNote })
        if (isFinite(igpu)) out.push({ label: "iGPU", value: igpu, note: "" })
        readings = out
    }

    function poll() {
        if (cmd.running) return
        cmd.go(["sh", Quickshell.shellPath("sensors.sh")], (code, out) => root.parse(out))
    }

    Cmd { id: cmd }
    Timer { interval: 3000; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: root.poll() }
}
