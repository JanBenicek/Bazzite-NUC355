# Bazzite NUC355

Personal Bazzite KDE image for **ASUS NUC 14 Essential NUC14MNK350** with **Intel Core 3 N355, 24 GB RAM and 1 TB NVMe**.

The image is based on `ghcr.io/ublue-os/bazzite:stable` and is intended as an everyday workstation for development, media work and light gaming. System, driver and development tooling is baked directly into the immutable host image. Desktop Flatpaks and applications that require per-user or interactive setup are handled by versioned first-login provisioning.

## Current layout

### Baked into the immutable host image

Development and containers:

- .NET SDK 10
- Git + Git LFS
- Docker Engine (Docker CE), containerd, Buildx and Compose v2
- Distrobox and Podman from upstream Bazzite

PostgreSQL is intentionally **not** installed in the base image. Development databases can be run in Docker/Compose or another isolated environment when required.

Storage and networking:

- NTFS read/write tooling (`ntfs-3g`)
- SMB/CIFS tooling (`cifs-utils`)
- WireGuard userspace tools (`wireguard-tools`, including `wg` and `wg-quick`)
- GNOME Disks (`gnome-disk-utility`)
- rclone
- `iw` and current Fedora `wireless-regdb`
- `usb_modeswitch` + data files
- TP-Link Archer TBE230U / RTL8922AU Wi-Fi 7 driver support described below

Media / Intel GPU:

- Intel Compute Runtime / OpenCL
- VA-API tools (`vainfo`)
- Intel GPU tools (`igt-gpu-tools`)
- OpenCL diagnostics (`clinfo`)
- FFmpeg
- VLC — native RPM application
- Aegisub — native RPM application
- MusicBrainz Picard — native RPM application
- `n355-media-check` helper

Common CLI tools include htop, nano, jq, ripgrep, fd-find, curl, unzip and rclone. balenaEtcher is also installed into the immutable image.

Package versions follow the Fedora/Bazzite repositories used by the current upstream Bazzite stable image, except where an application or driver is deliberately obtained from its upstream project.

## TP-Link Archer TBE230U / RTL8922AU Wi-Fi 7

The image contains explicit support for the **TP-Link Archer TBE230U**, USB ID `37ad:0105`, based on the current `morrownr/rtw89` driver.

The upstream source currently supports RTL8922AU but does not contain `37ad:0105`. The repository therefore contains the reproducible patch:

```text
build_files/patches/rtw89-tbe230u-37ad-0105.patch
```

It adds the device to `rtw8922au.c` with the correct `rtw89_8922au_info`. The build never uses the unsafe dynamic `new_id` mechanism. If a future upstream version already contains `37ad:0105`, the build detects that and skips the local patch automatically.

`build_files/install-tbe230u-driver.sh` clones the current `morrownr/rtw89`, builds it against the exact OGC `kernel-devel` tree contained in the Bazzite image and installs only the RTL8922AU module chain:

```text
rtw89_core_git
rtw89_usb_git
rtw89_8922a_git
rtw89_8922au_git
```

The required `rtw89/rtw8922a_fw-4.bin` firmware is installed into the immutable deployment. The build fails if the final `rtw89_8922au_git` module does not advertise an alias matching `usb:v37ADp0105`.

This is deliberately an **image-baked kernel module**, not runtime DKMS. Bazzite updates the kernel as part of the atomic image, so every custom image build compiles the driver for that image's exact kernel. Kernel, module and firmware therefore update and roll back together with the bootc deployment. This avoids mutable DKMS state on the installed NUC.

The stock `rtw89_8922au` module is blacklisted so a future in-kernel addition of `37ad:0105` cannot race the tested `_git` driver. `switch_usb_mode=y` remains enabled so the adapter can re-enumerate from USB 2 High-Speed to USB 3 SuperSpeed. `usb_modeswitch` is installed and `0bda:1a2b` is excluded from `usb_storage` binding because the adapter can initially appear as a Realtek installer disk.

### Regulatory domain

Fedora's `wireless-regdb` package is explicitly installed. The image sets:

```text
/etc/sysconfig/regdomain
COUNTRY=CZ
```

This is the Fedora mechanism consumed by `setregdomain`/the wireless-regdb udev integration when an IEEE 802.11 PHY appears. The expected result is:

```text
country CZ: DFS-ETSI
```

This enables the channels allowed by the current Czech/ETSI regulatory database, including the permitted European portion of 6 GHz. Regulatory restrictions are never bypassed by the image.

### Secure Boot note

The custom TBE230U module is currently built directly in this repository and is **not signed by Universal Blue's private kernel-module signing key**. With Secure Boot/module signature enforcement enabled, the kernel can therefore reject this custom module. The clean long-term Secure Boot solution is to move the driver into the Universal Blue akmods build infrastructure (or otherwise establish and enroll a dedicated signing key). Do not assume the driver works under Secure Boot until module signing is implemented and tested.

### TBE230U acceptance test

After booting the new deployment with the adapter attached, verify:

```bash
lsusb
lsusb -t
modinfo rtw89_8922au_git | grep -i 37ADp0105
nmcli device
nmcli device wifi list
iw reg get
iw dev wlan0 link
iw phy
```

