#!/bin/sh
# Çıktı satırları: ad|etiket|miliderece   (NVIDIA için: nvidia||uyku  ya da  nvidia||miliderece)
for h in /sys/class/hwmon/hwmon*; do
  [ -r "$h/name" ] || continue
  n=$(cat "$h/name")
  for t in "$h"/temp*_input; do
    [ -r "$t" ] || continue
    b=$(echo "$t" | sed 's/_input$//')
    l=$(cat "$b"_label 2>/dev/null)
    v=$(cat "$t" 2>/dev/null)
    echo "$n|$l|$v"
  done
done
# NVIDIA: kart uykudaysa nvidia-smi çağırıp onu uyandırma
for d in /sys/bus/pci/devices/*; do
  [ "$(cat "$d/vendor" 2>/dev/null)" = "0x10de" ] || continue
  case "$(cat "$d/class" 2>/dev/null)" in 0x03*) ;; *) continue ;; esac
  if [ "$(cat "$d/power/runtime_status" 2>/dev/null)" = "suspended" ]; then
    echo "nvidia||uyku"
  elif command -v nvidia-smi >/dev/null 2>&1; then
    t=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1)
    case "$t" in ''|*[!0-9]*) ;; *) echo "nvidia||$((t * 1000))" ;; esac
  fi
done
