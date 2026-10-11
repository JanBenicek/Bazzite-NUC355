# Bazzite NUC355

Personal Bazzite KDE image for **ASUS NUC 14 Essential NUC14MNK350** with **Intel Core 3 N355, 24 GB RAM and 1 TB NVMe**.

The image is based on `ghcr.io/ublue-os/bazzite:stable` and is intended as an everyday workstation for development, media work and light gaming. Core development and system tools are baked directly into the immutable host image. User applications are installed or configured by versioned provisioning.

## Included in the host image

### Development

- .NET SDK 10
- Git + Git LFS
- PostgreSQL client tools
- Docker Engine (Docker CE)
- containerd
- Docker Buildx
- Docker Compose v2
- Distrobox and Podman from upstream Bazzite

Node.js/npm are intentionally not installed globally. Projects that require them can use Distrobox or install a project-specific environment later.

### Storage and networking

- NTFS read/write tooling (`ntfs-3g`)
- SMB/CIFS tooling (`cifs-utils`)
- GNOME Disks (`gnome-disk-utility`)
- rclone

For applications such as DaVinci Resolve, Docker and command-line tools, a real filesystem mount is generally preferable to a desktop-only SMB URL.

### Media / Intel GPU

- Intel Compute Runtime / OpenCL
- VA-API tools (`vainfo`)
- Intel GPU tools (`igt-gpu-tools`)
- OpenCL diagnostics (`clinfo`)
- FFmpeg
- `n355-media-check` helper

### CLI utilities

- htop
- nano
- jq
- ripgrep
- fd-find
- curl
- unzip
- rclone

Package versions follow the Fedora/Bazzite repositories used by the current upstream Bazzite stable image.

## Desktop applications and provisioning

User-facing applications are managed by a versioned provisioning system. Each component has its own provisioning version, so changing one application does not cause all other applications to be reinstalled.

Currently managed components include:

- Google Chrome — Flatpak
- LocalSend — Flatpak
- Draw.io — Flatpak
- Jellyfin Desktop — Flatpak
- Flatseal — Flatpak
- JetBrains Toolbox / Rider setup
- balenaEtcher
- Bootstrap Studio — AppImage downloaded from the vendor
- TMOG — AppImage downloaded from the vendor
- DaVinci Resolve Studio — vendor Linux ZIP installed through the Bazzite/davincibox workflow
- Docker user-group configuration

Provisioning state is stored per user under:

```text
~/.local/state/bazzite-nuc355/components/
```

Example markers:

```text
flatpaks.v1.done
rider.v1.done
tmog.v1.done
resolve-studio.v1.done
```

When an application such as TMOG, Bootstrap Studio or DaVinci Resolve Studio needs a controlled update, its provisioning version is incremented in the repository. Only that component is then provisioned again.

DaVinci Resolve activation/licensing is never stored in this repository or image.

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
- the SHA tag permanently identifies the image built from a specific Git commit.

The workflow also runs weekly so the image is rebuilt on top of the current Bazzite stable base even when the repository has not changed.

The published image is signed with Cosign. The private signing key exists only as the GitHub Actions secret `SIGNING_SECRET`; `cosign.key` must never be committed.

Changes to `README.md` do **not** trigger an image build. Manual `workflow_dispatch` and the scheduled weekly build remain available independently.

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

### 4. User provisioning

At login, the provisioning mechanism checks the requested version of each component against the completed marker in `~/.local/state/bazzite-nuc355/components/`.

Components already at the requested version are skipped. New or version-bumped components are installed/configured. Failed or deferred components remain incomplete and are retried on a later login.

Some proprietary applications require interaction because their installers must be downloaded directly from the vendor.

## Updates

Every custom build starts from:

```text
ghcr.io/ublue-os/bazzite:stable
```

The NUC follows the `latest` custom image. Bazzite's normal atomic update mechanism can download a newer deployment in the background; the prepared deployment becomes active after reboot.

The expected lifecycle is:

```text
Bazzite stable update / repository change
              ↓
GitHub Actions builds custom image
              ↓
latest + date + SHA tags published to GHCR
              ↓
NUC downloads/prepares new deployment
              ↓
reboot activates new deployment
              ↓
versioned user provisioning checks for requested changes
```

Current deployment information can be checked with:

```bash
bootc status
```

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

The installer then uses the Bazzite Resolve/davincibox installation path.

`n355-media-check` can be used afterwards to inspect Intel OpenCL, VA-API and FFmpeg hardware-acceleration visibility. This does not guarantee support for every codec inside Resolve on Linux.

## Image design

The intended split is:

1. **Host image:** drivers, Intel compute/media support, .NET, Git, Docker, filesystem/network support and common CLI utilities.
2. **Flatpak:** ordinary desktop applications where a maintained Flatpak is suitable.
3. **Vendor package/AppImage:** applications where the normal Flatpak/Fedora route is unsuitable.
4. **Distrobox:** optional isolated/mutable development environments and project-specific stacks.
5. **Versioned provisioning:** lifecycle management for user-level and proprietary applications that should not be baked into the immutable host image.

This keeps the workstation reproducible while retaining Bazzite's atomic/bootc update and rollback model.

## Project status

The OCI image builds and is published to GHCR with Cosign signing and immutable historical tags. Versioned provisioning and automatic hardware hostname support are implemented. The next milestone is validation in a VM followed by testing on the target NUC, including a full update and rollback cycle.
