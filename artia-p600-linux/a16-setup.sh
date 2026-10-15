#!/data/data/com.termux/files/usr/bin/bash
# a16-setup.sh
# Run this in Termux on your Samsung A16.
# It will install Alpine Linux on the Artia P600 over USB-C OTG automatically.
#
# HOW TO RUN (in A16 Termux):
#   curl -fsSL https://raw.githubusercontent.com/Guffalo/Android-Image-Kitchen/claude/artia-lightweight-linux-7d5qjx/artia-p600-linux/a16-setup.sh | bash

set -euo pipefail

R='\033[0;31m'; G='\033[0;32m'; Y='\033[0;33m'; B='\033[0;34m'; N='\033[0m'
log()  { echo -e "${B}[*]${N} $*"; }
ok()   { echo -e "${G}[+]${N} $*"; }
warn() { echo -e "${Y}[!]${N} $*"; }
die()  { echo -e "${R}[x]${N} $*"; exit 1; }

# ── 1. Storage permission ──────────────────────────────────────────────────
setup_storage() {
  if [ ! -d "$HOME/storage" ]; then
    log "Requesting storage permission..."
    termux-setup-storage
    sleep 3
  fi
  ok "Storage ready."
}

# ── 2. Install ADB on A16 ──────────────────────────────────────────────────
install_adb() {
  if command -v adb &>/dev/null; then
    ok "adb already installed."
    return
  fi
  log "Installing android-tools (adb)..."
  pkg update -y -o Dpkg::Options::='--force-confnew' 2>/dev/null
  pkg install -y android-tools
  ok "adb installed."
}

# ── 3. Wait for P600 to appear over USB OTG ───────────────────────────────
wait_for_p600() {
  log "Waiting for Artia P600 via USB-C..."
  warn "Make sure USB Debugging is ON on the P600 and tap Allow when prompted."
  local attempts=0
  while true; do
    local devices
    devices=$(adb devices 2>/dev/null | grep -v 'List of' | grep -v '^$' || true)
    if echo "$devices" | grep -q 'device$'; then
      ok "P600 connected."
      SERIAL=$(echo "$devices" | grep 'device$' | awk '{print $1}' | head -1)
      ok "Serial: $SERIAL"
      return
    fi
    if echo "$devices" | grep -q 'unauthorized'; then
      warn "Tap ALLOW on the P600 screen now."
    fi
    attempts=$((attempts + 1))
    [ $attempts -ge 60 ] && die "Timed out waiting for device. Check USB debugging is enabled."
    sleep 2
  done
}

# ── 4. Get device arch ────────────────────────────────────────────────────
get_arch() {
  ARCH=$(adb -s "$SERIAL" shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r\n')
  log "P600 CPU ABI: $ARCH"
  case "$ARCH" in
    arm64-v8a) TERMUX_ARCH="arm64-v8a" ;;
    armeabi-v7a|armeabi) TERMUX_ARCH="arm-v7a" ;;
    *) warn "Unknown ABI $ARCH, defaulting to arm64-v8a"; TERMUX_ARCH="arm64-v8a" ;;
  esac
}

# ── 5. Download Termux APK to A16 ─────────────────────────────────────────
download_termux() {
  local APK_PATH="$HOME/storage/downloads/termux-p600.apk"

  if [ -f "$APK_PATH" ]; then
    ok "Termux APK already downloaded."
    TERMUX_APK="$APK_PATH"
    return
  fi

  log "Fetching latest Termux release URL..."
  local RELEASE_JSON
  RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/termux/termux-app/releases/latest")

  local APK_URL
  APK_URL=$(echo "$RELEASE_JSON" \
    | grep browser_download_url \
    | grep "${TERMUX_ARCH}" \
    | grep '\.apk' \
    | grep -v 'bootstraps' \
    | head -1 \
    | cut -d'"' -f4)

  # Fallback to universal APK if arch-specific not found
  if [ -z "$APK_URL" ]; then
    warn "Arch-specific APK not found, trying universal..."
    APK_URL=$(echo "$RELEASE_JSON" \
      | grep browser_download_url \
      | grep 'universal' \
      | grep '\.apk' \
      | head -1 \
      | cut -d'"' -f4)
  fi

  [ -z "$APK_URL" ] && die "Could not find Termux APK URL. Check github.com/termux/termux-app/releases manually."

  log "Downloading Termux from: $APK_URL"
  curl -fL --progress-bar -o "$APK_PATH" "$APK_URL"
  ok "Downloaded: $APK_PATH"
  TERMUX_APK="$APK_PATH"
}

