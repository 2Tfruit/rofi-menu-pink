#!/bin/bash
THEME="$HOME/.config/rofi/power.rasi"
# Язык
LANG_SYS=$(echo $LANG | cut -c1-2)
if [ "$LANG_SYS" = "ru" ]; then
  POWEROFF="Выключить"
  REBOOT="Перезагрузить"
  SLEEP="Сон"
  EXIT="Выход"
  PROMPT="Питание"
  YES="Да"
  NO="Нет"
else
  POWEROFF="Shutdown"
  REBOOT="Reboot"
  SLEEP="Sleep"
  EXIT="Exit"
  PROMPT="Power"
  YES="Yes"
  NO="No"
fi

confirm() {
  CONFIRM=$(echo -e "$YES\n$NO" | rofi -dmenu -theme "$THEME" -p "$1?" -u 1)
  [ "$CONFIRM" = "$YES" ]
}

main_menu() {
  CHOSEN=$(echo -e " $POWEROFF\n $REBOOT\n $SLEEP\n $EXIT" | rofi -dmenu -theme "$THEME" -p "  $PROMPT" -u 3)

  case "$CHOSEN" in
    " $POWEROFF") confirm " $POWEROFF" && systemctl poweroff || main_menu ;;
    " $REBOOT") confirm " $REBOOT" && systemctl reboot || main_menu ;;
    " $SLEEP") systemctl suspend ;;
    " $EXIT"|"") exit 0 ;;
  esac
}

main_menu
