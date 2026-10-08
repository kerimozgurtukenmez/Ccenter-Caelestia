pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.utils

// Keyboard backlight (the kernel LED interface): /sys/class/leds/*::kbd_backlight
//   brightness (0..max_brightness); if RGB, multi_intensity "r g b" (0..multi_max_intensity)
// No zones: the whole keyboard is one colour. Write access comes from the optional udev rule (dist/90-ccenter.rules).
// Effects are done in software (this service always runs, so they continue while the window is closed):
//   breathing: intensity eases between the lowest and highest level; the colour changes at the darkest point.
//   cycle:     continuous smooth transition between colours along the hue, without dimming.
Singleton {
    id: root

    property string dir: ""                   // e.g. /sys/class/leds/hp::kbd_backlight
    readonly property bool available: dir !== ""
    readonly property string name: dir.slice(dir.lastIndexOf("/") + 1)
    property bool rgb: false
    property bool writable: false
    property bool ready: false                // first read finished?
    property int maxBrightness: 255
    property var maxIntensity: [255, 255, 255]
    property int brightness: 0
    property color color: "white"             // chosen colour (at full intensity; brightness is separate)
    property string error: ""
    // Where the udev rule granting write access lives: "etc" (added by install.sh / "grant" button, removable from the app),
    // "lib" (added by a system package), "" (none)
    property string ruleAt: ""
    property bool permBusy: false

    // ---------- effect settings (settings.json -> kbd) ----------
    property string effect: "static"          // static | breathing | cycle
    property string source: "single"          // single (chosen colour) | multi (colour list) | theme (Caelestia)
    property var colors: ["#ff0000", "#00ff00", "#0040ff"]
    property real speed: 0.5                  // 0 slow .. 1 fast
    readonly property real period: 8 - 7 * speed   // one breath / one colour (s): 8 .. 1
    property bool paused: false               // effect pauses while the permission is being revoked (the saved choice is kept)
    readonly property bool effectActive: effect !== "static" && rgb && writable && !paused
    property int cycleIndex: 0                // index of the colour currently shown (the UI highlights it)
    property int themeCount: 3                // number of Caelestia colours (3..6)
    property real minLevel: 0                 // lowest breathing level (0..1); 0 = fully off
    property real maxLevel: 1                 // highest breathing level (0..1)

    // Caelestia colours are made vivid for the LED (theme colours are pastel; low saturation looks whitish on an LED)
    function vivid(c) {
        c = Qt.lighter(c, 1)
        return c.hsvSaturation < 0.05 ? Qt.rgba(1, 1, 1, 1) : Qt.hsva(c.hsvHue, Math.max(c.hsvSaturation, 0.85), 1, 1)
    }
    // Theme colours: the theme's primary colour first, then from secondary/tertiary and the theme's accent colours
    // the hues furthest from the ones already picked (themeCount in total). All from the theme; look-alikes are skipped.
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
    // Colours the effect goes through
    readonly property var cycle: source === "multi" ? colors.map(x => Qt.lighter(x, 1))
                               : source === "theme" ? themeColors : [color]

    // ---------- reading ----------
    function refresh(done) {
        // One go: directory, writability, values. Shell builtins only (read).
        reader.go(["sh", "-c",
            'for d in /sys/class/leds/*::kbd_backlight; do [ -e "$d/brightness" ] || continue; ' +
            'echo "dir|$d"; ' +
            'for f in brightness max_brightness multi_intensity multi_max_intensity multi_index; do ' +
            '  [ -r "$d/$f" ] && { read -r v < "$d/$f"; echo "$f|$v"; }; done; ' +
            '[ -w "$d/brightness" ] && echo "w|brightness"; [ -w "$d/multi_intensity" ] && echo "w|multi_intensity"; ' +
            'break; done; ' +
            '[ -f /etc/udev/rules.d/90-ccenter.rules ] && echo "rule|etc"; [ -f /usr/lib/udev/rules.d/90-ccenter.rules ] && echo "rule|lib"; true'],
            (code, out) => { root.parse(out); if (done) done() })
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
        if (!ready) loadSaved()               // load saved effect settings on the first read (the settings file is ready by now)
        ruleAt = /rule\|etc/.test(out) ? "etc" : /rule\|lib/.test(out) ? "lib" : ""
        dir = v.dir || ""
        rgb = !!v.multi_intensity && /red/.test(v.multi_index || "") && /green/.test(v.multi_index || "")
        writable = !!w.brightness && (!rgb || !!w.multi_intensity)
        maxBrightness = parseInt(v.max_brightness) || 255
        brightness = parseInt(v.brightness) || 0
        if (rgb) maxIntensity = (v.multi_max_intensity || "255 255 255").trim().split(/\s+/).map(x => parseInt(x) || 255)
        // While an effect runs, the hardware colour is just the current frame; don't overwrite the chosen colour with it
        if (rgb && !effectActive) {
            const it = v.multi_intensity.trim().split(/\s+/).map(x => parseInt(x) || 0)
            const order = (v.multi_index || "red green blue").trim().split(/\s+/)
            const ch = n => { const k = order.indexOf(n); return k < 0 ? 0 : it[k] / maxIntensity[k] }
            color = Qt.rgba(ch("red"), ch("green"), ch("blue"), 1)
        }
        ready = true
    }

    // ---------- writing ----------
    // colour (0..1) x level -> "R G B" (hardware scale)
    function intensity(c, level) {
        return [c.r, c.g, c.b].map((x, i) => Math.round(Math.max(0, Math.min(1, x * level)) * (maxIntensity[i] ?? 255))).join(" ")
    }
    // Changes show in the UI immediately; the file is written at most ~12 times/s (while dragging)
    property var pending: ({})
    function setBrightness(b) {
        if (!writable) { refresh(); return }  // without permission don't change the state; it may have been granted meanwhile, so check again
        brightness = Math.max(0, Math.min(maxBrightness, Math.round(b)))
        queue("brightness", String(brightness))
    }
    function setColor(c) {
        if (!rgb) return
        if (!writable) { refresh(); return }
        c = Qt.lighter(c, 1)                  // may also be a "#rrggbb" string (terminal, presets): convert to a colour
        color = Qt.rgba(c.r, c.g, c.b, 1)
        Settings.setKbd({ color: hex(color) })
        if (!effectActive) queue("multi_intensity", intensity(color, 1))   // with an effect running, the next frame applies it
        // Picking a colour at brightness 0 shows nothing; turn the light on so the user sees it
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
        // Colour first, then brightness (so the light never shows the new colour at the old brightness)
        for (const f of ["multi_intensity", "brightness"])
            if (pending[f] !== undefined) send(f, pending[f])
        pending = ({})
    }
    Timer { id: flush; interval: 80; onTriggered: root.writeNext() }

    // One persistent writer process (awk): starting a process per write would be costly during effects (25 frames/s).
    // awk reads its input buffered (bash "read" reads a pipe byte by byte, ~2x the CPU; Quickshell FileView ~3x).
    // Each write is two lines: file path, value. If a write fails, awk prints an error and exits.
    function send(file, value) {
        if (writer.running) writer.write(dir + "/" + file + "\n" + value + "\n")
    }
    function writeFailed(why) {
        error = I18n.t("Could not write to the keyboard light") + (why ? ": " + why : "")
        effect = "static"                     // permission lost: stop the effect (not saved to settings)
        refresh()                             // re-read the real value and permission
    }
    Process {
        id: writer
        running: root.available
        command: ["awk", "NR % 2 { f = $0; next } { print > f; close(f) }"]
        stdinEnabled: true
        stderr: SplitParser { onRead: line => root.writeFailed(line.replace(/^.*fatal: /, "")) }
        // If it exits (error), restart it so later writes work
        onExited: if (root.available) restartWriter.start()
    }
    Timer { id: restartWriter; interval: 1000; onTriggered: writer.running = true }

    // ---------- effects ----------
    function setEffect(e) {
        if (e === effect) return
        if (e === "cycle" && source === "single") setSource("multi")   // a cycle needs more than one colour
        effect = e
        Settings.setKbd({ effect: e })
        if (e === "static") queue("multi_intensity", intensity(color, 1))   // effect off: back to the chosen colour
        else { t0 = Date.now(); lastFrame = "" }
    }
    function setSource(s) { source = s; Settings.setKbd({ source: s }); lastFrame = "" }
    function setThemeCount(n) { themeCount = Math.max(3, Math.min(6, Math.round(n))); Settings.setKbd({ themeCount: themeCount }) }
    function setColors(list) { colors = list.slice(0, 6); Settings.setKbd({ colors: colors }) }
    function setSpeed(v) {
        // When the speed changes, continue from the same point of the breath (keep the phase)
        const now = Date.now(), p = ((now - t0) / 1000) / period
        speed = Math.max(0, Math.min(1, v))
        t0 = now - p * period * 1000
        saveSpeed.restart()
    }
    Timer { id: saveSpeed; interval: 500; onTriggered: Settings.setKbd({ speed: root.speed }) }
    // Lowest/highest level; if one passes the other, it pushes it along
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
    // Mix along the hue: no dark/muddy midpoint between vivid colours (red -> yellow -> green)
    function mixHsv(a, b, f) {
        if (a.hsvSaturation < 0.05 || b.hsvSaturation < 0.05) return mix(a, b, f)   // white/grey: plain RGB mix
        let d = b.hsvHue - a.hsvHue
        if (d > 0.5) d -= 1
        if (d < -0.5) d += 1
        const h = ((a.hsvHue + d * f) % 1 + 1) % 1
        return Qt.hsva(h, a.hsvSaturation + (b.hsvSaturation - a.hsvSaturation) * f, a.hsvValue + (b.hsvValue - a.hsvValue) * f, 1)
    }
    // At very low levels the channels round to tiny integers and the hue shifts (pink -> [1 0 0] red, for example);
    // when the strongest channel drops below this threshold the light turns off instead of showing a wrong colour
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
            // Colour cycle: from colour k to the next with an ease-in/ease-out transition; the light never dims
            const e = (1 - Math.cos(Math.PI * f)) / 2
            v = frame(n > 1 ? mixHsv(cycle[k % n], cycle[(k + 1) % n], e) : cycle[0], 1)
        } else {
            // Breathing: one colour per breath; the colour changes at the darkest point (f = 0), nothing in between
            const l = Math.pow((1 - Math.cos(2 * Math.PI * f)) / 2, 1.8)   // 0 -> 1 -> 0, a bit longer in the dark part (perceived brightness is not linear)
            v = frame(cycle[k % n], minLevel + (maxLevel - minLevel) * l)
        }
        if (v !== lastFrame) { lastFrame = v; send("multi_intensity", v) }
    }
    Timer {
        // ~80 frames per breath is smooth enough: 25 frames/s when fast, fewer when slow (less CPU)
        interval: Math.max(40, Math.min(100, root.period * 1000 / 80))
        repeat: true
        running: root.effectActive && writer.running
        onTriggered: root.tick()
    }

    // Flush pending (500 ms after dragging) speed/level saves into the settings right away
    function flushSaves() {
        if (saveSpeed.running) { saveSpeed.stop(); Settings.setKbd({ speed: speed }) }
        if (saveRange.running) { saveRange.stop(); Settings.setKbd({ min: minLevel, max: maxLevel }) }
    }
    // On quit: don't leave the keyboard dark in the middle of an effect; go back to the chosen static colour (then cb)
    function restoreForQuit(cb) {
        flushSaves()
        if (!effectActive) { cb(); return }
        effect = "static"                                   // not saved: the effect resumes on the next start
        oneShot.go(["sh", "-c", 'printf "%s\\n" "$2" > "$1"', "sh", dir + "/multi_intensity", intensity(color, 1)], () => cb())
    }

    // ---------- write permission (only when the user asks; via the system password dialog) ----------
    // The rule file ships with the app (dist/90-ccenter.rules); it goes to /etc/udev/rules.d and udev applies it right away.
    readonly property string ruleFile: Quickshell.shellPath("dist/90-ccenter.rules")
    function grantPermission() {
        permBusy = true
        error = ""
        perm.go(["pkexec", "sh", "-c",
                 'install -Dm644 "$1" /etc/udev/rules.d/90-ccenter.rules && udevadm control --reload-rules && ' +
                 'udevadm trigger --action=change --subsystem-match=leds && udevadm settle', "sh", ruleFile],
                (code, out, err) => root.permDone(code, out, err))
    }
    function revokePermission() {
        // Without permission the effect can't write: switch the keyboard to the chosen static colour and pause the effect.
        // The saved choice is kept, so the effect resumes once permission is granted again.
        if (effectActive) { paused = true; send("multi_intensity", intensity(color, 1)) }
        permBusy = true
        error = ""
        perm.go(["pkexec", "sh", "-c",
                 'rm -f /etc/udev/rules.d/90-ccenter.rules && udevadm control --reload-rules; ' +
                 'for f in /sys/class/leds/*::kbd_backlight/brightness /sys/class/leds/*::kbd_backlight/multi_intensity; do ' +
                 '[ -e "$f" ] && chmod 0644 "$f"; done; true'],
                (code, out, err) => root.permDone(code, out, err))
    }
    function permDone(code, out, err) {
        permBusy = false
        // 126/127: password dialog dismissed / not authorised
        if (code !== 0) error = code === 126 || code === 127 ? I18n.t("Cancelled.") : I18n.t("Failed: %1").arg((err || out).trim().split("\n")[0])
        // Unpause only after the new permission state has been read: if permission is gone, writable=false stops the effect;
        // if it was cancelled, the effect continues (unpausing earlier would make the effect write without permission and stop itself)
        refresh(() => { root.paused = false })
    }
    Cmd { id: perm }

    // For the terminal (IPC): "#rrggbb" and percent
    function hex(c) {
        const h = x => ("0" + Math.round(x * 255).toString(16)).slice(-2)
        return ("#" + h(c.r) + h(c.g) + h(c.b)).toUpperCase()
    }
    function noPermissionText() { return I18n.t("No write permission: Keyboard tab > 'Grant permission' (or install.sh)") }
    function statusText() {
        if (!available) return I18n.t("No keyboard light found (no /sys/class/leds/*::kbd_backlight)")
        const src = { single: I18n.t("chosen color"), multi: I18n.t("%1 colors").arg(colors.length),
                      theme: I18n.t("Caelestia theme, %1 colors").arg(themeCount) }
        const fx = effect === "breathing"
            ? I18n.t("breathing (%1, %2 s, %3%–%4%)").arg(src[source]).arg(I18n.num(period, 1)).arg(Math.round(minLevel * 100)).arg(Math.round(maxLevel * 100))
            : effect === "cycle" ? I18n.t("color cycle (%1, %2 s per color)").arg(src[source]).arg(I18n.num(period, 1)) : I18n.t("static")
        return I18n.t("Keyboard light: %1").arg(name) + " (" + (rgb ? I18n.t("RGB, single zone") : I18n.t("single color")) + ")"
            + "\n" + I18n.t("Color: %1").arg(rgb ? hex(color) : "-")
            + "\n" + I18n.t("Brightness: %1%").arg(Math.round(brightness * 100 / maxBrightness))
            + "\n" + I18n.t("Effect: %1").arg(fx)
            + (writable ? "" : "\n" + noPermissionText())
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
