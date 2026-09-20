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
./iphone.sh          # interactive menu
./iphone.sh check    # utilities, USB, tunnel, SSH, device status
./iphone.sh reapply  # re-apply bypass (after restore / erased flags)
./iphone.sh zebra    # install Zebra if missing
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
| `iphone.sh` | Main helper: menu + CLI (`check` / `reapply` / `zebra`) |
| `mobileactivationd` | Patched activation daemon (sha1 `178235dbce7c9e73fa01d138d0e83339d9455031`) |
| `com.apple.purplebuddy.plist` | "Setup complete" flags (`ForceNoBuddy`, `SetupDone`, ...) |
| `com.apple.springboard.plist` | Disable auto-lock (handy while working) |
| `askpass.sh` | SSH password helper |
| `zebra_stage/` + `zebra_1.1.36_arm.deb` | Zebra manual-install payload |

## Gotchas

- **Tethered jailbreak**: every reboot needs checkra1n again (rootfs patch itself survives).
- If the setup screen appears after a reboot: `./iphone.sh reapply`.
- App Store may ask for an Apple ID — a new account works, iCloud sign-in does not.