Expected key points are `37ad:0105`, `Driver=rtw89_8922au_git`, USB `5000M`, an available Wi-Fi interface, `country CZ: DFS-ETSI`, and `EHT` when connected to a suitable Wi-Fi 7 AP. Physical validation should cover 2.4 GHz, 5 GHz, 6 GHz, reconnect, reboot with the adapter inserted, USB3 re-enumeration, image/kernel update and bootc rollback.

### System-wide Flatpaks installed at first login

The following applications are automatically installed from Flathub as **system-wide Flatpaks**:

- Google Chrome
- Discord
- Prism Launcher
- LocalSend
- Draw.io
- Jellyfin Desktop
- Flatseal
- Moonlight
- TigerVNC Viewer

Flatpak payloads are downloaded on the target machine rather than stored inside the bootc image because Flatpak/Bubblewrap installation is unsuitable inside the restricted GitHub Actions OCI build environment. Provisioning ensures the selected applications are installed but does not automatically uninstall other Flatpaks already present.

### Per-user / interactive provisioning

The versioned provisioning system also handles JetBrains Toolbox / Rider setup, Docker user-group configuration, Bootstrap Studio, TMOG and DaVinci Resolve Studio. Resolve activation/licensing is never stored in this repository or image.

Provisioning state is stored under:

```text
~/.local/state/bazzite-nuc355/components/
```

Current component markers include:

```text
flatpaks.v4.done
docker.v1.done
rider.v1.done
balena-etcher.v2.done
bootstrap-studio.v2.done
tmog.v1.done
resolve-studio.v1.done
```

Failed or deferred components are retried later; completed versions are skipped. The log is `~/.local/state/bazzite-nuc355/provision.log`.

## Automatic hardware hostname

A systemd service generates the hostname from detected hardware before networking starts. The intended format is approximately `NUC-[model]-[RAM]-[disk]`, for example `NUC-14MNK350-24G-1TB`.

## Building and publishing

GitHub Actions builds the image from `main` and publishes it to GHCR as:

```text
ghcr.io/janbenicek/bazzite-n355:latest
ghcr.io/janbenicek/bazzite-n355:YYYY-MM-DD
ghcr.io/janbenicek/bazzite-n355:sha-XXXXXXXXXXXX
```

The workflow also runs weekly so the image is rebuilt on the current Bazzite stable base and current rtw89 source. The published image is signed with Cosign. Changes limited to `README.md` do **not** trigger an image build.

## Installing on a new NUC

Install stock Bazzite KDE first, verify the desktop/networking, then switch to the custom image:

```bash
sudo bootc switch ghcr.io/janbenicek/bazzite-n355:latest
systemctl reboot
```

After reboot:

```bash
bootc status
n355-media-check
dotnet --info
docker --version
docker compose version
vlc --version
aegisub --version
picard --version
wg --version
iw reg get
modinfo rtw89_8922au_git
```

## Updates and rollback

Every custom build starts from `ghcr.io/ublue-os/bazzite:stable`. Bazzite's atomic update mechanism prepares newer deployments in the background and activates them after reboot. The TBE230U module is built into each deployment for that deployment's kernel, so it follows the same atomic lifecycle.

Typical rollback:

```bash
sudo bootc rollback
```

To return to stock Bazzite:

```bash
sudo bootc switch ghcr.io/ublue-os/bazzite:stable
systemctl reboot
```

Historical date/SHA tags in GHCR provide additional recovery points. System-wide Flatpaks have their own lifecycle and are not rolled back by bootc.

## NTFS and SMB/CIFS

External NTFS disks are supported through `ntfs-3g`. For permanent NAS mounts, prefer `/etc/fstab` or systemd automount with `_netdev,nofail,x-systemd.automount` so an unavailable NAS does not block startup.

## DaVinci Resolve Studio

The proprietary Resolve installer is not stored in the image or repository. Provisioning opens the Blackmagic Design download page, locates a `DaVinci_Resolve_Studio_*_Linux.zip`, extracts it and continues through the Bazzite Resolve/davincibox path. License activation remains manual.

## Image design

1. **Immutable bootc host:** kernel-matched TBE230U driver/firmware, Intel compute/media support, .NET, Git, Docker, WireGuard, VLC, Aegisub, MusicBrainz Picard, balenaEtcher, filesystem/network tools and helpers.
2. **System-wide Flatpaks:** standard desktop applications installed automatically during first-login provisioning.
3. **Vendor AppImage/package:** software where a normal Fedora/Flatpak route is unsuitable.
4. **Distrobox:** optional mutable development environments; none is created automatically.
5. **Versioned provisioning:** idempotent lifecycle management for user/system-wide applications.

## Project status

The image publishes to GHCR with Cosign signing and historical tags. Native VLC, Aegisub, MusicBrainz Picard, WireGuard tools and the patched TBE230U RTL8922AU driver are part of the desired immutable host. The next milestone is physical NUC validation, especially TBE230U 2.4/5/6 GHz operation, USB3 switching, image update/rollback and Secure Boot strategy.
