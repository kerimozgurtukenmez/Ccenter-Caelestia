#!/bin/sh
# Her turda çalışır; bu yüzden sadece kabuk yerleşikleri (read, echo) kullanılır: dosya başına süreç açılmaz.
# Sadece uygulamanın kullandığı sensörler okunur (NVMe, Wi-Fi, RAM gibi aygıtlar boşuna uyandırılmaz).
# Çıktı satırları:
#   ad|etiket|miliderece        CPU / iGPU / AMD GPU sıcaklıkları
#   fan|sürücü|numara|rpm       fan devri (sürücü veriyorsa; bazı sürücüler hep 0 verir)
#   nvidia||miliderece          NVIDIA sıcaklığı   (nvidia||uyku: kart uykuda, nvidia||atla: bu tur okunmadı)
# $1 = "gpu" ise NVIDIA sıcaklığı nvidia-smi ile okunur (pahalı, ~30 ms); değilse atlanır.
for h in /sys/class/hwmon/hwmon*; do
  [ -r "$h/name" ] || continue
  read -r n < "$h/name"
  case "$n" in
    coretemp|k10temp|zenpower|acpitz|i915|xe|amdgpu|nouveau)
      for t in "$h"/temp*_input; do
        [ -r "$t" ] || continue
        read -r v < "$t" || continue
        l=""
        [ -r "${t%_input}_label" ] && read -r l < "${t%_input}_label"
        echo "$n|$l|$v"
      done ;;
  esac
  for f in "$h"/fan*_input; do
    [ -r "$f" ] || continue
    read -r v < "$f" || continue
    i=${f##*/fan}
    echo "fan|$n|${i%_input}|$v"
  done
done
# NVIDIA: kart uykudaysa nvidia-smi çağırıp onu uyandırma
for d in /sys/bus/pci/devices/*; do
  [ -r "$d/vendor" ] || continue
  read -r ven < "$d/vendor"
  [ "$ven" = "0x10de" ] || continue
  read -r cls < "$d/class"
  case "$cls" in 0x03*) ;; *) continue ;; esac
  rs=""
  [ -r "$d/power/runtime_status" ] && read -r rs < "$d/power/runtime_status"
  if [ "$rs" = "suspended" ]; then
    echo "nvidia||uyku"
  elif [ "$1" != "gpu" ]; then
    echo "nvidia||atla"
  elif command -v nvidia-smi >/dev/null 2>&1; then
    t=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null)
    t=${t%%[!0-9]*}
    [ -n "$t" ] && echo "nvidia||${t}000"
  fi
done
