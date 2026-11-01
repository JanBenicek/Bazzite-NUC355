#!/usr/bin/env bash
set -uo pipefail

STATE="$HOME/.local/state/bazzite-nuc355"
COMPONENTS="$STATE/components"
LOG="$STATE/provision.log"
mkdir -p "$STATE" "$COMPONENTS" "$HOME/.local/bin" "$HOME/.local/share/applications" "$HOME/Applications"
exec > >(tee -a "$LOG") 2>&1

FLATPAKS_VERSION=4
DOCKER_VERSION=1
RIDER_VERSION=2
ETCHER_VERSION=2
BOOTSTRAP_VERSION=2
TMOG_VERSION=2
SMB_MOUNTS_VERSION=1

retry() { local n=0; until "$@"; do n=$((n+1)); ((n>=3)) && return 1; echo "Retry $n: $*"; sleep 3; done; }
download_dir() { xdg-user-dir DOWNLOAD 2>/dev/null || printf '%s\n' "$HOME/Downloads"; }
open_url() { if command -v xdg-open >/dev/null; then xdg-open "$1" >/dev/null 2>&1 & else echo "Open: $1"; fi; }
component_current() { [[ -e "$COMPONENTS/$1.v$2.done" ]]; }
mark_component() { local name="$1" version="$2"; rm -f "$COMPONENTS/$name".v*.done; touch "$COMPONENTS/$name.v$version.done"; }
run_component() { local name="$1" version="$2" label="$3"; shift 3; component_current "$name" "$version" && return 0; echo; echo "=== $label (provisioning v$version) ==="; if "$@"; then mark_component "$name" "$version"; echo "[OK] $label v$version"; CHANGED=1; return 0; fi; echo "[FAILED] $label v$version"; return 1; }

install_flatpaks() {
  local apps=(com.google.Chrome com.discordapp.Discord org.prismlauncher.PrismLauncher org.localsend.localsend_app com.jgraph.drawio.desktop org.jellyfin.JellyfinDesktop com.github.tchx84.Flatseal com.moonlight_stream.Moonlight org.tigervnc.vncviewer)
  command -v flatpak >/dev/null || return 1
  retry sudo flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || return 1
  retry sudo flatpak install --system -y --noninteractive flathub "${apps[@]}" || return 1
}

configure_docker() {
  command -v docker >/dev/null || return 1
  if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then sudo usermod -aG docker "$USER" || return 1; fi
  sudo systemctl enable --now docker.service || return 1
  docker --version && docker compose version
}

configure_smb_mounts() {
  local dir="$HOME/.config/smb-mounts" cred="$dir/credentials"; mkdir -p "$cred"; chmod 0700 "$dir" "$cred"
  if [[ ! -e "$dir/mounts.conf" ]]; then printf '%s\n' '# Bazzite NUC355 per-user SMB/CIFS mounts' '# [NAS]' '# share=//nas.example.local/data' '# mount=NAS' '# credentials=nas' '# options=vers=3.1.1' > "$dir/mounts.conf"; chmod 0600 "$dir/mounts.conf"; fi
  if [[ ! -e "$cred/example" ]]; then printf '%s\n' 'username=YOUR_USERNAME' 'password=YOUR_PASSWORD' '#domain=WORKGROUP' > "$cred/example"; chmod 0600 "$cred/example"; fi
}

