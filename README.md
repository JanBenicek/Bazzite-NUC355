# bazzite-n355

Personal Bazzite KDE image for **ASUS NUC 14 Essential NUC14MNK350** with
**Intel Core 3 N355, 24 GB RAM and 1 TB NVMe**.

The image intentionally stays close to upstream Bazzite. It adds only the
host-level pieces that are useful for the Intel iGPU / media workflow and keeps
normal applications and development SDKs outside the immutable base image.

## What is added to Bazzite

- Intel OpenCL compute runtime (`intel-compute-runtime`)
- VA-API diagnostics (`vainfo`)
- Intel GPU diagnostics (`igt-gpu-tools`)
- OpenCL diagnostics (`clinfo`)
- `git-lfs`
- `rclone`
- `n355-media-check` helper command

Bazzite itself already provides KDE Plasma, Steam/gaming integration, Distrobox,
Podman and multimedia support, so they are not duplicated here.

## Application strategy

- **DaVinci Resolve:** use Bazzite's `ujust install-resolve` / davincibox workflow.
- **JetBrains Rider:** JetBrains Toolbox or the preferred JetBrains distribution;
  keep SDK/toolchain dependencies in a development Distrobox where practical.
- **Chrome, LocalSend, Draw.io, Jellyfin Desktop:** Flatpak where appropriate.
- **TMOG:** AppImage.
- **Development SDKs:** Fedora Distrobox named `dev`.

Suggested Flatpaks are in `config/flatpaks.txt` and suggested dev packages are in
`config/dev-distrobox-packages.txt`.

## 1. Repository

This repository is the source for the custom image. The build workflow publishes it to GHCR from the `main` branch.

## 2. Generate a cosign key

The Universal Blue template model expects custom images to be signed.
Generate a passwordless key pair **locally**:

```bash
COSIGN_PASSWORD="" cosign generate-key-pair
```

Commit **only** `cosign.pub`:

```bash
git add cosign.pub
git commit -m "Add image signing public key"
git push
```

Never commit `cosign.key`; it is ignored by `.gitignore`.

In GitHub open:

`Settings -> Secrets and variables -> Actions -> New repository secret`

Create the secret:

- Name: `SIGNING_SECRET`
- Value: complete contents of `cosign.key`

Then delete or securely archive the local private key.

## 3. Enable and run GitHub Actions

Open the repository's **Actions** tab and enable workflows if GitHub asks.
Run **Build custom Bazzite image** manually once. The workflow also rebuilds
weekly so that the resulting image follows upstream `bazzite:stable`.

The resulting image is:

```text
ghcr.io/janbenicek/bazzite-n355:latest
```

If the GHCR package is private, make it public before switching a normal client
to it, or configure registry credentials on that client.

## 4. Switch an installed Bazzite system to the custom image

First verify that a normal Bazzite installation works on the NUC. Then:

```bash
sudo bootc switch ghcr.io/janbenicek/bazzite-n355:latest
systemctl reboot
```

After reboot:

```bash
bootc status
n355-media-check
```

Do not switch until the GitHub Actions build has completed successfully.

### Returning to stock Bazzite

```bash
sudo bootc switch ghcr.io/ublue-os/bazzite:stable
systemctl reboot
```

## 5. User applications

After cloning this repository on the NUC you may run:

```bash
./setup-user.sh
```

This installs the listed Flatpaks and creates a `dev` Distrobox. Review
`config/flatpaks.txt` first and delete anything you do not want.

For the development container:

```bash
distrobox enter dev
sudo dnf install $(grep -Ev '^[[:space:]]*(#|$)' config/dev-distrobox-packages.txt)
```

## DaVinci Resolve

Do **not** bake the proprietary Resolve installer into this image. On Bazzite use:

```bash
ujust install-resolve
```

After installation, use:

```bash
n355-media-check
```

to inspect Intel OpenCL, VA-API and FFmpeg hardware acceleration visibility.
This does not guarantee that every codec is supported inside Resolve; Resolve
Studio/Free and Linux codec support differ.

## Updating the custom image

There is normally nothing special to merge from Bazzite: every build starts
from the current `ghcr.io/ublue-os/bazzite:stable` base. A scheduled GitHub
Actions build runs once a week and a push to `main` also creates a new image.

The NUC then receives the newly published deployment through the normal Bazzite /
bootc update path.

## Design rule

Keep additions to `build_files/build.sh` limited to things that truly belong on
the host. Prefer, in order:

1. Flatpak for desktop applications
2. AppImage where suitable
3. Distrobox for SDKs, CLI stacks and mutable development environments
4. host packages in this custom image only when host integration is required

This keeps rebases and upgrades much less fragile.