# ── 6. Install Termux onto P600 ───────────────────────────────────────────
install_termux_on_p600() {
  log "Installing Termux on P600..."
  adb -s "$SERIAL" install -r "$TERMUX_APK" \
    && ok "Termux installed on P600." \
    || die "APK install failed. Check if P600 has enough storage."
}

# ── 7. Write the Alpine setup script that will run ON the P600 ────────────
build_p600_script() {
  P600_SCRIPT="$HOME/p600-alpine.sh"
  cat > "$P600_SCRIPT" <<'INNER'
#!/data/data/com.termux/files/usr/bin/bash
# Runs inside Termux on the Artia P600.
set -euo pipefail

pkg update -y -o Dpkg::Options::='--force-confnew' 2>/dev/null
pkg install -y proot-distro

echo "[*] Installing Alpine Linux..."
proot-distro install alpine

# First-boot config inside Alpine
proot-distro login alpine -- sh -c '
  echo "nameserver 8.8.8.8" > /etc/resolv.conf
  apk update
  apk add --no-cache bash shadow openssh nano git python3
  echo "root:alpine" | chpasswd
  echo "[+] Alpine ready. Login: root / alpine"
'

# Add login alias
grep -qF 'alias linux=' ~/.bashrc 2>/dev/null \
  || echo 'alias linux="proot-distro login alpine"' >> ~/.bashrc

echo ""
echo "=== DONE ==="
echo "Type: linux     to enter Alpine any time."
echo "Packages: apk add <name>"
echo ""
INNER
  chmod +x "$P600_SCRIPT"
  ok "P600 setup script written."
}

# ── 8. Push and execute on P600 ───────────────────────────────────────────
run_on_p600() {
  log "Pushing setup script to P600..."
  adb -s "$SERIAL" push "$P600_SCRIPT" /sdcard/p600-alpine.sh

  log "Launching Termux on P600..."
  adb -s "$SERIAL" shell monkey -p com.termux -c android.intent.category.LAUNCHER 1 &>/dev/null || true
  sleep 4

  log "Running Alpine setup on P600 (this takes 2-5 min)..."
  warn "Watch the P600 screen -- it will show install progress."
  adb -s "$SERIAL" shell "run-as com.termux bash /sdcard/p600-alpine.sh" 2>/dev/null \
  || adb -s "$SERIAL" shell "am broadcast -a com.termux.RUN_COMMAND \
       --es com.termux.RUN_COMMAND_PATH '/data/data/com.termux/files/usr/bin/bash' \
       --esa com.termux.RUN_COMMAND_ARGUMENTS '/sdcard/p600-alpine.sh' \
       --ez com.termux.RUN_COMMAND_BACKGROUND 'false'" 2>/dev/null \
  || {
    warn "Auto-launch method failed. Do this manually on P600:"
    warn "Open Termux on P600, then type:"
    warn "  bash /sdcard/p600-alpine.sh"
    warn ""
    warn "Or run from A16's Termux:"
    warn "  adb -s $SERIAL shell"
    warn "  Then inside that shell: bash /sdcard/p600-alpine.sh"
  }
}

# ── Main ──────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${B}╔══════════════════════════════════════╗${N}"
  echo -e "${B}║  A16 → P600  Alpine Linux Installer  ║${N}"
  echo -e "${B}╚══════════════════════════════════════╝${N}"
  echo ""

  setup_storage
  install_adb
  wait_for_p600
  get_arch
  download_termux
  install_termux_on_p600
  build_p600_script
  run_on_p600

  echo ""
  ok "All steps complete."
  echo ""
  echo "To verify Alpine is running on P600, from A16 Termux:"
  echo "  adb -s $SERIAL shell"
  echo "  proot-distro login alpine"
  echo ""
}

main "$@"
