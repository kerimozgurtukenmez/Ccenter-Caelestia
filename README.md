# Ccenter-Caelestia

A laptop control center for **fan control** and **keyboard lighting**, built with [Quickshell](https://quickshell.org) and themed to match [Caelestia dots](https://github.com/caelestia-dots).

> [!WARNING]
> **This project is in a very early stage. Use it at your own risk.**
>
> - It is developed and tested on a single machine (HP Victus 16, Arch Linux, Hyprland). It may not work on yours.
> - The fan section **writes fan speeds to your hardware** through NBFC. A wrong setting can make your laptop run hot. Keep an eye on temperatures.
> - In *Fixed* and *Curve* modes the app itself drives the fans. Closing the window keeps it running in the background; quitting it hands the fans back to NBFC. If the app is killed in another way, the fans **stay at the last speed it set**; run `nbfc set -a` to return them to automatic control.
> - Things will change and break without notice. The name is temporary too.
> - The interface is currently in Turkish only.

## Features

### Fan control (via NBFC-Linux)
- Live temperature, fan speed and service status
- Per-fan modes: **Auto**, **Fixed** (constant %), **Curve** (temperature → speed)
- Curve editor with draggable points, fine-tuning, smooth or stepped curves
- "Global" card that applies one setting to every fan
- Profiles: built-in (NBFC Auto, Quiet, Balanced, Performance) and your own saved ones
- Per-fan temperature source in Curve mode (CPU, GPU or the hotter one)
- Hysteresis and gradual slow-down in Curve mode, so fans don't keep revving up and down
- Shows your NBFC config's own fan curve and lets you copy it into an editable curve
- Max fan button (5 min, 15 min or until turned off)
- Last 10 minutes graph of CPU/GPU temperature and fan speed
- Desktop notifications through Caelestia: critical temperature, NBFC service stopped, fan speed could not be set, max fan ended, profile switched from a keybind (can be turned off)
- Real fan RPM when the driver reports it
- Tray icon in the Caelestia bar: click to show/hide, hover for profiles, max fan and quit
- Light on resources: ~0.5% CPU in the background when NBFC is in control
- Settings are saved in `~/.config/ccenter/settings.json`
- Safety limit: above 90 °C, fans in Fixed/Curve mode go to 100%
- NBFC service controls (start / stop / restart, read-only mode, start on boot) and config selection
- CPU, GPU and iGPU temperatures. A sleeping NVIDIA GPU is not woken up just to read its temperature.

### Keyboard lighting
- Change the keyboard **color** (color wheel, presets, or your Caelestia theme color) and **brightness**
- Works with the kernel's keyboard backlight interface (`/sys/class/leds/*::kbd_backlight`); single-zone RGB (the whole keyboard is one color) or brightness only on non-RGB keyboards
- Effects (breathing, rainbow, …) are not there yet

### Caelestia integration
- Colors follow Caelestia's scheme (`~/.local/state/caelestia/scheme.json`) live.
- Rounding, spacing, fonts, animations and transparency come from your Caelestia shell settings, so the app looks like the rest of your shell. With Hyprland blur enabled, the window is blurred like Caelestia's panels.
- Ccenter only **reads** Caelestia files and never modifies them.

## Requirements

- [Quickshell](https://quickshell.org) (developed on 0.3.x)
- [Caelestia shell](https://github.com/caelestia-dots/shell) (`caelestia-shell`): Ccenter imports its QML plugin for design tokens, so it **will not start without it**
- [nbfc-linux](https://github.com/nbfc-linux/nbfc-linux) with a working config for your laptop
- A polkit agent (service and config actions use `pkexec`)
- [Material Symbols Rounded](https://fonts.google.com/icons) font
- `make` (for installing)
- Optional: `python-gobject` (tray icon in the Caelestia bar), `nvidia-smi` (NVIDIA GPU temperature), `lspci` (GPU names)

## Installation

```sh
git clone https://github.com/kerimozgurtukenmez/Ccenter-Caelestia.git
cd Ccenter-Caelestia
sudo make install
```

Then start **Ccenter** from your app launcher, or run `ccenter`.

This installs:

| What | Where |
|---|---|
| App files | `/usr/share/ccenter/` |
| `ccenter` command | `/usr/bin/ccenter` |
| Launcher entry and icon | `/usr/share/applications/ccenter.desktop`, `/usr/share/icons/hicolor/scalable/apps/ccenter.svg` |
| Background service (off until you enable it) | `/usr/lib/systemd/user/ccenter.service` |
| Keyboard backlight permission (udev rule) | `/usr/lib/udev/rules.d/90-ccenter.rules` |

The udev rule lets Ccenter change the keyboard light without root: it makes only the `brightness` and `multi_intensity` files of `*::kbd_backlight` writable. Uninstalling removes the rule and restores the permissions.

Nothing is written to your home folder during installation. The app itself only writes its settings to `~/.config/ccenter/settings.json`, and only after you change something.

The cloned folder is not needed after installation; you can delete it. To update later, pull or clone again and run `sudo make install`.

### Uninstall

```sh
sudo make uninstall
```

Your settings in `~/.config/ccenter` are kept; delete that folder too if you want a clean slate. If you enabled the background service, run `systemctl --user disable ccenter.service` first.

### Running in the background
- Closing the window does **not** quit Ccenter; it keeps controlling the fans in the background. Open it again from the launcher, the tray icon or with `ccenter`.
- To quit completely, use the "Quit" button in the app, the tray menu or `ccenter quit`. Fans that Ccenter was controlling are handed back to NBFC's automatic control first.
- "Start in background on login" in the app enables the systemd user service. When the service stops or crashes, fans are handed back to NBFC (`nbfc set -a`).
- Only one copy of Ccenter runs at a time. `ccenter` refuses to start a second copy, because two copies would fight over the fans.

### Terminal control

```sh
ccenter                     # open the window (starts the app if needed)
ccenter status              # fans, temperatures, active profile
ccenter profiles            # list profiles (* = active)
ccenter profile Sessiz      # apply a profile (case-insensitive)
ccenter boost 15            # max fan for 15 minutes (0 = off, -1 = until turned off)
ccenter kbd color "#ff0000" # keyboard color
ccenter kbd brightness 50   # keyboard brightness in percent (0 = off)
ccenter hide                # also: open, toggle
ccenter quit                # quit; fans go back to NBFC auto
ccenter --help
```

Handy for Hyprland keybinds, e.g. `bind = SUPER, F9, exec, ccenter profile Performans`.

The window uses the app ID `ccenter`, so you can target it in Hyprland rules with `class:^(ccenter)$`.

## Reverting changes

- Return fans to NBFC's automatic control: `nbfc set -a`
- Ccenter never edits NBFC config files. It only changes which config is selected. To go back to a config of your choice: `sudo nbfc config --set "<config name>"` followed by `sudo nbfc restart`
- Remove the app: `sudo make uninstall` (see above)

## Development

Run it straight from the cloned folder without installing:

```sh
./bin/ccenter
```

`bin/ccenter` uses the folder it lives in, so the same commands work (`./bin/ccenter status`, …). Quit the installed copy first; only one copy can run at a time. For keyboard control without a full install, `sudo make udev` installs just the udev rule (`sudo make uninstall-udev` removes it). Quickshell reloads the UI live when you save a file.

## Project layout

```
shell.qml           window, tabs, terminal commands (IPC), tray wiring
services/           always-running backends: NBFC, fan state, settings, sensors, colors, notifications, tray
modules/fan/        fan tab (UI only)
modules/keyboard/   keyboard tab
components/         shared UI components
utils/              helpers
scripts/            sensor / hardware info scripts, tray icon helper
assets/             icons and images
bin/ccenter         launcher and terminal commands
dist/               desktop entry and systemd user service
Makefile            install / uninstall
```

## Status / roadmap

- [x] Fan control through NBFC
- [x] Persist per-fan settings across restarts
- [x] Profiles, background mode, tray icon, notifications
- [x] System-wide installation (`make install`)
- [x] Keyboard color and brightness
- [ ] Keyboard effects (breathing, rainbow, …)
- [ ] Keep the keyboard color in sync with the Caelestia theme automatically (one-click theme color is already there)
- [ ] English UI

Issues and feedback are welcome, but expect rough edges.
