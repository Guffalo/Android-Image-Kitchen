#!/usr/bin/env bash
# flash-linux-full.sh
# Direct BROM flash of Alpine Linux onto Artia P600 (MediaTek).
# Uses mtkclient -- no fastboot needed, no bootloader lock matters.
# Device is treated as sacrificial. No confirmation prompts.
#
# Run from a PC (Linux or WSL2 recommended).
# Windows: use WSL2 with usbipd to forward the USB device.
#
# PREREQS:
#   pip3 install mtkclient
#   apt install python3-pip adb   (or brew install on Mac)

set -euo pipefail

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[0;34m%s\033[0m\n' "$*"; }

WORKDIR="$(mktemp -d /tmp/p600-flash.XXXXXX)"
chmod 700 "$WORKDIR"

cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

banner() {
  blue ""
  blue "================================================"
  blue "  Artia P600 -- Full Linux Flash (BROM mode)"
  blue "  Method: mtkclient direct eMMC write"
  blue "  Target: Alpine Linux ARM"
  blue "================================================"
  blue ""
}

check_deps() {
  local missing=0
  for cmd in python3 pip3; do
    command -v "$cmd" &>/dev/null || { red "Missing: $cmd"; missing=1; }
  done
  [ $missing -eq 1 ] && { red "Install python3 and pip3 first."; exit 1; }

  if ! python3 -c 'import mtkclient' 2>/dev/null; then
    yellow "Installing mtkclient..."
    pip3 install mtkclient
  fi
  green "Dependencies OK."
}

brom_detect() {
  blue ""
  blue "BROM Detection"
  blue "--------------"
  echo "Put the Artia P600 into BROM mode:"
  echo "  Method 1: Power OFF the device completely."
  echo "            Hold VOL+ and plug in USB-C."
  echo "  Method 2: With battery out (if removable),"
  echo "            plug in USB-C directly."
  echo ""
  echo "Waiting for BROM connection (up to 60s)..."

  local detected
  detected=$(timeout 60 python3 -m mtkclient identify 2>&1) || {
    red "BROM detection failed."
    red "Make sure the device is fully powered off before connecting."
    echo "Raw output:"
    echo "$detected"
    exit 1
  }

  echo "$detected"
  green "BROM connected."

  # Parse chipset from mtkclient output
  SOC=$(echo "$detected" | grep -oiE 'MT[0-9]+[A-Z]*' | head -1 || true)
  ARCH=$(echo "$detected" | grep -oiE 'aarch64|arm64|armv7|arm32|32bit|64bit' | head -1 || true)

  if [ -z "$SOC" ]; then
    yellow "Could not auto-parse SoC from output. Defaulting to MT6739 (most likely for this hw)."
    SOC="MT6739"
  fi

  if [ -z "$ARCH" ]; then
    # MT6739 is ARMv8 but runs 32-bit Android Go -- use arm (32-bit) for broadest compat
    ARCH="arm"
  fi

  green "SoC: $SOC | Arch: $ARCH"
}

download_alpine() {
  blue ""
  blue "Downloading Alpine Linux ($ARCH)..."

  local ALPINE_VER="3.20.3"
  local BASE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.20/releases"
  local IMG

  case "$ARCH" in
    aarch64|arm64)
      IMG="alpine-minirootfs-${ALPINE_VER}-aarch64.tar.gz"
      ;;
    *)
      IMG="alpine-minirootfs-${ALPINE_VER}-armv7.tar.gz"
      ;;
  esac

  curl -L --progress-bar -o "$WORKDIR/$IMG" "$BASE_URL/$ARCH/$IMG"
  green "Downloaded: $IMG"

  # Verify checksum
  curl -sL "$BASE_URL/$ARCH/$IMG.sha256" -o "$WORKDIR/$IMG.sha256"
  (cd "$WORKDIR" && sha256sum -c "$IMG.sha256") || {
    red "Checksum mismatch -- download may be corrupt. Abort."
    exit 1
  }
  green "Checksum OK."

  ROOTFS="$WORKDIR/$IMG"
}

