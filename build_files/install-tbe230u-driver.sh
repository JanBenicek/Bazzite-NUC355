#!/usr/bin/env bash
set -euo pipefail

RTW89_REPO="https://github.com/morrownr/rtw89.git"
SRC="$(mktemp -d -t rtw89.XXXXXX)"
trap 'rm -rf "$SRC"' EXIT

# Bazzite installs the exact OGC kernel-devel package into the image. Build for
# that image kernel rather than the CI runner kernel returned by uname -r.
KVER="$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V | tail -n1)"
KDIR="/usr/lib/modules/${KVER}/build"
[[ -d "$KDIR" ]] || { echo "Missing kernel build tree: $KDIR" >&2; exit 1; }

echo "Building morrownr/rtw89 for Bazzite kernel: $KVER"
git clone --depth=1 "$RTW89_REPO" "$SRC"
RTW89_COMMIT="$(git -C "$SRC" rev-parse HEAD)"
echo "rtw89 source commit: $RTW89_COMMIT"

# Upstream currently lacks TP-Link Archer TBE230U (37ad:0105). Keep the patch
# in this repository, but automatically stop applying it once upstream adds the
# ID itself.
if grep -qiE '0x37ad,[[:space:]]*0x0105' "$SRC/rtw8922au.c"; then
  echo 'TBE230U USB ID 37ad:0105 is already present upstream; local patch not needed.'
else
  patch -d "$SRC" -p1 --forward < /ctx/patches/rtw89-tbe230u-37ad-0105.patch
fi

grep -qiE '0x37ad,[[:space:]]*0x0105' "$SRC/rtw8922au.c" || {
  echo 'TBE230U USB ID patch verification failed.' >&2
  exit 1
}

make -C "$SRC" KVER="$KVER" KDIR="$KDIR" clean
make -C "$SRC" KVER="$KVER" KDIR="$KDIR" -j"$(nproc)" modules

# Install only the module chain required by RTL8922AU. Keeping the remaining
# out-of-tree rtw89 modules out of the image minimizes interaction with stock
# in-kernel rtw89 drivers for unrelated adapters.
MODDIR="/usr/lib/modules/${KVER}/extra/rtw89-tbe230u"
install -d "$MODDIR"
for module in rtw89_core_git rtw89_usb_git rtw89_8922a_git rtw89_8922au_git; do
  file="$SRC/${module}.ko"
  [[ -f "$file" ]] || { echo "Expected module missing: $file" >&2; exit 1; }
  strip -g "$file"
  install -m0644 "$file" "$MODDIR/"
done

# The tested adapter requires this firmware. Install the exact upstream file
# even when linux-firmware already provides another rtw8922a firmware revision.
FW="$SRC/firmware/rtw8922a_fw-4.bin"
[[ -f "$FW" ]] || { echo 'rtw8922a_fw-4.bin missing from rtw89 source.' >&2; exit 1; }
install -Dm0644 "$FW" /usr/lib/firmware/rtw89/rtw8922a_fw-4.bin

depmod -a "$KVER"

MODULE="$MODDIR/rtw89_8922au_git.ko"
modinfo -F alias "$MODULE" | grep -qi 'usb:v37ADp0105' || {
  echo 'Built rtw89_8922au_git does not advertise usb:v37ADp0105.' >&2
  modinfo "$MODULE" >&2 || true
  exit 1
}

echo 'Verified module alias for TP-Link Archer TBE230U (37ad:0105).'
modinfo -F alias "$MODULE" | grep -i 'usb:v37ADp0105'
