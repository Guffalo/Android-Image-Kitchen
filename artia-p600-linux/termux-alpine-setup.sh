#!/data/data/com.termux/files/usr/bin/sh
# termux-alpine-setup.sh
# Run this INSIDE Termux on the Artia P600.
# Installs proot-distro and boots Alpine Linux (ARM).
# Alpine = ~130MB base, very fast on 2GB RAM.

set -e

echo ""
echo "=== Artia P600 — Lightweight Linux Setup ==="
echo "Target: Alpine Linux via proot-distro"
echo ""

# Update Termux packages
echo "[1/4] Updating Termux package list..."
pkg update -y

# Install proot-distro
echo "[2/4] Installing proot-distro..."
pkg install -y proot-distro

# Install Alpine (ARM, ~130MB)
echo "[3/4] Downloading Alpine Linux (ARM)..."
echo "This is the smallest option — about 130MB."
proot-distro install alpine

# Write a launch alias into .bashrc
echo "[4/4] Creating 'linux' shortcut..."
LAUNCH_LINE='alias linux="proot-distro login alpine"'
if ! grep -qF "$LAUNCH_LINE" ~/.bashrc 2>/dev/null; then
  echo "" >> ~/.bashrc
  echo "# Artia P600 lightweight Linux" >> ~/.bashrc
  echo "$LAUNCH_LINE" >> ~/.bashrc
fi

echo ""
echo "=== Done ==="
echo ""
echo "Run Alpine now:   proot-distro login alpine"
echo "Or just type:     linux    (after restarting Termux)"
echo ""
echo "Inside Alpine, useful first commands:"
echo "  apk update && apk upgrade"
echo "  apk add bash git python3 nano openssh"
echo "  apk add build-base    # gcc, make, etc."
echo ""
echo "To install Ubuntu instead, run:"
echo "  proot-distro install ubuntu && proot-distro login ubuntu"
echo ""
