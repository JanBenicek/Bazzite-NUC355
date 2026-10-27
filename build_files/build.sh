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
  ffmpeg
  vlc
  aegisub
  picard
  jq
  ripgrep
  fd-find
  rclone
  htop
  nano
  unzip
  curl
  ntfs-3g
  cifs-utils
  wireguard-tools
  gnome-disk-utility
)

dnf5 -y install "${PACKAGES[@]}"

# Docker Engine: use Docker's official Fedora repository and include Compose v2
# and Buildx. The daemon is enabled in the image and the provisioning script adds
# the desktop user to the docker group.
dnf5 -y config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
dnf5 -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker.service containerd.service

# balenaEtcher must be installed while the immutable image is being built.
# Installing an RPM later on a booted bootc system would only be transient.
ETCHER_API='https://api.github.com/repos/balena-io/etcher/releases/latest'
ETCHER_URL="$(curl -fsSL --retry 3 "$ETCHER_API" | grep -oE 'https://[^\"]+balena-etcher-[^\"]+\.x86_64\.rpm' | head -n1)"
[[ -n "$ETCHER_URL" ]] || { echo 'Could not determine latest balenaEtcher x86_64 RPM.' >&2; exit 1; }
dnf5 -y install "$ETCHER_URL"

# Flatpak applications are intentionally installed on the first graphical login.
# Running flatpak install during an OCI/bootc build requires bubblewrap user
# namespaces which are not available in the GitHub Actions Podman build sandbox.
# first-boot.sh installs them system-wide on the real Bazzite host instead.

# /usr/local is persistent mutable state on Bazzite/OSTree and therefore must
# not contain files that belong to the immutable image. Install our helpers in
# /usr/libexec and the user-facing command in /usr/bin instead.
if [[ -d /ctx/system_files/etc ]]; then
  cp -a /ctx/system_files/etc/. /etc/
fi
mkdir -p /usr/libexec/bazzite-nuc355
cp -a /ctx/system_files/usr/local/lib/bazzite-nuc355/. /usr/libexec/bazzite-nuc355/
install -Dm0755 /ctx/system_files/usr/local/bin/n355-media-check /usr/bin/n355-media-check

chmod 0755 /usr/libexec/bazzite-nuc355/first-boot.sh
chmod 0755 /usr/libexec/bazzite-nuc355/install-resolve-studio.sh
chmod 0755 /usr/libexec/bazzite-nuc355/set-hardware-hostname.sh
systemctl enable bazzite-nuc355-hostname.service

# Keep the final image clean.
dnf5 clean all
rm -rf /var/cache/dnf /var/log/dnf* /tmp/*
