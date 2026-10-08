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
- Settings are saved in `~/.config/ccenter/settings.json`
- Safety limit: above 90 °C, fans in Fixed/Curve mode go to 100%
- NBFC service controls (start / stop / restart, read-only mode, start on boot) and config selection
- CPU, GPU and iGPU temperatures. A sleeping NVIDIA GPU is not woken up just to read its temperature.

### Keyboard lighting
- **UI only for now, it does not control anything yet.** Color wheel, effect modes, brightness and speed are planned.

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
- Optional: `nvidia-smi` (NVIDIA GPU temperature), `lspci` (GPU names)

## Installation

```sh
git clone https://github.com/kerimozgurtukenmez/Ccenter-Caelestia.git ~/.config/quickshell/Ccenter
qs -c Ccenter -n -d
```

Always start it with `-n` (no duplicate): two running copies would fight over the fans.

### Running in the background
- Closing the window does **not** quit Ccenter; it keeps controlling the fans in the background. Reopen it with `qs -c Ccenter ipc call cc open`.
- To quit completely, use the "Quit" button in the app or `qs -c Ccenter ipc call cc quit`. Fans that Ccenter was controlling are handed back to NBFC's automatic control first.
- "Start in background on login" in the app enables a systemd user service (`dist/ccenter.service`, linked into `~/.config/systemd/user`). Turning it off removes the link. When the service stops or crashes, fans are handed back to NBFC (`nbfc set -a`).

### Terminal control

```sh
qs -c Ccenter ipc call cc status            # fans, temperatures, active profile
qs -c Ccenter ipc call cc profiles          # list profiles (* = active)
qs -c Ccenter ipc call cc profile Sessiz    # apply a profile (case-insensitive)
qs -c Ccenter ipc call cc open              # open the window (also: hide, toggle)
qs -c Ccenter ipc call cc quit              # quit; fans go back to NBFC auto
```

Handy for Hyprland keybinds, e.g. `bind = SUPER, F9, exec, qs -c Ccenter ipc call cc profile Performans`.

The window uses the app ID `ccenter`, so you can target it in Hyprland rules with `class:^(ccenter)$`.

## Reverting changes

- Return fans to NBFC's automatic control: `nbfc set -a`
- Ccenter never edits NBFC config files. It only changes which config is selected. To go back to a config of your choice: `sudo nbfc config --set "<config name>"` followed by `sudo nbfc restart`

## Project layout

```
shell.qml           window and tabs
services/           backends (NBFC, sensors, colors)
utils/              helpers
components/         shared UI components
modules/fan/        fan tab
modules/keyboard/   keyboard tab
scripts/            sensor / hardware info scripts
assets/             images
```

## Status / roadmap

- [x] Fan control through NBFC
- [ ] Persist per-fan settings across restarts
- [ ] Keyboard RGB backend
- [ ] Sync keyboard colors with Caelestia
- [ ] English UI

Issues and feedback are welcome, but expect rough edges.
