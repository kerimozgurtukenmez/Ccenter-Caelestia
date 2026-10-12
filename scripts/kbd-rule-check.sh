#!/bin/sh
# Checks a rendered udev rule (template with @UID@ already replaced) before it is installed as root.
# Accepts only comments, empty lines and the three chown lines of dist/90-ccenter.rules for one numeric user id.
# A udev rule can run anything as root, so a tampered or broken file must never be installed. Exit 0 = ok.
# Usage: kbd-rule-check.sh <rule file> <uid>
f=$1 uid=$2
case "$uid" in ""|*[!0-9]*) echo "kbd-rule-check: bad user id" >&2; exit 1 ;; esac
[ -f "$f" ] || { echo "kbd-rule-check: no rule file" >&2; exit 1; }
match='SUBSYSTEM=="leds", ACTION=="add|change", KERNEL=="*::kbd_backlight|*::kbd_backlight_*|*::kbd_zoned_backlight-*"'
n=0
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    ''|'#'*) continue ;;
  esac
  ok=""
  for a in brightness multi_intensity kbd_rgb_mode; do
    [ "$line" = "$match, TEST==\"$a\", RUN+=\"/bin/chown $uid /sys%p/$a\"" ] && ok=1
  done
  [ -n "$ok" ] || { echo "kbd-rule-check: unexpected line: $line" >&2; exit 1; }
  n=$((n + 1))
done < "$f"
[ "$n" -eq 3 ] || { echo "kbd-rule-check: expected 3 rule lines, found $n" >&2; exit 1; }
exit 0
