#!/usr/bin/env bash
set -euo pipefail

# Generate a short, stable hostname from hardware. Bazzite recommends hostnames
# shorter than 20 characters because of Distrobox compatibility.
model_raw="$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || true)"
model="$(printf '%s' "$model_raw" | tr -cd '[:alnum:]' | sed -E 's/^NUC//I' | head -c 8)"
[[ -n "$model" ]] || model='PC'

mem_kib="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
mem_gib="$(( (mem_kib + 524288) / 1048576 ))"

# Prefer the physical disk containing the root filesystem; fall back to the
# largest non-removable disk visible to lsblk.
root_source="$(findmnt -n -o SOURCE / || true)"
root_parent="$(lsblk -ndo PKNAME "$root_source" 2>/dev/null | head -n1 || true)"
if [[ -n "$root_parent" ]]; then
  disk_bytes="$(lsblk -bdno SIZE "/dev/$root_parent" 2>/dev/null | head -n1 || true)"
else
  disk_bytes="$(lsblk -bdno SIZE,TYPE,RM | awk '$2=="disk" && $3==0 {if ($1>max) max=$1} END {print max}')"
fi
[[ "$disk_bytes" =~ ^[0-9]+$ ]] || disk_bytes=0

if (( disk_bytes >= 900000000000 )); then
  disk="$(( (disk_bytes + 500000000000) / 1000000000000 ))TB"
else
  disk="$(( (disk_bytes + 500000000) / 1000000000 ))GB"
fi

hostname="NUC-${model}-${mem_gib}G-${disk}"
# Keep under Bazzite's documented 20-character recommendation.
hostname="${hostname:0:19}"
hostname="${hostname%-}"

current="$(hostnamectl --static 2>/dev/null || hostname)"
if [[ "$current" != "$hostname" ]]; then
  echo "Setting hostname: $current -> $hostname"
  hostnamectl hostname "$hostname"
fi
