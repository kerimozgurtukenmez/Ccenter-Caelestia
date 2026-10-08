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
- **Breathing effect**: the light fades in and out with your color, cycles through up to 6 colors of your choice, or uses your Caelestia theme colors (follows theme changes). Adjustable speed and lowest/highest level; with a lowest level above 0 the light never goes dark and the colors flow into each other. Keeps running when the window is closed and resumes after a restart
- **Color cycle effect**: the light flows smoothly between your colors (or the Caelestia theme colors) without dimming
- Caelestia colors: 3 to 6 colors taken from your current theme, picked so they look different from each other
- More effects (rainbow, …) are not there yet

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
./install.sh
```

Then start **Ccenter** from your app launcher, or run `ccenter`.

**No `sudo` needed.** `install.sh` installs into your own home folder and shows the exact plan before it writes anything:

| What | Where |
|---|---|
| App, `ccenter` command and icon | `~/.local/share/ccenter/` (the command is `~/.local/share/ccenter/bin/ccenter`) |
| Launcher entry | `~/.local/share/applications/ccenter.desktop` |
| Background service (off until you enable it) | `~/.local/share/systemd/user/ccenter.service` (or `~/.config/systemd/user/`) |
| Short `ccenter` command | `~/.local/bin/ccenter`, a link to the command above |

Everything lives in the app's own folder; the other entries are only added where they can be. If a folder is not writable (for example `~/.local/bin` owned by root because something was once installed there with `sudo`), or a file with the same name belongs to another program, that entry is skipped and the installer tells you why. Nothing of yours is overwritten and you never have to change permissions.

The app writes its settings to `~/.config/ccenter/settings.json`, and only after you change something.

### Permissions: asked, never taken silently

- **Keyboard light (optional).** To change the keyboard color and brightness, Ccenter needs write access to two files of your keyboard backlight (`/sys/class/leds/*::kbd_backlight/brightness` and `multi_intensity`). `install.sh` explains what this does and **asks** you; the default answer is no. Only if you say yes, your password is asked for that single step, which adds `/etc/udev/rules.d/90-ccenter.rules`. You can also grant it later from the Keyboard tab (the "İzin ver" button; your password is asked by the system's own dialog) and remove it there again ("İzni kaldır"). It only affects the keyboard light; it gives no access to fans, files or the system.
- **NBFC service actions** (start/stop/restart the fan service, apply a config) ask for your password through polkit every time you use them. Setting fan speeds does not need a password.

### Uninstall

```sh
./uninstall.sh
```

It shows what it will delete, quits Ccenter (keyboard back to your static color, fans back to NBFC) and asks separately whether to remove the keyboard permission and whether to keep your settings.

### Packaging / system-wide install

The `Makefile` is for packagers (`make DESTDIR=… PREFIX=/usr install`) or a system-wide install with `sudo make install`. It never adds the keyboard permission on its own; that is a separate, optional `sudo make udev`.

### Running in the background
- Closing the window does **not** quit Ccenter; it keeps controlling the fans in the background. Open it again from the launcher, the tray icon or with `ccenter`.
- To quit completely, use the "Quit" button in the app, the tray menu or `ccenter quit`. Fans that Ccenter was controlling are handed back to NBFC's automatic control first.
- "Start in background on login" in the app enables the systemd user service. Stopping the service quits Ccenter the same way as "Quit" (keyboard effect back to your static color, fans back to NBFC); if it crashes, fans are still handed back to NBFC (`nbfc set -a`).
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
ccenter kbd effect cycle    # keyboard effect: static | breathing | cycle
ccenter kbd source theme    # breathing colors: single | multi | theme (Caelestia)
ccenter kbd speed 60        # effect speed 0-100
ccenter kbd range 20 80     # breathing lowest and highest level in percent
ccenter kbd themecount 5    # number of Caelestia colors (3-6)
ccenter hide                # also: open, toggle
ccenter quit                # quit; fans go back to NBFC auto
ccenter --help
```

Handy for Hyprland keybinds, e.g. `bind = SUPER, F9, exec, ccenter profile Performans`.

The window uses the app ID `ccenter`, so you can target it in Hyprland rules with `class:^(ccenter)$`.

## Reverting changes

- Return fans to NBFC's automatic control: `nbfc set -a`
- Ccenter never edits NBFC config files. It only changes which config is selected. To go back to a config of your choice: `sudo nbfc config --set "<config name>"` followed by `sudo nbfc restart`
- Remove the app: `./uninstall.sh` (see above)

## Development

Run it straight from the cloned folder without installing:

```sh
./bin/ccenter
```

`bin/ccenter` uses the folder it lives in, so the same commands work (`./bin/ccenter status`, …). Quit the installed copy first; only one copy can run at a time. Keyboard permission works the same way (Keyboard tab > "İzin ver"). Quickshell reloads the UI live when you save a file.

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
install.sh          install into ~/.local (no sudo; asks about the keyboard permission)
uninstall.sh        remove it again
Makefile            system-wide install / packaging
```

## Status / roadmap

- [x] Fan control through NBFC
- [x] Persist per-fan settings across restarts
- [x] Profiles, background mode, tray icon, notifications
- [x] Installation without sudo (`./install.sh`), permissions only when you agree
- [x] Keyboard color and brightness
- [x] Keyboard breathing effect (one color, several colors or Caelestia theme colors)
- [x] Keyboard color cycle effect
- [ ] More keyboard effects (rainbow, …)
- [ ] Keep the keyboard color in sync with the Caelestia theme automatically (one-click theme color is already there)
- [ ] English UI

Issues and feedback are welcome, but expect rough edges.
