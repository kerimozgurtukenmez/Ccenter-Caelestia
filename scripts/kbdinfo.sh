#!/bin/sh
# Keyboard light detection (read only; runs when the Keyboard tab opens or the permission changes, not in a loop).
# Everything here is readable without root. Nothing is written.
# Output lines (fields separated by "|"):
#   dmi|vendor|product|version|family|board     laptop maker and model (/sys/class/dmi/id)
#   kernel|release
#   led|name|driver|path                        a keyboard light the kernel exposes (LED class)
#   v|name|file|value                           a readable value of that light
#   w|name|file                                 a file of that light we may write to (permission granted)
#   x|name|file                                 a file that exists (kbd_rgb_mode is write-only, so it can't be read)
#   usb|vendor|product|name                     USB devices of makers whose RGB keyboards are USB devices (ASUS, ITE/Lenovo)
#   rule|etc|current|legacy  rule|lib           our udev permission rule; legacy = an older, less strict version
#                                               (world-writable 0666, or running a shell)
# Testing without the hardware: CCENTER_SYS=<folder> makes it read a fake /sys tree from that folder instead (the app
# then also writes into that fake tree, never to the real lights).
sys=${CCENTER_SYS:-}/sys
dmi=$sys/class/dmi/id
r() { v=""; [ -r "$1" ] && read -r v < "$1"; printf '%s' "$v"; }
echo "dmi|$(r $dmi/sys_vendor)|$(r $dmi/product_name)|$(r $dmi/product_version)|$(r $dmi/product_family)|$(r $dmi/board_name)"
echo "kernel|$(r /proc/sys/kernel/osrelease)"

for d in "$sys"/class/leds/*; do
  n=${d##*/}
  case "$n" in
    *::kbd_backlight|*::kbd_backlight_*|*::kbd_zoned_backlight-*) ;;
    *) continue ;;
  esac
  [ -e "$d/brightness" ] || continue
  drv=""
  [ -e "$d/device/driver" ] && drv=$(readlink -f "$d/device/driver") && drv=${drv##*/}
  echo "led|$n|$drv|$d"
  for f in brightness max_brightness multi_index multi_intensity multi_max_intensity; do
    [ -r "$d/$f" ] && { read -r v < "$d/$f"; echo "v|$n|$f|$v"; }
  done
  for f in brightness multi_intensity kbd_rgb_mode; do
    [ -e "$d/$f" ] && echo "x|$n|$f"
    [ -w "$d/$f" ] && echo "w|$n|$f"
  done
done

for u in "$sys"/bus/usb/devices/*; do
  [ -r "$u/idVendor" ] || continue
  read -r vid < "$u/idVendor"
  case "$vid" in 0b05|048d) ;; *) continue ;; esac
  echo "usb|$vid|$(r "$u/idProduct")|$(r "$u/product")"
done

f=/etc/udev/rules.d/90-ccenter.rules
if [ -f "$f" ]; then
  if grep -q -e '0666' -e '/bin/sh' "$f"; then echo "rule|etc|legacy"; else echo "rule|etc|current"; fi
fi
[ -f /usr/lib/udev/rules.d/90-ccenter.rules ] && echo "rule|lib"
true