install_rider() {
  local app="$HOME/Applications/JetBrains-Rider" launcher="$HOME/Applications/JetBrains-Rider/bin/rider.sh"
  if [[ -x "$launcher" ]]; then echo 'JetBrains Rider is already installed.'; return 0; fi
  local tmp archive url extracted
  tmp="$(mktemp -d -p "$HOME/.cache" rider.XXXXXX)" || return 1
  archive="$tmp/rider.tar.gz"
  url="$(curl -fsSL 'https://data.services.jetbrains.com/products/releases?code=RD&latest=true&type=release' | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["RD"][0]["downloads"]["linux"]["link"])' 2>/dev/null)"
  [[ -n "$url" ]] || { rm -rf "$tmp"; return 1; }
  retry curl -fL "$url" -o "$archive" || { rm -rf "$tmp"; return 1; }
  mkdir -p "$tmp/extract"; tar -xzf "$archive" -C "$tmp/extract" || { rm -rf "$tmp"; return 1; }
  extracted="$(find "$tmp/extract" -mindepth 1 -maxdepth 1 -type d -print -quit)"
  [[ -n "$extracted" && -x "$extracted/bin/rider.sh" ]] || { rm -rf "$tmp"; return 1; }
  rm -rf "$app"; mv "$extracted" "$app" || { rm -rf "$tmp"; return 1; }
  ln -sfn "$launcher" "$HOME/.local/bin/rider"
  cat > "$HOME/.local/share/applications/jetbrains-rider.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=JetBrains Rider
Exec=$launcher %f
Icon=$app/bin/rider.svg
Terminal=false
Categories=Development;IDE;
StartupWMClass=jetbrains-rider
EOF
  rm -rf "$tmp"
  echo 'JetBrains Rider installed directly; Toolbox is no longer used.'
}

verify_balena_etcher() { command -v balena-etcher >/dev/null 2>&1 || command -v balenaEtcher >/dev/null 2>&1 || rpm -q balena-etcher >/dev/null 2>&1; }

install_bootstrap_studio() {
  [[ -x "$HOME/Applications/BootstrapStudio.AppImage" ]] && return 0
  local dl file answer; dl="$(download_dir)"; open_url 'https://bootstrapstudio.io/download/'
  while true; do read -r -p 'When the Bootstrap Studio download is complete, press Enter: ' _; file="$(find "$dl" -maxdepth 1 -type f -iname 'Bootstrap Studio*.AppImage' -print -quit 2>/dev/null)"; [[ -n "$file" ]] && break; read -r -p 'Press Enter to search again, or type q to stop: ' answer; [[ "${answer,,}" == q ]] && return 1; done
  mv -- "$file" "$HOME/Applications/BootstrapStudio.AppImage" || return 1; chmod +x "$HOME/Applications/BootstrapStudio.AppImage"
}

install_tmog() {
  [[ -x "$HOME/Applications/TMOG.AppImage" ]] && return 0
  local dl file answer; dl="$(download_dir)"; open_url 'https://tmog.org/'
  while true; do read -r -p 'When the TMOG download is complete, press Enter: ' _; file="$(find "$dl" -maxdepth 1 -type f \( -iname '*TaskManagerOG*.appimage' -o -iname '*Task*Manager*OG*.appimage' -o -iname '*TMOG*.appimage' \) -print -quit 2>/dev/null)"; [[ -n "$file" ]] && break; read -r -p 'Press Enter to search again, or type q to stop: ' answer; [[ "${answer,,}" == q ]] && return 1; done
  mv -- "$file" "$HOME/Applications/TMOG.AppImage" || return 1; chmod +x "$HOME/Applications/TMOG.AppImage"
}

CHANGED=0; FAILED=()
run_component flatpaks "$FLATPAKS_VERSION" 'Workstation Flatpaks' install_flatpaks || FAILED+=(flatpaks)
run_component docker "$DOCKER_VERSION" 'Docker configuration' configure_docker || FAILED+=(docker)
run_component smb-mounts "$SMB_MOUNTS_VERSION" 'Per-user SMB mount configuration' configure_smb_mounts || FAILED+=(smb-mounts)
run_component rider "$RIDER_VERSION" 'JetBrains Rider' install_rider || FAILED+=(rider)
run_component balena-etcher "$ETCHER_VERSION" 'balenaEtcher' verify_balena_etcher || FAILED+=(balena-etcher)
run_component bootstrap-studio "$BOOTSTRAP_VERSION" 'Bootstrap Studio' install_bootstrap_studio || FAILED+=(bootstrap-studio)
run_component tmog "$TMOG_VERSION" 'TMOG' install_tmog || FAILED+=(tmog)
if ((${#FAILED[@]})); then echo; echo "Failed or deferred components: ${FAILED[*]}"; exit 1; fi
if ((CHANGED == 0)); then exit 0; fi
echo 'Provisioning completed. Rebooting in 10 seconds.'; sleep 10; systemctl reboot || sudo systemctl reboot