build_image() {
  blue ""
  blue "Building flashable ext4 image..."

  local IMG_FILE="$WORKDIR/alpine-rootfs.img"
  local MOUNT_DIR="$WORKDIR/mnt"
  mkdir -p "$MOUNT_DIR"

  # 2GB image -- fits on 32GB eMMC with room to spare
  dd if=/dev/zero of="$IMG_FILE" bs=1M count=2048 status=progress
  mkfs.ext4 -L alpine-root "$IMG_FILE"
  mount -o loop "$IMG_FILE" "$MOUNT_DIR"
  tar xzf "$ROOTFS" -C "$MOUNT_DIR"

  # Minimal first-boot setup
  cat > "$MOUNT_DIR/etc/resolv.conf" <<'EOF'
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF

  cat > "$MOUNT_DIR/etc/fstab" <<'EOF'
/dev/mmcblk0p21  /        ext4  defaults,noatime  0 1
tmpfs            /tmp     tmpfs defaults          0 0
EOF

  # Enable serial console for headless access
  ln -sf /etc/init.d/agetty "$MOUNT_DIR/etc/runlevels/default/agetty-ttyS0" 2>/dev/null || true

  umount "$MOUNT_DIR"
  green "Image built: $IMG_FILE"
  FLASH_IMG="$IMG_FILE"
}

flash_device() {
  blue ""
  blue "Flashing to eMMC via BROM..."
  yellow "Do NOT unplug during flash."

  # userdata partition is typically the largest and safest target
  # on MediaTek Android Go devices. Adjust partition name if needed.
  python3 -m mtkclient w userdata "$FLASH_IMG" || {
    red "Flash via partition name failed. Trying raw eMMC write..."
    # Fallback: write at offset after system partitions (~4GB in)
    python3 -m mtkclient w 0x100000000 "$FLASH_IMG"
  }

  green "Flash complete."
}

write_bootscript() {
  blue ""
  blue "Writing boot configuration..."

  # Dump current boot.img, patch it to chainload our rootfs
  python3 -m mtkclient r boot "$WORKDIR/boot-orig.img" || {
    yellow "Could not read boot partition. Manual boot config needed."
    echo "See: https://postmarketos.org/devices for device-specific boot guides."
    return
  }

  green "Original boot image saved to $WORKDIR/boot-orig.img"
  echo "NOTE: For full boot into Alpine (not just chroot), you need a kernel"
  echo "that matches this MediaTek SoC ($SOC). Options:"
  echo ""
  echo "  1. postmarketOS kernel port (best HW support):"
  echo "       https://postmarketos.org/devices"
  echo "       pmbootstrap init && pmbootstrap install && pmbootstrap flasher"
  echo ""
  echo "  2. Use Android's kernel + Alpine userspace (works NOW):"
  echo "       The flashed Alpine rootfs is accessible via chroot from"
  echo "       the Android recovery or via Termux until a custom kernel is built."
}

main() {
  banner
  check_deps
  brom_detect
  download_alpine

  # Need root for loopback mount
  if [ "$EUID" -ne 0 ]; then
    yellow "Re-running with sudo for loopback mount..."
    exec sudo -E bash "$0" "$@"
  fi

  build_image
  flash_device
  write_bootscript

  green ""
  green "=== DONE ==="
  green "Alpine Linux rootfs flashed to Artia P600."
  echo ""
  echo "Next: power cycle the device."
  echo "If it boots to Android recovery, use 'adb shell' to chroot into Alpine:"
  echo "  adb shell"
  echo "  chroot /data/alpine /bin/sh"
  echo "  apk update && apk add bash openssh"
  echo ""
  echo "For a full native boot (replaces Android kernel), use postmarketOS:"
  echo "  pip3 install pmbootstrap && pmbootstrap init"
}

main "$@"
