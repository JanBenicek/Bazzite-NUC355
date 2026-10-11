#!/usr/bin/env bash
set -uo pipefail
STATE="$HOME/.local/state/bazzite-nuc355"
DONE="$STATE/provisioned"
mkdir -p "$STATE" "$HOME/.local/bin" "$HOME/.local/share/applications" "$HOME/Applications"
[[ -e "$DONE" ]] && exit 0
exec > >(tee -a "$STATE/provision.log") 2>&1

retry() { local n=0; until "$@"; do n=$((n+1)); ((n>=3)) && return 1; echo "Retry $n: $*"; sleep 3; done; }

install_flatpaks() {
  flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
  local apps=(com.google.Chrome org.localsend.localsend_app com.jgraph.drawio.desktop org.jellyfin.JellyfinDesktop com.github.tchx84.Flatseal)
  retry flatpak install --user -y --noninteractive flathub "${apps[@]}"
}

install_devbox() {
  command -v distrobox >/dev/null || return 0
  distrobox list --no-color 2>/dev/null | grep -qE '(^|[[:space:]])dev([[:space:]]|$)' || distrobox create --yes --name dev --image registry.fedoraproject.org/fedora:latest
  distrobox enter dev -- bash -lc 'sudo dnf -y install git git-lfs dotnet-sdk-10.0 nodejs npm podman-compose postgresql ffmpeg jq ripgrep fd-find'
}

install_rider() {
  # JetBrains documents Toolbox as the recommended installer for Rider. Install
  # Toolbox through its official Linux tarball endpoint, then launch it. Toolbox
  # handles the current Rider version and future IDE updates.
  if command -v jetbrains-toolbox >/dev/null || [[ -x "$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox" ]]; then return 0; fi
  local tmp archive dir bin
  tmp="$(mktemp -d)"
  archive="$tmp/toolbox.tar.gz"
  if ! curl -fL --retry 3 'https://download.jetbrains.com/toolbox/jetbrains-toolbox.tar.gz' -o "$archive"; then rm -rf "$tmp"; return 1; fi
  tar -xzf "$archive" -C "$tmp"
  bin="$(find "$tmp" -type f -name jetbrains-toolbox -perm -u+x -print -quit)"
  [[ -n "$bin" ]] || { rm -rf "$tmp"; return 1; }
  mkdir -p "$HOME/.local/share/JetBrains/Toolbox/bin"
  cp "$bin" "$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox"
  chmod +x "$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox"
  "$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox" >/dev/null 2>&1 &
  rm -rf "$tmp"
  echo 'JetBrains Toolbox installed and launched. Rider is managed by Toolbox.'
}

install_bootstrap_studio() {
  # Bootstrap Studio is proprietary and its official download is account/license
  # gated. We cannot embed a licensed installer. If an AppImage has already been
  # downloaded, integrate it automatically.
  local dl file
  dl="$(xdg-user-dir DOWNLOAD 2>/dev/null || printf '%s' "$HOME/Downloads")"
  file="$(find "$dl" -maxdepth 1 -type f \( -iname 'Bootstrap*Studio*.AppImage' -o -iname 'bootstrap-studio*.AppImage' \) -print -quit 2>/dev/null || true)"
  [[ -n "$file" ]] || { echo 'Bootstrap Studio installer not found; leaving for licensed user download.'; return 0; }
  cp "$file" "$HOME/Applications/BootstrapStudio.AppImage"
  chmod +x "$HOME/Applications/BootstrapStudio.AppImage"
  cat > "$HOME/.local/share/applications/bootstrap-studio.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Bootstrap Studio
Exec=$HOME/Applications/BootstrapStudio.AppImage
Terminal=false
Categories=Development;WebDevelopment;
EOF
}

install_tmog() {
  # TMOG is supplied as AppImage. Integrate a downloaded copy automatically.
  local dl file
  dl="$(xdg-user-dir DOWNLOAD 2>/dev/null || printf '%s' "$HOME/Downloads")"
  file="$(find "$dl" -maxdepth 1 -type f -iname '*TMOG*.AppImage' -print -quit 2>/dev/null || true)"
  [[ -n "$file" ]] || { echo 'TMOG AppImage not found in Downloads; skipping.'; return 0; }
  cp "$file" "$HOME/Applications/TMOG.AppImage"
  chmod +x "$HOME/Applications/TMOG.AppImage"
  cat > "$HOME/.local/share/applications/tmog.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=TMOG
Exec=$HOME/Applications/TMOG.AppImage
Terminal=false
Categories=Utility;
EOF
}

install_flatpaks || echo 'WARNING: some Flatpaks failed.'
install_devbox || echo 'WARNING: dev Distrobox provisioning failed.'
install_rider || echo 'WARNING: JetBrains Toolbox installation failed.'
install_bootstrap_studio || true
install_tmog || true

# Resolve Studio deliberately remains interactive because Blackmagic requires the
# user to obtain the Studio Linux package from its download page.
/usr/local/lib/bazzite-nuc355/install-resolve-studio.sh || echo 'WARNING: Resolve Studio was not installed.'

touch "$DONE"
echo 'Bazzite NUC355 first-login provisioning finished.'
