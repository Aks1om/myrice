#!/usr/bin/env bash
# OCR выделенной области экрана (grim+slurp+tesseract)
# Использование: ocr.sh [copy|google]  — copy: текст в буфер, google: открыть поиск

mode="${1:-copy}"

text="$(grim -g "$(slurp)" - | tesseract stdin stdout -l rus+eng 2>/dev/null)"

if [ -z "${text//[[:space:]]/}" ]; then
    notify-send "OCR" "Текст не распознан" 2>/dev/null
    exit 1
fi

case "$mode" in
    google)
        q="$(printf '%s' "$text" | python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip()))')"
        xdg-open "https://www.google.com/search?q=${q}"
        ;;
    *)
        printf '%s' "$text" | wl-copy
        notify-send "OCR" "Скопировано: $(printf '%s' "$text" | head -c 120)" 2>/dev/null
        ;;
esac
