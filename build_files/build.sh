#!/usr/bin/env bash
set -euo pipefail

# Keep the host image deliberately small. GUI apps and development SDKs belong
# in Flatpak/AppImage/Distrobox unless they genuinely need host integration.
PACKAGES=(
  intel-compute-runtime
  libva-utils
  igt-gpu-tools
  clinfo
  git-lfs
  rclone
  unzip
  curl
)

dnf5 -y install "${PACKAGES[@]}"

# Copy files that should be part of the immutable OS image.
cp -a /ctx/system_files/. /
chmod 0755 /usr/local/bin/n355-media-check
chmod 0755 /usr/local/lib/bazzite-nuc355/first-boot.sh
chmod 0755 /usr/local/lib/bazzite-nuc355/install-resolve-studio.sh

# Keep the final image clean.
dnf5 clean all
rm -rf /var/cache/dnf /var/log/dnf* /tmp/*
