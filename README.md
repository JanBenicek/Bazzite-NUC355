# Bazzite NUC355

Personal Bazzite KDE image for **ASUS NUC 14 Essential NUC14MNK350** with **Intel Core 3 N355, 24 GB RAM and 1 TB NVMe**.

The image is based on `ghcr.io/ublue-os/bazzite:stable` and is intended as an everyday workstation for development, media work and light gaming. System, driver and development tooling is baked directly into the immutable host image. Desktop Flatpaks and applications that require per-user or interactive setup are handled by versioned first-login provisioning.

## Current layout

### Baked into the immutable host image

Development and containers:

- .NET SDK 10
- Git + Git LFS
- Docker Engine (Docker CE)
- containerd
- Docker Buildx
- Docker Compose v2
- Distrobox and Podman from upstream Bazzite

PostgreSQL is intentionally **not** installed in the base image. Development databases can be run in Docker/Compose or another isolated environment when required.

Storage and networking:

- NTFS read/write tooling (`ntfs-3g`)
- SMB/CIFS tooling (`cifs-utils`)
- GNOME Disks (`gnome-disk-utility`)
- rclone

Media / Intel GPU:

- Intel Compute Runtime / OpenCL
- VA-API tools (`vainfo`)
- Intel GPU tools (`igt-gpu-tools`)
- OpenCL diagnostics (`clinfo`)
- FFmpeg
- `n355-media-check` helper

Common CLI tools:

- htop
- nano
- jq
- ripgrep
- fd-find
- curl
- unzip
- rclone

Desktop/system package:

- balenaEtcher

Package versions follow the Fedora/Bazzite repositories used by the current upstream Bazzite stable image, except where an application is deliberately obtained from its vendor.

### System-wide Flatpaks installed at first login

The following applications are automatically installed from Flathub as **system-wide Flatpaks**:

- Google Chrome
- LocalSend
- Draw.io
- Jellyfin Desktop
- Flatseal
- Moonlight
- TigerVNC Viewer

These Flatpaks are not installed while the OCI image itself is being built. Flatpak application installation uses Bubblewrap/user namespaces and does not work reliably inside the restricted Podman build environment used by GitHub Actions. Instead, the immutable image contains the provisioning logic and installs the applications on the real Bazzite host at first login.

This means the applications are part of the intended standard installation, but their Flatpak payloads are downloaded on the target machine rather than stored inside the bootc image.

### Per-user / interactive provisioning

The same versioned provisioning system handles:

- JetBrains Toolbox / Rider setup
- Docker user-group configuration
- Bootstrap Studio — AppImage downloaded from the vendor
- TMOG — AppImage downloaded from the vendor
- DaVinci Resolve Studio — vendor Linux ZIP installed through the Bazzite/davincibox workflow

DaVinci Resolve activation/licensing is never stored in this repository or image.

## Provisioning model

Provisioning state is stored per user under:

```text
~/.local/state/bazzite-nuc355/components/
```

Each component has an independent version. Current examples include:

```text
flatpaks.v2.done
docker.v1.done
rider.v1.done
balena-etcher.v2.done
bootstrap-studio.v2.done
tmog.v1.done
resolve-studio.v1.done
```

Components already at the requested version are skipped. If provisioning logic or the desired state of one component changes, only its version is incremented and only that component runs again.

Failed or intentionally deferred components remain incomplete and are retried at a later login. The provisioning log is stored at:

```text
~/.local/state/bazzite-nuc355/provision.log
```

When provisioning actually changes the system, the current script requests a reboot after successful completion so changes such as Docker group membership become active.

## Automatic hardware hostname

The image contains a systemd service which generates the hostname from detected hardware before networking starts.

The intended format is approximately:

```text
NUC-[model]-[RAM]-[disk]
```

For example:

```text
NUC-14MNK350-24G-1TB
```

The final value is shortened when necessary to keep the hostname practical for Linux/container tooling. RAM and system-disk size are detected dynamically rather than hard-coded for one machine.

## Building and publishing

GitHub Actions builds the image from `main` and publishes it to GHCR.

Every successful build receives multiple tags:

```text
ghcr.io/janbenicek/bazzite-n355:latest
ghcr.io/janbenicek/bazzite-n355:YYYY-MM-DD
ghcr.io/janbenicek/bazzite-n355:sha-XXXXXXXXXXXX
```

- `latest` is the normal update channel.
- the date tag provides a convenient historical reference.
- the SHA tag identifies the image built from a specific Git commit.

The workflow also runs weekly so the image is rebuilt on top of the current Bazzite stable base even when the repository has not changed.

The published image is signed with Cosign. The private signing key exists only as the GitHub Actions secret `SIGNING_SECRET`; `cosign.key` must never be committed.

Changes limited to `README.md` do **not** trigger an image build. Manual `workflow_dispatch` and the scheduled weekly build remain available independently.

