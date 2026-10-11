#!/usr/bin/env bash
set -uo pipefail
STATE="$HOME/.local/state/bazzite-nuc355"
DONE="$STATE/provisioned"
mkdir -p "$STATE" "$HOME/.local/bin" "$HOME/.local/share/applications" "$HOME/Applications"
[[ -e "$DONE" ]] && exit 0
exec > >(tee -a "$STATE/provision.log") 2>&1

retry() { local n=0; until "$@"; do n=$((n+1)); ((n>=3)) && return 1; echo "Retry $n: $*"; sleep 3; done; }
download_dir() { xdg-user-dir DOWNLOAD 2>/dev/null || printf '%s\n' "$HOME/Downloads"; }
open_url() { if command -v xdg-open >/dev/null; then xdg-open "$1" >/dev/null 2>&1 & else echo "Open: $1"; fi; }

install_flatpaks() {
  flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
  local apps=(com.google.Chrome org.localsend.localsend_app com.jgraph.drawio.desktop org.jellyfin.JellyfinDesktop com.github.tchx84.Flatseal)
  retry flatpak install --user -y --noninteractive flathub "${apps[@]}"
}

configure_docker() {
  command -v docker >/dev/null || { echo 'WARNING: Docker is missing from the host image.'; return 1; }
  if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    echo 'Adding current user to the docker group (sudo authentication may be requested)...'
    sudo usermod -aG docker "$USER" || return 1
    echo 'Docker group membership will be active after the next login/reboot.'
  fi
  sudo systemctl enable --now docker.service || return 1
  docker --version || true
  docker compose version || true
}

install_rider() {
  if command -v jetbrains-toolbox >/dev/null || [[ -x "$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox" ]]; then return 0; fi
  local tmp archive bin
  tmp="$(mktemp -d)"; archive="$tmp/toolbox.tar.gz"
  if ! curl -fL --retry 3 'https://download.jetbrains.com/toolbox/jetbrains-toolbox.tar.gz' -o "$archive"; then rm -rf "$tmp"; return 1; fi
  tar -xzf "$archive" -C "$tmp"
  bin="$(find "$tmp" -type f -name jetbrains-toolbox -perm -u+x -print -quit)"
  [[ -n "$bin" ]] || { rm -rf "$tmp"; return 1; }
  mkdir -p "$HOME/.local/share/JetBrains/Toolbox/bin"
  cp "$bin" "$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox"
  chmod +x "$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox"
  "$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox" >/dev/null 2>&1 &
  rm -rf "$tmp"
  echo 'JetBrains Toolbox installed and launched. Install/manage Rider there.'
}

install_bootstrap_studio() {
  local dl file answer
  dl="$(download_dir)"
  echo; echo 'Bootstrap Studio installation'; echo '-----------------------------'
  echo 'The Bootstrap Studio download page will now open.'
  echo 'Download the Linux AppImage named: Bootstrap Studio.appimage'
  open_url 'https://bootstrapstudio.io/download/'
  while true; do
    read -r -p 'When the Bootstrap Studio download is complete, press Enter: ' _
    file="$dl/Bootstrap Studio.appimage"
    [[ -f "$file" ]] && break
    echo "Bootstrap Studio.appimage was not found in $dl"
    read -r -p 'Press Enter to search again, or type q to skip: ' answer
    [[ "${answer,,}" == q ]] && return 0
  done
  mv -- "$file" "$HOME/Applications/BootstrapStudio.AppImage"
  chmod +x "$HOME/Applications/BootstrapStudio.AppImage"
  cat > "$HOME/.local/share/applications/bootstrap-studio.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Bootstrap Studio
Exec=$HOME/Applications/BootstrapStudio.AppImage
Terminal=false
Categories=Development;WebDevelopment;
EOF
  echo 'Bootstrap Studio installed; downloaded AppImage moved to ~/Applications.'
}

install_tmog() {
  local dl file answer
  dl="$(download_dir)"
  echo; echo 'TMOG installation'; echo '-----------------'
  echo 'The TMOG website will now open.'
  echo 'Download: downloads_TaskManagerOG-1.0.0-x86_64.appimage'
  open_url 'https://tmog.org/'
  while true; do
    read -r -p 'When the TMOG download is complete, press Enter: ' _
    file="$dl/downloads_TaskManagerOG-1.0.0-x86_64.appimage"
    [[ -f "$file" ]] && break
    echo "downloads_TaskManagerOG-1.0.0-x86_64.appimage was not found in $dl"
    read -r -p 'Press Enter to search again, or type q to skip: ' answer
    [[ "${answer,,}" == q ]] && return 0
  done
  mv -- "$file" "$HOME/Applications/TMOG.AppImage"
  chmod +x "$HOME/Applications/TMOG.AppImage"
  cat > "$HOME/.local/share/applications/tmog.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=TMOG
Exec=$HOME/Applications/TMOG.AppImage
Terminal=false
Categories=Utility;
EOF
  echo 'TMOG installed; downloaded AppImage moved to ~/Applications.'
}

install_flatpaks || echo 'WARNING: some Flatpaks failed.'
configure_docker || echo 'WARNING: Docker configuration failed.'
install_rider || echo 'WARNING: JetBrains Toolbox installation failed.'
install_bootstrap_studio || echo 'WARNING: Bootstrap Studio was not installed.'
install_tmog || echo 'WARNING: TMOG was not installed.'
/usr/local/lib/bazzite-nuc355/install-resolve-studio.sh || echo 'WARNING: Resolve Studio was not installed.'

echo; echo 'Host development environment:'
dotnet --info || true
git --version || true
node --version || true
npm --version || true
docker --version || true

touch "$DONE"
echo 'Bazzite NUC355 first-login provisioning finished.'
