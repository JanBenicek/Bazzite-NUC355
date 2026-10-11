# Bazzite NUC355

Personal Bazzite KDE image for **ASUS NUC 14 Essential NUC14MNK350** with **Intel Core 3 N355, 24 GB RAM and 1 TB NVMe**.

The image is based on upstream `ghcr.io/ublue-os/bazzite:stable` and is intended as an everyday workstation for development, media work and light gaming. Core development tools are installed directly in the immutable host image; Distrobox remains available for isolated environments but is not required for the normal .NET workflow.

## Included in the host image

The custom image currently adds or explicitly provides:

### Development

- .NET SDK 10 (`dotnet-sdk-10.0`)
- ASP.NET Core/.NET 10 runtime and targeting packs pulled as SDK dependencies
- Git
- Git LFS
- Node.js + npm
- PostgreSQL client tools
- Docker Engine (Docker CE)
- containerd
- Docker Buildx
- Docker Compose v2
- Distrobox and Podman from upstream Bazzite remain available

### Media / Intel GPU

- Intel Compute Runtime / OpenCL (`intel-compute-runtime`)
- Intel Level Zero and related runtime dependencies
- VA-API tools (`libva-utils`, including `vainfo`)
- Intel GPU tools (`igt-gpu-tools`)
- OpenCL diagnostics (`clinfo`)
- FFmpeg
- `n355-media-check` helper for checking the Intel GPU, VA-API, OpenCL and FFmpeg hardware acceleration

### CLI utilities

- rclone
- jq
- ripgrep
- fd-find
- curl
- unzip

The exact package versions follow the Fedora/Bazzite repositories used by the current upstream Bazzite stable image.

## Desktop applications / first-login setup

A first-login provisioning script is included in the image. It currently handles or prepares installation of:

- Google Chrome — Flatpak
- LocalSend — Flatpak
- Draw.io — Flatpak
- Jellyfin Desktop — Flatpak
- Flatseal — Flatpak
- JetBrains Toolbox / Rider setup
- Bootstrap Studio — AppImage downloaded interactively from the vendor
- TMOG — AppImage downloaded interactively from the vendor
- DaVinci Resolve Studio — vendor Linux ZIP downloaded interactively and installed through the Bazzite/davincibox workflow
- Docker user-group configuration

DaVinci Resolve Studio, Bootstrap Studio and TMOG cannot simply be redistributed inside this public image, so first-login setup opens their official download pages and continues after the installer/AppImage has been downloaded.

DaVinci Resolve activation/licensing is intentionally not stored in this repository or image.

## Building the image

GitHub Actions builds the image from `main` and publishes:

```text
ghcr.io/janbenicek/bazzite-n355:latest
```

The workflow also runs weekly so the custom image is rebuilt on top of the current Bazzite stable base.

The published image is signed with Cosign. The private signing key is stored only as the GitHub Actions secret `SIGNING_SECRET`; `cosign.key` must never be committed to the repository.

## Installing the OS on a new NUC

This repository currently publishes a bootc/OCI operating-system image, not a standalone custom USB ISO installer. The recommended installation path is therefore to install normal Bazzite first and then switch that installation to this custom image.

### 1. Install stock Bazzite KDE

Download the normal Bazzite desktop/KDE installer from the official Bazzite website, create a bootable USB drive and install Bazzite on the NUC normally.

Use the normal desktop/KDE variant rather than a handheld/Steam Gaming Mode image for this workstation.

After installation, boot the installed Bazzite system and make sure networking and the desktop work normally.

### 2. Switch to the custom image

Open Konsole and run:

```bash
sudo bootc switch ghcr.io/janbenicek/bazzite-n355:latest
```

After the deployment finishes, reboot:

```bash
systemctl reboot
```

### 3. Verify the deployment

After reboot:

```bash
bootc status
```

The active image should point to:

```text
ghcr.io/janbenicek/bazzite-n355:latest
```

Then check the Intel media/compute stack:

```bash
n355-media-check
```

Useful development checks:

```bash
dotnet --info
git --version
node --version
npm --version
docker --version
docker compose version
rclone version
```

### 4. First-login provisioning

The image contains a KDE autostart entry which launches the NUC355 first-login setup in Konsole. It installs/configures the user-facing applications that should not be baked directly into the immutable OS image.

Some proprietary applications require interaction because their installers must be downloaded from the vendor. Follow the prompts in the first-login terminal window.

Docker may request sudo authentication while adding the desktop user to the `docker` group. Group membership becomes active after logging out/in or rebooting.

> Membership in the `docker` group effectively grants root-level control of the machine. This is intentional for this workstation image.

## Updating

Every custom build starts from:

```text
ghcr.io/ublue-os/bazzite:stable
```

so rebuilding the repository automatically incorporates the current upstream Bazzite stable base.

The GitHub Actions workflow runs on pushes affecting the image and once per week. After a new image has been published, the machine can receive the new bootc deployment through the normal Bazzite/bootc update mechanism.

Current deployment information can always be checked with:

```bash
bootc status
```

## Rollback / return to stock Bazzite

bootc keeps deployment history, so a previous deployment can be selected from the bootloader when necessary.

To permanently switch the machine back to stock Bazzite stable:

```bash
sudo bootc switch ghcr.io/ublue-os/bazzite:stable
systemctl reboot
```

## DaVinci Resolve Studio

The proprietary Resolve installer is deliberately not stored in the image or Git repository.

The first-login helper opens the Blackmagic Design download page, waits for a file matching:

```text
DaVinci_Resolve_Studio_*_Linux.zip
```

and then uses the Bazzite Resolve/davincibox installation path.

After installation use:

```bash
n355-media-check
```

to inspect Intel OpenCL, VA-API and FFmpeg hardware acceleration visibility. This does not guarantee that every codec is supported by Resolve on Linux.

## Image design

The intended split is:

1. **Host image:** drivers, Intel compute/media support, .NET/Node development stack, Git, Docker and commonly used CLI tools.
2. **Flatpak:** ordinary desktop applications where a maintained Flatpak is suitable.
3. **AppImage/vendor installer:** applications such as Bootstrap Studio, TMOG and DaVinci Resolve Studio where redistribution or packaging makes Flatpak unsuitable.
4. **Distrobox:** optional isolated/mutable development environments, not the primary .NET development environment.

This keeps the workstation reproducible while retaining the atomic/bootc update model of Bazzite.

## Current project status

The OCI image itself successfully builds and pushes to GHCR. Remaining CI/provisioning work is being validated before this image should be considered production-ready for a fresh workstation installation.