The build following the move of Flatpak installation back to host-side provisioning completed successfully (`582e6efdbca3ad943e9693f39a49d629ded6919b`).

## Installing on a new NUC

The repository publishes a bootc/OCI operating-system image, not a standalone custom USB ISO. Install stock Bazzite KDE first and then switch the installation to this image.

### 1. Install stock Bazzite KDE

Install the normal Bazzite desktop/KDE variant and verify that networking and the desktop work normally.

### 2. Switch to the custom image

Open Konsole and run:

```bash
sudo bootc switch ghcr.io/janbenicek/bazzite-n355:latest
systemctl reboot
```

### 3. Verify the deployment

After reboot:

```bash
bootc status
n355-media-check
```

Useful checks:

```bash
dotnet --info
git --version
docker --version
docker compose version
rclone version
htop --version
nano --version
```

### 4. Complete first-login provisioning

After login, the provisioning script checks the requested version of every managed component against its marker in `~/.local/state/bazzite-nuc355/components/`.

The system-wide Flatpaks are downloaded and installed at this stage. Some proprietary applications require interaction because their installers must be downloaded directly from the vendor.

If a component is deferred or fails, completed components are retained and only incomplete/outdated components need to run again later.

## Updates

Every custom build starts from:

```text
ghcr.io/ublue-os/bazzite:stable
```

The NUC follows the `latest` custom image. Bazzite's atomic update mechanism can download a newer deployment in the background; the prepared deployment becomes active after reboot.

The expected lifecycle is:

```text
Bazzite stable update / repository change
              ↓
GitHub Actions builds custom bootc image
              ↓
latest + date + SHA tags published to GHCR
              ↓
NUC downloads/prepares new deployment
              ↓
reboot activates new deployment
              ↓
versioned provisioning checks desired user/system-wide app state
```

Current deployment information can be checked with:

```bash
bootc status
```

Flatpaks remain managed by Flatpak on the installed host and are not embedded into the bootc deployment itself.

## Rollback

The local system keeps deployment history for normal atomic rollback. A previous deployment can be selected when a new image causes a problem.

Typical rollback command:

```bash
sudo bootc rollback
```

Historical date/SHA image tags in GHCR additionally allow explicitly returning to an older published custom image when required.

To switch back to stock Bazzite stable:

```bash
sudo bootc switch ghcr.io/ublue-os/bazzite:stable
systemctl reboot
```

Note that bootc rollback changes the OS deployment. System-wide Flatpaks installed on the host have their own lifecycle and are not rolled back merely by switching the bootc deployment.

## NTFS and SMB/CIFS

External NTFS disks are supported through `ntfs-3g`. Avoid moving a volume from Windows while it is hibernated or Fast-Startup-locked.

A temporary SMB mount can be created with, for example:

```bash
sudo mkdir -p /mnt/nas
sudo mount -t cifs //server/share /mnt/nas -o username=USER
```

For permanent NAS mounts, prefer `/etc/fstab` or systemd automount configuration with options such as `_netdev,nofail,x-systemd.automount` so an unavailable NAS does not block startup.

## DaVinci Resolve Studio

The proprietary Resolve installer is deliberately not stored in the image or Git repository. The provisioning helper opens the Blackmagic Design download page and expects a Linux Studio ZIP matching:

```text
DaVinci_Resolve_Studio_*_Linux.zip
```

After the download is confirmed, the helper extracts the Studio installer and continues through the Bazzite Resolve/davincibox installation path. License activation remains manual and outside the repository.

`n355-media-check` can be used afterwards to inspect Intel OpenCL, VA-API and FFmpeg hardware-acceleration visibility. This does not guarantee support for every codec inside Resolve on Linux.

## Image design

The current split is:

1. **Immutable bootc host image:** drivers, Intel compute/media support, .NET, Git, Docker, balenaEtcher, filesystem/network support, common CLI utilities and the provisioning helpers.
2. **System-wide Flatpaks:** standard desktop applications installed automatically on the actual host during first-login provisioning.
3. **Vendor AppImage/package:** applications where a normal Fedora/Flatpak route is unsuitable.
4. **Distrobox:** optional isolated/mutable development environments and project-specific stacks; no development container is created automatically.
5. **Versioned provisioning:** idempotent lifecycle management for Flatpaks, user setup and proprietary applications.

This preserves Bazzite's atomic/bootc image model while avoiding Flatpak/Bubblewrap operations inside the restricted OCI build environment.

## Project status

The OCI image currently builds successfully and is published to GHCR with Cosign signing and historical date/SHA tags. Versioned provisioning and automatic hardware hostname support are implemented. PostgreSQL has been removed from the base image. The standard desktop Flatpaks now install system-wide on the target host during first-login provisioning.

The next milestone is validation on the target NUC, including first-login provisioning, hardware acceleration, application startup, update and rollback testing.
