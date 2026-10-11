#!/usr/bin/env bash
set -uo pipefail

STATE="$HOME/.local/state/bazzite-nuc355"
COMPONENTS="$STATE/components"
LOG="$STATE/provision.log"
mkdir -p "$STATE" "$COMPONENTS" "$HOME/.local/bin" "$HOME/.local/share/applications" "$HOME/Applications"
exec > >(tee -a "$LOG") 2>&1

# Increment only the component whose provisioning logic or desired state changes.
FLATPAKS_VERSION=1
DOCKER_VERSION=1
RIDER_VERSION=1
ETCHER_VERSION=1
BOOTSTRAP_VERSION=1
TMOG_VERSION=1
RESOLVE_VERSION=1

retry() { local n=0; until "$@"; do n=$((n+1)); ((n>=3)) && return 1; echo "Retry $n: $*"; sleep 3; done; }
download_dir() { xdg-user-dir DOWNLOAD 2>/dev/null || printf '%s\n' "$HOME/Downloads"; }
open_url() { if command -v xdg-open >/dev/null; then xdg-open "$1" >/dev/null 2>&1 & else echo "Open: $1"; fi; }

component_current() {
  [[ -e "$COMPONENTS/$1.v$2.done" ]]
}

mark_component() {
  local name="$1" version="$2"
  rm -f "$COMPONENTS/$name".v*.done
  touch "$COMPONENTS/$name.v$version.done"
}

run_component() {
  local name="$1" version="$2" label="$3"
  shift 3
  if component_current "$name" "$version"; then
    return 0
  fi
  echo
  echo "=== $label (provisioning v$version) ==="
  if "$@"; then
    mark_component "$name" "$version"
    echo "[OK] $label v$version"
    CHANGED=1
    return 0
  fi
  echo "[FAILED] $label v$version"
  return 1
}

install_flatpaks() {
  flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
  local apps=(com.google.Chrome org.localsend.localsend_app com.jgraph.drawio.desktop org.jellyfin.JellyfinDesktop com.github.tchx84.Flatseal)
  retry flatpak install --user -y --noninteractive flathub "${apps[@]}" || return 1
  # Keep all user Flatpaks current whenever this component is reprovisioned.
  retry flatpak update --user -y --noninteractive
}

configure_docker() {
  command -v docker >/dev/null || { echo 'Docker is missing from the host image.'; return 1; }
  if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    echo 'Adding current user to the docker group (sudo authentication may be requested)...'
    sudo usermod -aG docker "$USER" || return 1
    echo 'Docker group membership will become active after the final reboot.'
  fi
  sudo systemctl enable --now docker.service || return 1
  docker --version || return 1
  docker compose version || return 1
}

install_rider() {
  local toolbox="$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox"
  if [[ -x "$toolbox" ]]; then
    "$toolbox" >/dev/null 2>&1 &
    echo 'JetBrains Toolbox is present; Toolbox manages Rider updates.'
    return 0
  fi
  local tmp archive bin
  tmp="$(mktemp -d)"; archive="$tmp/toolbox.tar.gz"
  curl -fL --retry 3 'https://download.jetbrains.com/toolbox/jetbrains-toolbox.tar.gz' -o "$archive" || { rm -rf "$tmp"; return 1; }
  tar -xzf "$archive" -C "$tmp" || { rm -rf "$tmp"; return 1; }
  bin="$(find "$tmp" -type f -name jetbrains-toolbox -perm -u+x -print -quit)"
  [[ -n "$bin" ]] || { rm -rf "$tmp"; return 1; }
  mkdir -p "$(dirname "$toolbox")"
  cp "$bin" "$toolbox" || { rm -rf "$tmp"; return 1; }
  chmod +x "$toolbox"
  "$toolbox" >/dev/null 2>&1 &
  rm -rf "$tmp"
  echo 'JetBrains Toolbox installed and launched. Install/manage Rider there.'
}

