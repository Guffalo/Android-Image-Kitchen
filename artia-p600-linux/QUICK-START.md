# Quick Start — Artia P600 Full Linux Flash

Device is sacrificial. No warnings. Go fast.

## What you need

- PC running Linux or WSL2 (Windows)
- USB-C cable
- Python 3 + pip

---

## Step 1 — Install tools (30 seconds)

```sh
pip3 install mtkclient
```

## Step 2 — Put device in BROM mode

1. **Power the Artia P600 completely OFF**
2. Hold **Volume Up** and plug in USB-C to PC
3. The device screen stays black — that's correct

## Step 3 — Run the flash script

```sh
bash artia-p600-linux/flash-linux-full.sh
```

That's it. The script:
- Auto-detects the MediaTek chipset via BROM
- Downloads Alpine Linux ARM (130MB)
- Builds and flashes the rootfs
- No prompts, no gates

---

## After flash — access Alpine

```sh
adb shell
chroot /data/alpine /bin/sh
apk update && apk upgrade
apk add bash git python3 openssh nano
```

## Want full native boot (replaces Android kernel)?

```sh
pip3 install pmbootstrap
pmbootstrap init
# Select your SoC when prompted (script will have printed it)
pmbootstrap install
pmbootstrap flasher flash_rootfs
pmbootstrap flasher flash_kernel
```

---

## WSL2 users — USB forwarding

```sh
# On Windows (admin PowerShell):
winget install usbipd
usbipd list                    # find the P600
usbipd bind --busid <busid>
usbipd attach --wsl --busid <busid>
# Then run flash script inside WSL2
```
