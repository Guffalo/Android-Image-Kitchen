#!/usr/bin/env bash
# flash-linux.sh — Full Linux flash path for Artia P600.
# Run from a PC. Requires: adb, fastboot, detect-device.sh output.
#
# STOP: Run detect-device.sh first and confirm your chipset.
# This script will NOT proceed until you provide the confirmed SoC model.

set -euo pipefail

red()    { echo -e "\033[0;31m$*\033[0m"; }
green()  { echo -e "\033[0;32m$*\033[0m"; }
yellow() { echo -e "\033[0;33m$*\033[0m"; }

banner() {
  echo ""
  echo "================================================"
  echo "  Artia P600 — Full Linux Flash Tool"
  echo "  Device: ANS Artia P600 | 2GB RAM | Android 11 Go"
  echo "================================================"
  echo ""
}

check_deps() {
  local missing=0
  for cmd in adb fastboot; do
    if ! command -v "$cmd" &>/dev/null; then
      red "ERROR: '$cmd' not found."
      missing=1
    fi
  done
  if [ $missing -eq 1 ]; then
    echo "Install Android Platform Tools:"
    echo "  https://developer.android.com/tools/releases/platform-tools"
    exit 1
  fi
}

require_chipset_confirmation() {
  yellow "REQUIRED: Run detect-device.sh first to get your exact chipset."
  yellow "The Artia P600 chipset model is not publicly documented."
  yellow "Flashing the wrong image can brick the device."
  echo ""
  echo "Paste the 'Hardware' or 'SoC model' value from detect-device.sh output:"
  read -rp "> SoC model: " SOC_MODEL

  if [ -z "$SOC_MODEL" ]; then
    red "ERROR: SoC model is required. Run detect-device.sh first."
    exit 1
  fi

  echo ""
  echo "You entered: $SOC_MODEL"
  read -rp "Confirm this is correct? [y/N]: " CONFIRM
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Aborted."
    exit 0
  fi
}

check_device_connected() {
  echo "Checking ADB connection..."
  if ! adb devices | grep -q 'device$'; then
    red "ERROR: No device found via ADB."
    echo "Check:"
    echo "  1. USB cable is connected"
    echo "  2. USB debugging is enabled (Settings > Developer Options)"
    echo "  3. You approved the ADB RSA key on the device"
    exit 1
  fi
  green "Device connected."
}

print_flash_options() {
  echo ""
  echo "Available distributions for ARM devices (lightest first):"
  echo ""
  echo "  1) Alpine Linux    — ~130MB, musl libc, apk package manager"
  echo "     Fastest on 2GB RAM. Recommended for this hardware."
  echo ""
  echo "  2) Debian minimal  — ~300MB, apt package manager"
  echo "     Familiar package manager, heavier than Alpine."
  echo ""
  echo "  3) postmarketOS    — Alpine-based, designed for mobile devices"
  echo "     Best hardware support for MediaTek phones."
  echo "     Requires device-specific port — check: https://postmarketos.org/devices"
  echo ""
  read -rp "Choose [1/2/3]: " CHOICE
}

unlock_bootloader() {
  echo ""
  yellow "Step: Unlocking bootloader..."
  echo "The device will reboot into bootloader mode."
  read -rp "Press Enter to continue (all data will be erased)..."

  adb reboot bootloader
  echo "Waiting for fastboot..."
  fastboot wait-for-device

  fastboot flashing unlock
  echo ""
  yellow "CONFIRM the unlock on-device now (use volume keys + power)."
  read -rp "Press Enter after confirming on device..."

  fastboot reboot
  echo "Waiting for device to boot..."
  adb wait-for-device
  green "Bootloader unlocked."
}

dl_and_flash() {
  local distro="$1"
  local arch
  arch=$(adb shell getprop ro.product.cpu.abi | tr -d '\r')

  echo ""
  echo "Detected CPU ABI: $arch"

  case "$distro" in
    alpine)
      echo ""
      echo "Alpine Linux does not distribute pre-built phone system images."
      echo "The recommended path for this hardware is postmarketOS,"
      echo "which is Alpine-based and targets mobile MediaTek devices."
      echo ""
      echo "Check if your chipset ($SOC_MODEL) has a postmarketOS port:"
      echo "  https://postmarketos.org/devices"
      echo ""
      echo "If no port exists, the Termux/proot path in Path 1 is your"
      echo "best option without a custom port being built."
      ;;
    debian)
      echo ""
      echo "Debian does not distribute images for phones directly."
      echo "A custom port or a Debian-based chroot via Termux is recommended."
      echo ""
      echo "Fastest working Debian-on-phone option:"
      echo "  proot-distro install debian   (inside Termux)"
      ;;
    postmarketos)
      echo ""
      echo "postmarketOS (Alpine-based) is the most complete mobile Linux."
      echo ""
      echo "Steps:"
      echo "  1. Install pmbootstrap on your PC:"
      echo "       pip3 install pmbootstrap"
      echo "  2. Run: pmbootstrap init"
      echo "     Select your device. If 'Artia P600' is not listed,"
      echo "     search by chipset: $SOC_MODEL"
      echo "  3. Run: pmbootstrap install"
      echo "  4. Run: pmbootstrap flasher flash_rootfs"
      echo ""
      echo "postmarketOS device list: https://postmarketos.org/devices"
      echo "New device porting guide:  https://wiki.postmarketos.org/wiki/Porting_to_a_new_device"
      ;;
  esac
}

main() {
  banner
  check_deps
  check_device_connected
  require_chipset_confirmation
  print_flash_options

  case "$CHOICE" in
    1) dl_and_flash alpine ;;
    2) dl_and_flash debian ;;
    3) dl_and_flash postmarketos ;;
    *)
      red "Invalid choice."
      exit 1
      ;;
  esac

  echo ""
  green "Done. Follow the instructions above for your chosen path."
}

main
