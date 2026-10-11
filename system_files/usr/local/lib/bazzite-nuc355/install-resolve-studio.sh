#!/usr/bin/env bash
set -euo pipefail
URL='https://www.blackmagicdesign.com/products/davinciresolve'
DOWNLOAD_DIR="${XDG_DOWNLOAD_DIR:-$HOME/Downloads}"
command -v xdg-user-dir >/dev/null && DOWNLOAD_DIR="$(xdg-user-dir DOWNLOAD 2>/dev/null || printf '%s' "$DOWNLOAD_DIR")"
echo 'Opening Blackmagic Design. Download DaVinci Resolve Studio for Linux.'
xdg-open "$URL" >/dev/null 2>&1 &
while true; do
  read -r -p 'When the Studio Linux ZIP download is complete, press Enter: ' _
  shopt -s nullglob
  files=("$DOWNLOAD_DIR"/DaVinci_Resolve_Studio_*_Linux.zip)
  shopt -u nullglob
  ((${#files[@]})) && break
  echo "No DaVinci_Resolve_Studio_*_Linux.zip found in $DOWNLOAD_DIR"
done
ZIP="$(ls -1t "${files[@]}" | head -n1)"
TMP="$(mktemp -d -t resolve-studio.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
unzip -q "$ZIP" -d "$TMP"
RUN="$(find "$TMP" -type f -name 'DaVinci_Resolve_Studio_*_Linux.run' -print -quit)"
[[ -n "$RUN" ]] || { echo 'Studio .run installer not found in ZIP.' >&2; exit 1; }
chmod +x "$RUN"
echo "Installing $(basename "$RUN")..."
if command -v ujust >/dev/null 2>&1; then
  ujust install-resolve "$RUN"
elif command -v davincibox >/dev/null 2>&1; then
  davincibox setup "$RUN"
else
  echo 'Bazzite Resolve/davincibox helper is unavailable.' >&2
  exit 1
fi
rm -f -- "$ZIP"
echo 'DaVinci Resolve Studio installed; downloaded ZIP deleted.'
