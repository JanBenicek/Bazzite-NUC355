#!/usr/bin/env bash
set -euo pipefail

# System, media and development tools intentionally baked into the immutable
# image so Rider and terminal builds use the host toolchain directly.
PACKAGES=(
  intel-compute-runtime
  libva-utils
  igt-gpu-tools
  clinfo
  git
  git-lfs
  dotnet-sdk-10.0
  postgresql
  ffmpeg
  jq
  ripgrep
  fd-find
  rclone
  htop
  unzip
  curl
  ntfs-3g
  cifs-utils
  gnome-disk-utility
)

dnf5 -y install "${PACKAGES[@]}"

# Docker Engine: use Docker's official Fedora repository and include Compose v2
# and Buildx. The daemon is enabled in the image and the first-login script adds
# the desktop user to the docker group.
dnf5 -y config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
dnf5 -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker.service containerd.service

# Install /etc files normally. Bazzite's /usr/local is a symlink whose target
# may not exist inside the image build root yet, so resolve the link and create
# its target explicitly before copying our custom files into it.
if [[ -d /ctx/system_files/etc ]]; then
  cp -a /ctx/system_files/etc/. /etc/
fi
if [[ -d /ctx/system_files/usr/local ]]; then
  USR_LOCAL_TARGET="$(readlink -f /usr/local 2>/dev/null || true)"
  if [[ -z "$USR_LOCAL_TARGET" ]]; then
    USR_LOCAL_LINK="$(readlink /usr/local)"
    if [[ "$USR_LOCAL_LINK" = /* ]]; then
      USR_LOCAL_TARGET="$USR_LOCAL_LINK"
    else
      USR_LOCAL_TARGET="/usr/$USR_LOCAL_LINK"
    fi
  fi
  mkdir -p "$USR_LOCAL_TARGET"
  cp -a /ctx/system_files/usr/local/. "$USR_LOCAL_TARGET/"
fi

chmod 0755 /usr/local/bin/n355-media-check
chmod 0755 /usr/local/lib/bazzite-nuc355/first-boot.sh
chmod 0755 /usr/local/lib/bazzite-nuc355/install-resolve-studio.sh
chmod 0755 /usr/local/lib/bazzite-nuc355/set-hardware-hostname.sh
systemctl enable bazzite-nuc355-hostname.service

# Keep the final image clean.
dnf5 clean all
rm -rf /var/cache/dnf /var/log/dnf* /tmp/*
