#!/usr/bin/env bash
set -uo pipefail

STATE="$HOME/.local/state/bazzite-nuc355"
COMPONENTS="$STATE/components"
LOG="$STATE/provision.log"
mkdir -p "$STATE" "$COMPONENTS" "$HOME/.local/bin" "$HOME/.local/share/applications" "$HOME/Applications"
exec > >(tee -a "$LOG") 2>&1

# Increment only the component whose provisioning logic or desired state changes.
FLATPAKS_VERSION=2
DOCKER_VERSION=1
RIDER_VERSION=1
ETCHER_VERSION=2
BOOTSTRAP_VERSION=2
TMOG_VERSION=1
RESOLVE_VERSION=1

retry() { local n=0; until "$@"; do n=$((n+1)); ((n>=3)) && return 1; echo "Retry $n: $*"; sleep 3; done; }
download_dir() { xdg-user-dir DOWNLOAD 2>/dev/null || printf '%s\n' "$HOME/Downloads"; }
open_url() { if command -v xdg-open >/dev/null; then xdg-open "$1" >/dev/null 2>&1 & else echo "Open: $1"; fi; }

component_current() { [[ -e "$COMPONENTS/$1.v$2.done" ]]; }
mark_component() { local name="$1" version="$2"; rm -f "$COMPONENTS/$name".v*.done; touch "$COMPONENTS/$name.v$version.done"; }
run_component() {
  local name="$1" version="$2" label="$3"; shift 3
  component_current "$name" "$version" && return 0
  echo; echo "=== $label (provisioning v$version) ==="
  if "$@"; then mark_component "$name" "$version"; echo "[OK] $label v$version"; CHANGED=1; return 0; fi
  echo "[FAILED] $label v$version"; return 1
}

install_flatpaks() {
  local apps=(
    com.google.Chrome
    org.localsend.localsend_app
    com.jgraph.drawio.desktop
    org.jellyfin.JellyfinDesktop
    com.github.tchx84.Flatseal
    com.moonlight_stream.Moonlight
    org.tigervnc.vncviewer
  )
  command -v flatpak >/dev/null || { echo 'Flatpak is missing from the host image.'; return 1; }
  echo 'Configuring Flathub and installing workstation applications system-wide...'
  retry sudo flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || return 1
  retry sudo flatpak install --system -y --noninteractive flathub "${apps[@]}" || return 1
  echo 'Workstation Flatpaks installed.'
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
  if [[ -x "$toolbox" ]]; then "$toolbox" >/dev/null 2>&1 & echo 'JetBrains Toolbox is present; Toolbox manages Rider updates.'; return 0; fi
  local tmp archive bin
  tmp="$(mktemp -d)"; archive="$tmp/toolbox.tar.gz"
  curl -fL --retry 3 'https://download.jetbrains.com/toolbox/jetbrains-toolbox.tar.gz' -o "$archive" || { rm -rf "$tmp"; return 1; }
  tar -xzf "$archive" -C "$tmp" || { rm -rf "$tmp"; return 1; }
  bin="$(find "$tmp" -type f -name jetbrains-toolbox -perm -u+x -print -quit)"
  [[ -n "$bin" ]] || { rm -rf "$tmp"; return 1; }
  mkdir -p "$(dirname "$toolbox")"; cp "$bin" "$toolbox" || { rm -rf "$tmp"; return 1; }; chmod +x "$toolbox"
  "$toolbox" >/dev/null 2>&1 &
  rm -rf "$tmp"; echo 'JetBrains Toolbox installed and launched. Install/manage Rider there.'
}

verify_balena_etcher() {
  if command -v balena-etcher >/dev/null 2>&1 || command -v balenaEtcher >/dev/null 2>&1 || rpm -q balena-etcher >/dev/null 2>&1; then
    echo 'balenaEtcher is present in the immutable host image.'
    return 0
  fi
  echo 'balenaEtcher is missing from the immutable host image.'
  return 1
}

install_bootstrap_studio() {
  [[ -x "$HOME/Applications/BootstrapStudio.AppImage" ]] && return 0
  local dl file answer
  dl="$(download_dir)"
  echo 'The Bootstrap Studio download page will now open.'
  echo 'Download the Linux AppImage; the filename is detected case-insensitively.'
  open_url 'https://bootstrapstudio.io/download/'
  while true; do
    read -r -p 'When the Bootstrap Studio download is complete, press Enter: ' _
    file="$(find "$dl" -maxdepth 1 -type f -iname 'Bootstrap Studio*.AppImage' -print -quit 2>/dev/null)"
    [[ -n "$file" ]] && break
    echo "Bootstrap Studio AppImage was not found in $dl"
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
  local dl file answer; dl="$(download_dir)"
  echo 'The TMOG website will now open.'; echo 'Download: downloads_TaskManagerOG-1.0.0-x86_64.appimage'; open_url 'https://tmog.org/'
  while true; do
    read -r -p 'When the TMOG download is complete, press Enter: ' _
    file="$(find "$dl" -maxdepth 1 -type f -iname 'downloads_TaskManagerOG-*-x86_64.appimage' -print -quit 2>/dev/null)"
    [[ -n "$file" ]] && break
    echo "TMOG AppImage was not found in $dl"; read -r -p 'Press Enter to search again, or type q to stop provisioning for now: ' answer; [[ "${answer,,}" == q ]] && return 1
  done
  mv -- "$file" "$HOME/Applications/TMOG.AppImage" || return 1; chmod +x "$HOME/Applications/TMOG.AppImage"
  cat > "$HOME/.local/share/applications/tmog.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=TMOG
Exec=$HOME/Applications/TMOG.AppImage
Terminal=false
Categories=Utility;
EOF
}

install_resolve() { /usr/libexec/bazzite-nuc355/install-resolve-studio.sh; }

CHANGED=0
FAILED=()
run_component flatpaks "$FLATPAKS_VERSION" 'Workstation Flatpaks' install_flatpaks || FAILED+=(flatpaks)
run_component docker "$DOCKER_VERSION" 'Docker configuration' configure_docker || FAILED+=(docker)
run_component rider "$RIDER_VERSION" 'JetBrains Toolbox / Rider setup' install_rider || FAILED+=(rider)
run_component balena-etcher "$ETCHER_VERSION" 'balenaEtcher' verify_balena_etcher || FAILED+=(balena-etcher)
run_component bootstrap-studio "$BOOTSTRAP_VERSION" 'Bootstrap Studio' install_bootstrap_studio || FAILED+=(bootstrap-studio)
run_component tmog "$TMOG_VERSION" 'TMOG' install_tmog || FAILED+=(tmog)
run_component resolve-studio "$RESOLVE_VERSION" 'DaVinci Resolve Studio' install_resolve || FAILED+=(resolve-studio)

if ((${#FAILED[@]})); then
  echo; echo 'Provisioning/update is incomplete.'; echo "Failed or deferred components: ${FAILED[*]}"; echo 'Completed component versions will be skipped on the next login.'; echo "Full log: $LOG"; exit 1
fi
if ((CHANGED == 0)); then exit 0; fi

echo; echo 'All requested provisioning/update components completed successfully.'; echo 'The system will reboot automatically in 10 seconds to activate all changes.'; echo 'Press Ctrl+C now only if you need to postpone the reboot.'; sleep 10
systemctl reboot || sudo systemctl reboot
