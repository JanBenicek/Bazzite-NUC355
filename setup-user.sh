#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v flatpak >/dev/null 2>&1; then
  echo 'flatpak is missing; this script expects Bazzite.' >&2
  exit 1
fi

if ! flatpak remotes --columns=name | grep -qx flathub; then
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

mapfile -t FLATPAKS < <(grep -Ev '^[[:space:]]*(#|$)' "$ROOT_DIR/config/flatpaks.txt")
if ((${#FLATPAKS[@]})); then
  flatpak install -y flathub "${FLATPAKS[@]}"
fi

if command -v distrobox >/dev/null 2>&1; then
  if ! distrobox list --no-color 2>/dev/null | awk '{print $2}' | grep -qx dev; then
    distrobox create --yes --name dev --image registry.fedoraproject.org/fedora:latest
  fi
  echo
  echo 'Development box created as "dev".'
  echo 'Enter it with: distrobox enter dev'
  echo 'Then install packages from config/dev-distrobox-packages.txt.'
fi

echo
echo 'For DaVinci Resolve on Bazzite, use: ujust install-resolve'
echo 'After installation, run n355-media-check to inspect VA-API/OpenCL.'
