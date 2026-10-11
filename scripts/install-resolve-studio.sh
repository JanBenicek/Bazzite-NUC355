#!/usr/bin/env bash
set -euo pipefail

DOWNLOAD_URL="https://www.blackmagicdesign.com/products/davinciresolve"
DOWNLOAD_DIR="${XDG_DOWNLOAD_DIR:-$HOME/Downloads}"

# Prefer the localized XDG Downloads directory when configured.
if command -v xdg-user-dir >/dev/null 2>&1; then
  xdg_download="$(xdg-user-dir DOWNLOAD 2>/dev/null || true)"
  [[ -n "$xdg_download" ]] && DOWNLOAD_DIR="$xdg_download"
fi

printf '\nDaVinci Resolve Studio installation\n'
printf '----------------------------------\n'
printf 'The Blackmagic Design download page will now open.\n'
printf 'Download the Linux version of DaVinci Resolve Studio.\n'
printf 'Expected filename: DaVinci_Resolve_Studio_[version]_Linux.zip\n\n'

if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$DOWNLOAD_URL" >/dev/null 2>&1 &
elif command -v gio >/dev/null 2>&1; then
  gio open "$DOWNLOAD_URL" >/dev/null 2>&1 &
else
  printf 'Open this page in your browser:\n%s\n' "$DOWNLOAD_URL"
fi

while true; do
  read -r -p "After the download has completed, press Enter to continue... " _

  shopt -s nullglob
  candidates=("$DOWNLOAD_DIR"/DaVinci_Resolve_Studio_*_Linux.zip)
  shopt -u nullglob

  if ((${#candidates[@]} == 0)); then
    printf '\nNo matching Studio ZIP was found in:\n  %s\n' "$DOWNLOAD_DIR"
    printf 'The filename must match DaVinci_Resolve_Studio_[version]_Linux.zip\n\n'
    read -r -p "Press Enter to search again, or type q to skip Resolve Studio: " answer
    [[ "${answer,,}" == "q" ]] && exit 0
    continue
  fi

  # If several versions exist, use the newest file by modification time.
  ZIP_FILE="$(ls -1t "${candidates[@]}" | head -n1)"
  break
done

printf '\nFound installer:\n  %s\n' "$ZIP_FILE"

WORK_DIR="$(mktemp -d -t davinci-resolve-studio.XXXXXX)"
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

printf 'Extracting installer...\n'
unzip -q "$ZIP_FILE" -d "$WORK_DIR"

RUN_FILE="$(find "$WORK_DIR" -maxdepth 2 -type f -name 'DaVinci_Resolve_Studio_*_Linux.run' -print -quit)"
if [[ -z "$RUN_FILE" ]]; then
  echo 'The ZIP does not contain the expected DaVinci Resolve Studio Linux .run installer.' >&2
  exit 1
fi
chmod +x "$RUN_FILE"

printf 'Installing DaVinci Resolve Studio through Bazzite/davincibox...\n'

# Bazzite's helper is preferred. Passing the installer path allows davincibox
# to install the user-provided Studio package without redistributing it.
if command -v ujust >/dev/null 2>&1; then
  if ujust --choose 2>/dev/null | grep -q '^install-resolve'; then
    ujust install-resolve "$RUN_FILE"
  elif command -v davincibox >/dev/null 2>&1; then
    davincibox setup "$RUN_FILE"
  else
    echo 'Neither the Bazzite Resolve helper nor davincibox is available.' >&2
    exit 1
  fi
elif command -v davincibox >/dev/null 2>&1; then
  davincibox setup "$RUN_FILE"
else
  echo 'davincibox/Bazzite Resolve installer is not available.' >&2
  exit 1
fi

printf '\nDaVinci Resolve Studio installation finished successfully.\n'
printf 'Deleting downloaded installer ZIP:\n  %s\n' "$ZIP_FILE"
rm -f -- "$ZIP_FILE"

printf 'Installer ZIP deleted. Temporary extracted files will also be removed.\n'
