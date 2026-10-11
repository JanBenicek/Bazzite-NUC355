#!/usr/bin/env bash
set -euo pipefail

URL='https://www.blackmagicdesign.com/products/davinciresolve'
DOWNLOAD_DIR="${XDG_DOWNLOAD_DIR:-$HOME/Downloads}"
command -v xdg-user-dir >/dev/null && DOWNLOAD_DIR="$(xdg-user-dir DOWNLOAD 2>/dev/null || printf '%s' "$DOWNLOAD_DIR")"

echo 'Opening Blackmagic Design. Download DaVinci Resolve Studio for Linux.'
xdg-open "$URL" >/dev/null 2>&1 &

while true; do
  read -r -p 'When the Studio Linux ZIP download is complete, press Enter: ' _
  ZIP="$(find "$DOWNLOAD_DIR" -maxdepth 1 -type f -iname 'DaVinci_Resolve_Studio_*_Linux.zip' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2-)"
  [[ -n "$ZIP" ]] && break
  echo "No DaVinci Resolve Studio Linux ZIP found in $DOWNLOAD_DIR"
done

echo "Found: $ZIP"
TMP="$(mktemp -d -t resolve-studio.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

echo 'Extracting DaVinci Resolve Studio...'
unzip -q "$ZIP" -d "$TMP"
RUN="$(find "$TMP" -type f -iname 'DaVinci_Resolve_Studio_*_Linux.run' -print -quit)"
[[ -n "$RUN" ]] || { echo 'Studio .run installer not found in ZIP.' >&2; exit 1; }
chmod +x "$RUN"

echo "Installing $(basename "$RUN") automatically through the Bazzite Resolve helper..."
if command -v ujust >/dev/null 2>&1; then
  ujust install-resolve "$RUN"
elif command -v davincibox >/dev/null 2>&1; then
  davincibox setup "$RUN"
else
  echo 'Bazzite Resolve/davincibox helper is unavailable.' >&2
  exit 1
fi

echo 'DaVinci Resolve Studio installation completed successfully.'
rm -f -- "$ZIP"
echo 'Downloaded Studio ZIP deleted.'
