#!/bin/bash
# Папки с обоями
STATIC_DIR="$HOME/Wallpaper"
LIVE_DIR="$HOME/Wallpaper/live"
PREVIEW_DIR="$HOME/.cache/wallpaper-previews"  # кеш между сессиями
# Настройки rofi
THEME="$HOME/.config/rofi/wallpaper.rasi"
ROFI_OPTS=(-dmenu -show-icons -theme "$THEME")
# Настройки генерации превью
MAX_JOBS=4  # максимум параллельных задач
mkdir -p "$PREVIEW_DIR"
# Язык
LANG_SYS=$(echo $LANG | cut -c1-2)
if [ "$LANG_SYS" = "ru" ]; then
  LIVE="Живые"
  STATIC="Статичные"
  EXIT="Выход"
  PROMPT="Обои"
  PROMPT_LIVE="Живые обои"
  PROMPT_STATIC="Статичные обои"
else
  LIVE="Live"
  STATIC="Static"
  EXIT="Exit"
  PROMPT="Wallpaper"
  PROMPT_LIVE="Live wallpaper"
  PROMPT_STATIC="Static wallpaper"
fi
show_live() {
  # Удаляем превью для которых нет оригинала
  find "$PREVIEW_DIR" -type f -name "*.jpg" | while read -r PREVIEW; do
    NAME=$(basename "$PREVIEW" .jpg)
    [ ! -f "$LIVE_DIR/$NAME" ] && rm "$PREVIEW"
  done

  # Параллельная генерация превью с ограничением
  JOBS=0
  find "$LIVE_DIR" -type f \( -name "*.mp4" -o -name "*.webm" -o -name "*.gif" \) | while read -r VIDEO; do
    NAME=$(basename "$VIDEO")
    PREVIEW="$PREVIEW_DIR/$NAME.jpg"
    # Генерируем только если превью нет или видео новее превью
    if [ ! -f "$PREVIEW" ] || [ "$VIDEO" -nt "$PREVIEW" ]; then
      ffmpeg -i "$VIDEO" -vframes 1 -q:v 2 "$PREVIEW" -y 2>/dev/null &
      JOBS=$((JOBS + 1))
      [ "$JOBS" -ge "$MAX_JOBS" ] && wait && JOBS=0
    fi
  done
  wait

  CHOSEN=$(find "$PREVIEW_DIR" -type f -name "*.jpg" | while read -r PREVIEW; do
    NAME=$(basename "$PREVIEW" .jpg)
    echo -en "$NAME\0icon\x1f$PREVIEW\n"
  done | rofi "${ROFI_OPTS[@]}" -p " $PROMPT_LIVE")
  [ -z "$CHOSEN" ] && return 1
  xprop -root -remove _XROOTPMAP_ID 2>/dev/null
  xprop -root -remove ESETROOT_PMAP_ID 2>/dev/null
  pkill xwinwrap 2>/dev/null
  sleep 0.3
  xwinwrap -fs -fdt -ni -b -nf -ov -s -st -sp -- \
    mpv --wid="%WID" --loop --no-audio --no-osc --vo=x11 "$LIVE_DIR/$CHOSEN" &
  return 0
}
show_static() {
  CHOSEN=$(find "$STATIC_DIR" -maxdepth 1 -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" \) | while read -r IMG; do
    NAME=$(basename "$IMG")
    echo -en "$NAME\0icon\x1f$IMG\n"
  done | rofi "${ROFI_OPTS[@]}" -p " $PROMPT_STATIC")
  [ -z "$CHOSEN" ] && return 1
  xprop -root -remove _XROOTPMAP_ID 2>/dev/null
  xprop -root -remove ESETROOT_PMAP_ID 2>/dev/null
  pkill xwinwrap 2>/dev/null
  sleep 0.3
  feh --bg-max "$STATIC_DIR/$CHOSEN"
  return 0
}
main_menu() {
  TYPE=$(echo -e " $LIVE\n $STATIC\n $EXIT" | rofi -dmenu -theme "$THEME" -p "  $PROMPT" -u 2)
  case "$TYPE" in
    " $LIVE") show_live || main_menu ;;
    " $STATIC") show_static || main_menu ;;
    " $EXIT"|"") exit 0 ;;
  esac
}
main_menu
