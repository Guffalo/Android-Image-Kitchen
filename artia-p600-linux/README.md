# Lightweight Linux on the ANS Artia P600

**Device:** ANS Artia P600 | Quad-Core MediaTek ~1.5 GHz | 2 GB RAM | 32 GB storage | Android 11 Go

Two paths. Pick one based on how far you want to go.

---

## Path 1 — Termux + Alpine (Fastest, Zero Flash Risk)

Works today. No bootloader flash. No brick risk. Gets you a real Linux shell with APK package manager in under 5 minutes.

### Steps

1. **Install Termux from F-Droid** (NOT the Play Store version — it's outdated)
   - https://f-droid.org → search Termux → install

2. **Run the setup script inside Termux:**
   ```sh
   curl -fsSL https://raw.githubusercontent.com/Guffalo/Android-Image-Kitchen/claude/artia-lightweight-linux-7d5qjx/artia-p600-linux/termux-alpine-setup.sh | sh
   ```

3. **Start Alpine any time:**
   ```sh
   proot-distro login alpine
   ```

### What you get
- Alpine Linux (ARM) inside a proot container
- `apk` package manager (fast, ~130 MB base)
- Full bash shell, gcc, python3, git — whatever you `apk add`
- Persistent across reboots
- **Ubuntu variant:** swap `alpine` for `ubuntu` in the script if you prefer APT

---

## Path 2 — Full Bootloader Unlock + Flash (Replaces Android)

This installs Linux as the actual OS. Requires a PC with ADB/fastboot.

> **Warning:** This erases everything on the device.

### Prerequisites
- PC with `adb` and `fastboot` installed
- Artia P600 with OEM unlock already enabled (you confirmed this)
- USB-C cable

### Steps

1. **Detect your exact chipset first** (required — exact MediaTek model is not publicly listed):
   ```sh
   bash artia-p600-linux/detect-device.sh
   ```
   This prints the SoC model, architecture, and kernel version.

2. **Unlock the bootloader via fastboot:**
   ```sh
   adb reboot bootloader
   fastboot flashing unlock
   # Confirm on-device prompt, then:
   fastboot reboot
   ```

3. **Flash Alpine Linux** (after chipset is confirmed):
   ```sh
   bash artia-p600-linux/flash-linux.sh
   ```

---

## Why Alpine and Not Ubuntu?

| Distro | RAM needed | Base size | Speed on 2GB RAM |
|--------|-----------|-----------|------------------|
| Alpine | ~80 MB | ~130 MB | Very fast |
| Debian minimal | ~150 MB | ~300 MB | Fast |
| Ubuntu minimal | ~400 MB | ~500 MB | Slow on this HW |

Alpine with `apk add` gives you anything Ubuntu gives you. Same packages, different package manager.

---

## Sources
- [ANS Artia P600 retail specs](https://vipoutlet.com/products/ans-ans-artia-p600-6-0-4g-lte-2-gb-ram-32-gb-storage-1-5-ghz-processor-android-smartphone-black)
- [proot-distro project](https://github.com/termux/proot-distro)
- [F-Droid / Termux](https://f-droid.org)
