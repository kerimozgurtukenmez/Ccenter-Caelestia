#!/bin/sh
# Bir kez çalışır. Satırlar:  cpu|model|çekirdek   ve   gpu|vendor|pci-adresi|model
m=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^[[:space:]]*//')
echo "cpu|$m|$(nproc 2>/dev/null)"
for d in /sys/bus/pci/devices/*; do
  case "$(cat "$d/class" 2>/dev/null)" in 0x03*) ;; *) continue ;; esac
  v=$(cat "$d/vendor" 2>/dev/null); a=$(basename "$d"); n=""
  if [ "$v" = "0x10de" ]; then
    # NVIDIA: sürücünün bilgi dosyası kartı uyandırmaz
    n=$(sed -n 's/^Model:[[:space:]]*//p' /proc/driver/nvidia/gpus/"$a"/information 2>/dev/null | head -n 1)
    # uykudaysa lspci'ye dokunma (config alanını okumak kartı uyandırabilir)
    [ -z "$n" ] && [ "$(cat "$d/power/runtime_status" 2>/dev/null)" = "suspended" ] && n="NVIDIA GPU"
  fi
  if [ -z "$n" ] && command -v lspci >/dev/null 2>&1; then
    n=$(lspci -s "$a" -vmm 2>/dev/null | awk -F'\t' '$1=="Device:"{print $2; exit}')
  fi
  echo "gpu|$v|$a|$n"
done
