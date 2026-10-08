# Ccenter-Caelestia

A laptop control center for **fan control** and **keyboard lighting**, built with [Quickshell](https://quickshell.org) and themed to match [Caelestia dots](https://github.com/caelestia-dots).

> [!WARNING]
> **This project is in a very early stage. Use it at your own risk.**
>
> - It is developed and tested on a single machine (HP Victus 16, Arch Linux, Hyprland). It may not work on yours.
> - The fan section **writes fan speeds to your hardware** through NBFC. A wrong setting can make your laptop run hot. Keep an eye on temperatures.
> - In *Fixed* and *Curve* modes the app itself drives the fans. If the app is closed, the fans **stay at the last speed it set**. Switch the fans back to *Auto* before closing it, or run `nbfc set -a`.
> - Things will change and break without notice. The name is temporary too.
> - The interface is currently in Turkish only.

## Features

### Fan control (via NBFC-Linux)
- Live temperature, fan speed and service status
- Per-fan modes: **Auto**, **Fixed** (constant %), **Curve** (temperature → speed)
- Curve editor with draggable points, fine-tuning, smooth or stepped curves
- "Global" card that applies one setting to every fan
- Safety limit: above 90 °C, fans in Fixed/Curve mode go to 100%
- NBFC service controls (start / stop / restart, read-only mode, start on boot) and config selection
- CPU, GPU and iGPU temperatures. A sleeping NVIDIA GPU is not woken up just to read its temperature.

### Keyboard lighting
- **UI only for now, it does not control anything yet.** Color wheel, effect modes, brightness and speed are planned.

### Theming
- Reads Caelestia's color scheme (`~/.local/state/caelestia/scheme.json`) live and falls back to default colors if it is missing.

## Requirements

- [Quickshell](https://quickshell.org) (developed on 0.3.x)
- [nbfc-linux](https://github.com/nbfc-linux/nbfc-linux) with a working config for your laptop
- A polkit agent (service and config actions use `pkexec`)
- [Material Symbols Rounded](https://fonts.google.com/icons) font
- Optional: `nvidia-smi` (NVIDIA GPU temperature), `lspci` (GPU names)
- Optional: Caelestia dots (for matching colors)

## Installation

```sh
git clone https://github.com/kerimozgurtukenmez/Ccenter-Caelestia.git ~/.config/quickshell/Ccenter
qs -c Ccenter
```

Show or hide the window:

```sh
qs -c Ccenter ipc call cc toggle
```

On Hyprland the window may open floating. To tile it, add this to your config:

```
windowrule = match:title ^(Ccenter-Caelestia)$, tile on
```

(older syntax: `windowrulev2 = tile, title:^(Ccenter-Caelestia)$`)

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
