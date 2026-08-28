#!/usr/bin/env bash
# Boot the ISO in QEMU (UEFI). Requires: sudo pacman -S qemu-desktop edk2-ovmf
set -euo pipefail
ISO=${1:-$(ls -t "$(dirname "$0")"/out/*.iso | head -1)}
DISK="$(dirname "$0")/work/test-disk.qcow2"
[[ -f $DISK ]] || qemu-img create -f qcow2 "$DISK" 40G >/dev/null
exec qemu-system-x86_64 -enable-kvm -m 6G -smp 4 -cpu host \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -device virtio-vga-gl -display gtk,gl=on \
  -device virtio-net,netdev=n0 -netdev user,id=n0 \
  -drive file="$DISK",if=virtio \
  -cdrom "$ISO" -boot d
