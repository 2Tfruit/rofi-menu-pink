#!/bin/bash

# Проверка зависимостей
MISSING=""
for cmd in nmcli rofi notify-send; do
  if ! command -v "$cmd" &>/dev/null; then
    MISSING="$MISSING $cmd"
    echo "Ошибка: $cmd не установлен"
  fi
done

if [ -n "$MISSING" ]; then
  exit 1
fi

THEME="$HOME/.config/rofi/wifi.rasi"
# Язык
LANG_SYS=$(echo $LANG | cut -c1-2)
if [ "$LANG_SYS" = "ru" ]; then
  SCAN="Список сетей"
  TOGGLE_ON="Включить WiFi"
  TOGGLE_OFF="Выключить WiFi"
  CURRENT="Текущее подключение"
  DISCONNECT="Отключиться"
  FORGET="Забыть сеть"
  EXIT="Выход"
  PROMPT="WiFi"
  PROMPT_NETWORKS="Выбери сеть"
  NO_CONNECTION="Нет подключения"
  ENTER_PASS="Введи пароль: "
  CONNECTED_OK="Подключено"
  LOADING="Загрузка сетей..."
  LOADING_CURRENT="Получение информации..."
  YES="Да"
  NO="Нет"
else
  SCAN="Network list"
  TOGGLE_ON="Enable WiFi"
  TOGGLE_OFF="Disable WiFi"
  CURRENT="Current connection"
  DISCONNECT="Disconnect"
  FORGET="Forget network"
  EXIT="Exit"
  PROMPT="WiFi"
  PROMPT_NETWORKS="Select network"
  NO_CONNECTION="No connection"
  ENTER_PASS="Enter password: "
  CONNECTED_OK="Connected"
  LOADING="Loading networks..."
  LOADING_CURRENT="Getting info..."
  YES="Yes"
  NO="No"
fi
wifi_status() {
  nmcli radio wifi
}
current_connection() {
  nmcli -t -f NAME,TYPE connection show --active | grep '802-11-wireless' | cut -d: -f1
}
get_iface() {
  nmcli -t -f DEVICE,TYPE device | grep ':wifi$' | head -1 | cut -d: -f1
}
show_current() {
  CONN=$(current_connection)
  if [ -z "$CONN" ]; then
    echo "$NO_CONNECTION" | rofi -dmenu -theme "$THEME" -p "  $CURRENT"
    main_menu
    return
  fi

  notify-send "WiFi" "$LOADING_CURRENT" -t 10000

  SIGNAL=$(nmcli -t -f IN-USE,SIGNAL device wifi list | grep '^\*' | cut -d: -f2)
  IP=$(nmcli -t -f IP4.ADDRESS device show | head -1 | cut -d: -f2)

  pkill -x dunst && dunst &

  ACTION=$(echo -e " $CONN\n $SIGNAL%\n $IP\n $FORGET" | rofi -dmenu -theme "$THEME" -p "  $CURRENT" -u 3)
  case "$ACTION" in
    " $FORGET")
      CONFIRM=$(echo -e "$YES\n$NO" | rofi -dmenu -theme "$THEME" -p "$FORGET?" -u 1)
      if [ "$CONFIRM" = "$YES" ]; then
        IFACE=$(get_iface)
        nmcli device disconnect "$IFACE" 2>/dev/null
        nmcli connection delete "$CONN" 2>/dev/null
      else
        show_current
      fi
      ;;
    "") main_menu ;;
    *) show_current ;;
  esac
}
show_networks() {
  notify-send "WiFi" "$LOADING" -t 10000

  NETWORKS=$(nmcli -t -f SSID,SIGNAL,SECURITY device wifi list | while IFS=: read -r SSID SIGNAL SECURITY; do
    [ -z "$SSID" ] && continue
    if [ "$SECURITY" = "--" ]; then
      echo -e " $SSID ($SIGNAL%)"
    else
      echo -e " $SSID ($SIGNAL%)"
    fi
  done)

  pkill -x dunst && dunst &

  CHOSEN=$(echo "$NETWORKS" | rofi -dmenu -theme "$THEME" -p "  $PROMPT_NETWORKS")
  [ -z "$CHOSEN" ] && main_menu && return

  SSID=$(echo "$CHOSEN" | sed 's/ ([0-9]*%)$//' | sed 's/^[[:space:]]*//' | sed 's/^. //')

  SAVED=$(nmcli -t -f NAME connection show | grep -x "$SSID")

  if [ -n "$SAVED" ]; then
    nmcli connection up "$SSID" 2>/dev/null
  else
    PASS=$(rofi -dmenu -theme "$THEME" -p "  $ENTER_PASS" -theme-str 'entry { enabled: true; visibility: false; }')
    [ -z "$PASS" ] && main_menu && return
    nmcli device wifi connect "$SSID" password "$PASS" 2>/dev/null
  fi
}
confirm_disconnect() {
  CONFIRM=$(echo -e "$YES\n$NO" | rofi -dmenu -theme "$THEME" -p "$DISCONNECT?" -u 1)
  if [ "$CONFIRM" = "$YES" ]; then
    IFACE=$(get_iface)
    nmcli device disconnect "$IFACE" 2>/dev/null
  else
    main_menu
  fi
}
main_menu() {
  STATUS=$(wifi_status)
  if [ "$STATUS" = "enabled" ]; then
    TOGGLE=" $TOGGLE_OFF"
  else
    TOGGLE=" $TOGGLE_ON"
  fi
  CONN=$(current_connection)
  if [ -n "$CONN" ]; then
    CURRENT_LABEL=" $CURRENT: $CONN"
  else
    CURRENT_LABEL=" $CURRENT: $NO_CONNECTION"
  fi
  CHOSEN=$(echo -e "$CURRENT_LABEL\n $SCAN\n $DISCONNECT\n$TOGGLE\n $EXIT" | rofi -dmenu -theme "$THEME" -p "  $PROMPT" -u 4)
  case "$CHOSEN" in
    " $SCAN") show_networks ;;
    " $DISCONNECT") confirm_disconnect ;;
    " $TOGGLE_OFF"|" $TOGGLE_ON")
      if [ "$STATUS" = "enabled" ]; then
        nmcli radio wifi off
      else
        nmcli radio wifi on
      fi
      main_menu
      ;;
    " $EXIT"|"") exit 0 ;;
    *) show_current ;;
  esac
}
main_menu
