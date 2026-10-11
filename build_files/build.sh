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
  nodejs
  npm
  postgresql
  ffmpeg
  jq
  ripgrep
  fd-find
  rclone
  unzip
  curl
)

dnf5 -y install "${PACKAGES[@]}"

# Docker Engine: use Docker's official Fedora repository and include Compose v2
# and Buildx. The daemon is enabled in the image and the first-login script adds
# the desktop user to the docker group.
dnf5 -y config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
dnf5 -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker.service containerd.service

# Copy files that should be part of the immutable OS image.
cp -a /ctx/system_files/. /
chmod 0755 /usr/local/bin/n355-media-check
chmod 0755 /usr/local/lib/bazzite-nuc355/first-boot.sh
chmod 0755 /usr/local/lib/bazzite-nuc355/install-resolve-studio.sh

# Keep the final image clean.
dnf5 clean all
rm -rf /var/cache/dnf /var/log/dnf* /tmp/*
