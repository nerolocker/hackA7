# iPhone 5s Bypass Helper

Tools for an Activation-Locked iPhone 5s (iOS 12.5.8, build 16H88) jailbroken
with **checkra1n** (rootful). Works from **macOS and Linux**.

> Device: iPhone6,1 (5s GSM), UDID `a35725664652e06f4d285c3b36d5631ca72c9d48`

## What works

- Home screen, WiFi, cellular + LTE (patched activation daemon returns FactoryActivated)
- On iOS 12, writes to the rootfs **survive reboots** — after a reboot you only have
  to run checkra1n again, no re-apply needed (re-apply is only required after an
  iTunes restore / Erase).
- Not working: iCloud (needs the original Apple ID password), Find My by software.

## Usage

```bash
./hacka7.sh          # interactive menu
./hacka7.sh check    # utilities, USB, tunnel, SSH, device + activation status
./hacka7.sh wait     # wait for iPhone to connect (USB + iproxy + SSH)
./hacka7.sh reapply  # re-apply bypass (after restore / erased flags)
./hacka7.sh kill     # kill stale iproxy/usbmuxd helpers (cleanup)
```

Before running: phone jailbroken via checkra1n (SSH on port 44) and plugged in
via USB. SSH password comes from `askpass.sh` (default: `alpine`).

Install host tools:

```bash
# macOS
brew install libimobiledevice openssh
# Linux
apt install libimobiledevice-utils usbmuxd openssh-client
```

## Files

| File | Purpose |
|---|---|
| `hacka7.sh` | Main helper: menu + CLI (`check` / `wait` / `reapply` / `kill`) |
| `mobileactivationd` | Patched activation daemon (sha1 `178235dbce7c9e73fa01d138d0e83339d9455031`) |
| `com.apple.purplebuddy.plist` | "Setup complete" flags (`ForceNoBuddy`, `SetupDone`, ...) |
| `com.apple.springboard.plist` | Disable auto-lock (handy while working) |
| `askpass.sh` | SSH password helper |

## Gotchas

- **Tethered jailbreak**: every reboot needs checkra1n again (rootfs patch itself survives).
- If the setup screen appears after a reboot: `./hacka7.sh reapply`.
- App Store may ask for an Apple ID — a new account works, iCloud sign-in does not.
- On macOS, device detection uses `ioreg`; on Linux it uses `idevice_id` (falls back to `lsusb`).
- `iproxy` is auto-detected from PATH or common Homebrew locations (`/opt/homebrew/bin`, `/usr/local/bin`).