install_balena_etcher() {
  local api url tmp rpm
  tmp="$(mktemp -d)"; rpm="$tmp/balena-etcher.rpm"
  api='https://api.github.com/repos/balena-io/etcher/releases/latest'
  url="$(curl -fsSL --retry 3 "$api" | grep -oE 'https://[^\"]+balena-etcher-[^\"]+\.x86_64\.rpm' | head -n1)"
  [[ -n "$url" ]] || { echo 'Could not determine the latest balenaEtcher x86_64 RPM.'; rm -rf "$tmp"; return 1; }
  echo "Installing/updating balenaEtcher from $url"
  curl -fL --retry 3 "$url" -o "$rpm" || { rm -rf "$tmp"; return 1; }
  sudo dnf5 -y install "$rpm" || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}

install_bootstrap_studio() {
  [[ -x "$HOME/Applications/BootstrapStudio.AppImage" ]] && return 0
  local dl file answer
  dl="$(download_dir)"
  echo 'The Bootstrap Studio download page will now open.'
  echo 'Download the Linux AppImage named: Bootstrap Studio.appimage'
  open_url 'https://bootstrapstudio.io/download/'
  while true; do
    read -r -p 'When the Bootstrap Studio download is complete, press Enter: ' _
    file="$dl/Bootstrap Studio.appimage"
    [[ -f "$file" ]] && break
    echo "Bootstrap Studio.appimage was not found in $dl"
    read -r -p 'Press Enter to search again, or type q to stop provisioning for now: ' answer
    [[ "${answer,,}" == q ]] && return 1
  done
  mv -- "$file" "$HOME/Applications/BootstrapStudio.AppImage" || return 1
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
  [[ -x "$HOME/Applications/TMOG.AppImage" ]] && return 0
  local dl file answer
  dl="$(download_dir)"
  echo 'The TMOG website will now open.'
  echo 'Download: downloads_TaskManagerOG-1.0.0-x86_64.appimage'
  open_url 'https://tmog.org/'
  while true; do
    read -r -p 'When the TMOG download is complete, press Enter: ' _
    file="$dl/downloads_TaskManagerOG-1.0.0-x86_64.appimage"
    [[ -f "$file" ]] && break
    echo "downloads_TaskManagerOG-1.0.0-x86_64.appimage was not found in $dl"
    read -r -p 'Press Enter to search again, or type q to stop provisioning for now: ' answer
    [[ "${answer,,}" == q ]] && return 1
  done
  mv -- "$file" "$HOME/Applications/TMOG.AppImage" || return 1
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

install_resolve() {
  # Resolve is intentionally not auto-reinstalled on every OS update. Bump
  # RESOLVE_VERSION when the desired Resolve installation procedure changes.
  /usr/libexec/bazzite-nuc355/install-resolve-studio.sh
}

CHANGED=0
FAILED=()
run_component flatpaks "$FLATPAKS_VERSION" 'Desktop Flatpaks' install_flatpaks || FAILED+=(flatpaks)
run_component docker "$DOCKER_VERSION" 'Docker configuration' configure_docker || FAILED+=(docker)
run_component rider "$RIDER_VERSION" 'JetBrains Toolbox / Rider setup' install_rider || FAILED+=(rider)
run_component balena-etcher "$ETCHER_VERSION" 'balenaEtcher' install_balena_etcher || FAILED+=(balena-etcher)
run_component bootstrap-studio "$BOOTSTRAP_VERSION" 'Bootstrap Studio' install_bootstrap_studio || FAILED+=(bootstrap-studio)
run_component tmog "$TMOG_VERSION" 'TMOG' install_tmog || FAILED+=(tmog)
run_component resolve-studio "$RESOLVE_VERSION" 'DaVinci Resolve Studio' install_resolve || FAILED+=(resolve-studio)

if ((${#FAILED[@]})); then
  echo
  echo 'Provisioning/update is incomplete.'
  echo "Failed or deferred components: ${FAILED[*]}"
  echo 'Completed component versions will be skipped on the next login.'
  echo "Full log: $LOG"
  exit 1
fi

if ((CHANGED == 0)); then
  # Normal login after an update with no new provisioning work: exit silently.
  exit 0
fi

echo
echo 'All requested provisioning/update components completed successfully.'
echo 'The system will reboot automatically in 10 seconds to activate all changes.'
echo 'Press Ctrl+C now only if you need to postpone the reboot.'
sleep 10
systemctl reboot || sudo systemctl reboot
