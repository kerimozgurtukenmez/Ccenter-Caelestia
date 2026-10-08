#!/bin/sh
# Runs once. Lines:  cpu|model|threads   and   gpu|vendor|pci-address|model
m=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^[[:space:]]*//')
echo "cpu|$m|$(nproc 2>/dev/null)"
for d in /sys/bus/pci/devices/*; do
  case "$(cat "$d/class" 2>/dev/null)" in 0x03*) ;; *) continue ;; esac
  v=$(cat "$d/vendor" 2>/dev/null); a=$(basename "$d"); n=""
  if [ "$v" = "0x10de" ]; then
    # NVIDIA: the driver's info file doesn't wake the card
    n=$(sed -n 's/^Model:[[:space:]]*//p' /proc/driver/nvidia/gpus/"$a"/information 2>/dev/null | head -n 1)
    # if it's asleep, don't touch lspci (reading config space can wake the card)
    [ -z "$n" ] && [ "$(cat "$d/power/runtime_status" 2>/dev/null)" = "suspended" ] && n="NVIDIA GPU"
  fi
  if [ -z "$n" ] && command -v lspci >/dev/null 2>&1; then
    n=$(lspci -s "$a" -vmm 2>/dev/null | awk -F'\t' '$1=="Device:"{print $2; exit}')
  fi
  echo "gpu|$v|$a|$n"
done
