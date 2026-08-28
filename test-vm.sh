#!/usr/bin/env bash
# Boot the ISO in QEMU (UEFI). Requires: sudo pacman -S qemu-desktop edk2-ovmf
set -euo pipefail
HERE="$(dirname "$0")"
ISO=${1:-$(ls -t "$HERE"/out/*.iso | head -1)}
DISK="$HERE/work/test-disk.qcow2"
VARS="$HERE/work/OVMF_VARS.4m.fd"
[[ -f $DISK ]] || qemu-img create -f qcow2 "$DISK" 40G >/dev/null
# Writable NVRAM copy, so efibootmgr entries written by the installer persist.
[[ -f $VARS ]] || cp /usr/share/edk2/x64/OVMF_VARS.4m.fd "$VARS"
exec qemu-system-x86_64 -enable-kvm -m 6G -smp 4 -cpu host \
  -machine q35 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file="$VARS" \
  -device virtio-vga-gl -display gtk,gl=on \
  -monitor unix:"$HERE/work/qemu-mon.sock",server,nowait \
  -device virtio-net,netdev=n0 -netdev user,id=n0 \
  -drive file="$DISK",if=virtio \
  -cdrom "$ISO" -boot d
