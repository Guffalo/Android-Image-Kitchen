#!/data/data/com.termux/files/usr/bin/sh
# termux-ubuntu-setup.sh
# Run this INSIDE Termux on the Artia P600.
# Installs Ubuntu 24.04 minimal via proot-distro.
# Heavier than Alpine (~500MB) but uses familiar APT.

set -e

echo ""
echo "=== Artia P600 — Ubuntu Minimal Setup ==="
echo "This needs ~500MB free and is slower than Alpine on 2GB RAM."
echo ""

pkg update -y
pkg install -y proot-distro

echo "Downloading Ubuntu (ARM)..."
proot-distro install ubuntu

LAUNCH_LINE='alias ubuntu="proot-distro login ubuntu"'
if ! grep -qF "$LAUNCH_LINE" ~/.bashrc 2>/dev/null; then
  echo "" >> ~/.bashrc
  echo "# Artia P600 Ubuntu" >> ~/.bashrc
  echo "$LAUNCH_LINE" >> ~/.bashrc
fi

echo ""
echo "=== Done ==="
echo ""
echo "Start Ubuntu: proot-distro login ubuntu"
echo "Or type:      ubuntu    (after restarting Termux)"
echo ""
echo "First commands inside Ubuntu:"
echo "  apt update && apt upgrade -y"
echo "  apt install -y git python3 pip nano openssh-client build-essential"
echo ""
