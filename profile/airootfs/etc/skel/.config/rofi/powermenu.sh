#!/usr/bin/env bash
choice=$(printf '  Lock\n  Log out\n  Reboot\n  Shut down\n' | rofi -dmenu -p power -theme-str 'window { width: 260px; } listview { lines: 4; }')
case "$choice" in
  *Lock)      hyprlock ;;
  *"Log out") hyprctl dispatch exit ;;
  *Reboot)    systemctl reboot ;;
  *"Shut down") systemctl poweroff ;;
esac
