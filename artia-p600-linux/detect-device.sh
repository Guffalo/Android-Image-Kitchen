#!/usr/bin/env bash
# detect-device.sh — Reads hardware info from Artia P600 via ADB.
# Run from a PC with adb in PATH and the device connected via USB.
# Output is used to confirm the chipset before flashing.

set -euo pipefail

check_adb() {
  if ! command -v adb &>/dev/null; then
    echo "ERROR: adb not found in PATH."
    echo "Install Android Platform Tools: https://developer.android.com/tools/releases/platform-tools"
    exit 1
  fi
}

wait_for_device() {
  echo "Waiting for device..."
  adb wait-for-device
  echo "Device found."
}

print_prop() {
  local label="$1"
  local prop="$2"
  local value
  value=$(adb shell getprop "$prop" 2>/dev/null | tr -d '\r')
  printf "  %-30s %s\n" "$label" "${value:-<not set>}"
}

main() {
  check_adb
  wait_for_device

  echo ""
  echo "=== Artia P600 Device Report ==="
  echo ""
  echo "--- Identity ---"
  print_prop "Brand"              "ro.product.brand"
  print_prop "Model"              "ro.product.model"
  print_prop "Device codename"    "ro.product.device"
  print_prop "Board"              "ro.product.board"

  echo ""
  echo "--- Chipset / Hardware ---"
  print_prop "Hardware"           "ro.hardware"
  print_prop "SoC model"          "ro.soc.model"
  print_prop "SoC manufacturer"   "ro.soc.manufacturer"
  print_prop "CPU ABI (primary)"  "ro.product.cpu.abi"
  print_prop "CPU ABIlist"        "ro.product.cpu.abilist"
  print_prop "CPU ABIlist 32"     "ro.product.cpu.abilist32"
  print_prop "CPU ABIlist 64"     "ro.product.cpu.abilist64"

  echo ""
  echo "--- Software ---"
  print_prop "Android version"    "ro.build.version.release"
  print_prop "Build fingerprint"  "ro.build.fingerprint"
  print_prop "Kernel version"     "ro.build.version.kernel"
  print_prop "Security patch"     "ro.build.version.security_patch"
  print_prop "OEM unlock allowed" "ro.oem_unlock_supported"

  echo ""
  echo "--- Storage / Memory ---"
  echo "  RAM:"
  adb shell cat /proc/meminfo 2>/dev/null | grep MemTotal | awk '{printf "    Total: %s %s\n", $2, $3}'
  echo "  Disk:"
  adb shell df -h /data 2>/dev/null | tail -1 | awk '{printf "    /data: %s total, %s free\n", $2, $4}'

  echo ""
  echo "--- CPU Details ---"
  adb shell cat /proc/cpuinfo 2>/dev/null | grep -E 'Hardware|processor|model name|CPU implementer|CPU part' | sort -u

  echo ""
  echo "=== End Report ==="
  echo ""
  echo "NEXT STEP: Copy the 'Hardware' and 'SoC model' lines above."
  echo "Then run: bash artia-p600-linux/flash-linux.sh"
  echo "The flash script will prompt you to confirm the chipset."
}

main
