#!/bin/bash
# ============================================================================
# iphone.sh — helper for iPhone 5s / checkra1n / iOS 12.5.8 (macOS + Linux)
#
# Interactive menu (no args) and CLI subcommands:
#   ./iphone.sh menu     interactive menu
#   ./iphone.sh check    check utilities, USB, tunnel, SSH, device status
#   ./iphone.sh reapply  re-apply bypass (after reboot / re-restore)
#   ./iphone.sh zebra    install Zebra (if missing after restore)
#   ./iphone.sh help     usage
#
# Prerequisites: phone jailbroken via checkra1n (SSH on port 44) and plugged
# in via USB. SSH password comes from askpass.sh (alpine).
# ============================================================================
set -u
set -o pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=2222
DEVPORT=44
OS="$(uname -s 2>/dev/null || echo unknown)"

export SSH_ASKPASS_REQUIRE=force
export SSH_ASKPASS="$DIR/askpass.sh"
export DISPLAY=:0

# ---------- output helpers ----------
ok()   { echo "  [OK]   $*"; }
info() { echo "  [..]   $*"; }
warn() { echo "  [WARN] $*"; }
fail() { echo "  [FAIL] $*"; exit 1; }
sep()  { printf '%s\n' "────────────────────────────────────────────"; }

# ---------- find ssh (on macOS prefer homebrew openssh) ----------
SSH_BIN="$(command -v ssh 2>/dev/null)"
if [ "$OS" = "Darwin" ]; then
  for p in /opt/homebrew/opt/openssh/bin/ssh /usr/local/opt/openssh/bin/ssh; do
    [ -x "$p" ] && SSH_BIN="$p" && break
  done
fi
[ -n "$SSH_BIN" ] || fail "ssh not found (install OpenSSH: brew install openssh / apt install openssh-client)"

SSHOPTS=(
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o HostKeyAlgorithms=+ssh-rsa
  -o PubkeyAcceptedAlgorithms=+ssh-rsa
  -o KexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1
  -o Ciphers=+aes128-cbc,aes256-cbc,3des-cbc
  -o ConnectTimeout=8
  -p "$PORT"
  root@127.0.0.1
)

# ssh wrapper (no tty: password via SSH_ASKPASS; filter ssh noise)
ssh_r() {
  "$SSH_BIN" -n "${SSHOPTS[@]}" "$@" 2>&1 | grep -v 'Permanently added'
}

# ---------- host utility checks ----------
check_utils() {
  sep
  info "OS: $OS"
  info "ssh: $SSH_BIN"
  for tool in ssh iproxy; do
    if command -v "$tool" >/dev/null 2>&1; then
      ok "$tool found ($(command -v "$tool"))"
    else
      fail "utility '$tool' not found. Install: macOS → brew install libimobiledevice; Linux → apt install libimobiledevice-utils usbmuxd"
    fi
  done
  if [ -s "$DIR/askpass.sh" ]; then
    ok "askpass.sh present"
  else
    printf '#!/bin/sh\necho alpine\n' > "$DIR/askpass.sh"
    chmod 700 "$DIR/askpass.sh"
    ok "askpass.sh created"
  fi
}

# ---------- USB detection (macOS / Linux) ----------
usb_present() {
  if [ "$OS" = "Darwin" ]; then
    system_profiler SPUSBDataType 2>/dev/null | grep -qi 'apple'
  else
    lsusb 2>/dev/null | grep -qi 'apple'
  fi
}

# ---------- iproxy tunnel ----------
iproxy_running() { command -v pgrep >/dev/null 2>&1 && pgrep -f "^iproxy $PORT $DEVPORT" >/dev/null 2>&1; }

start_iproxy() {
  if iproxy_running; then
    ok "iproxy already running ($(pgrep -f "^iproxy $PORT $DEVPORT" | head -1))"
  else
    (nohup iproxy "$PORT" "$DEVPORT" >"${TMPDIR:-/tmp}/iproxy.log" 2>&1 &)
    sleep 2
    if iproxy_running; then
      ok "iproxy started ($PORT -> device:$DEVPORT)"
    else
      warn "iproxy failed to start (log: ${TMPDIR:-/tmp}/iproxy.log)"
    fi
  fi
}

# ---------- device diagnostics ----------
device_status() {
  sep
  info "Device status:"
  if ssh_r "echo __SSH_OK" >/dev/null 2>&1; then
    ok "SSH alive"
  else
    fail "SSH is dead. Phone plugged in? Charged? OpenSSH enabled? iproxy running?"
  fi

  if ssh_r 'ps aux | grep -E "Setup.app" | grep -v grep >/dev/null && echo SETUP_RUNNING || echo SETUP_GONE' | grep -q SETUP_RUNNING; then
    warn "Setup.app is RUNNING (run: ./iphone.sh reapply)"
  else
    ok "Setup not running — home screen"
  fi

  sb_pid=$(ssh_r 'ps aux | grep "SpringBoard.app/SpringBoard" | grep -v grep' | awk '{print $2}' | head -1)
  [ -n "$sb_pid" ] && ok "SpringBoard alive (PID $sb_pid)"

  daemon=$(ssh_r 'ps aux | grep mobileactivationd | grep -v grep' | awk '{print $2}' | head -1)
  [ -n "$daemon" ] && ok "mobileactivationd alive (PID $daemon)" || warn "mobileactivationd not found"

  if ssh_r 'dpkg -s xyz.willy.zebra 2>/dev/null | grep -q "install ok installed" && echo ZEBRA_YES' | grep -q ZEBRA_YES; then
    ok "Zebra installed"
  else
    info "Zebra not installed (./iphone.sh zebra)"
  fi
}

# ============================================================================
# reapply — re-apply the bypass
# ============================================================================
do_reapply() {
  sep
  info "Re-applying bypass (daemon patch + flags + respring)..."
  [ -s "$DIR/mobileactivationd" ] || fail "file $DIR/mobileactivationd missing"
  ssh_r "echo __SSH_OK" >/dev/null 2>&1 || fail "SSH is dead — need checkra1n + iproxy"

  info "[1/4] Remount rootfs RW"
  ssh_r "mount -o rw,union,update /" >/dev/null 2>&1 || true

  info "[2/4] Install patched mobileactivationd"
  ssh_r "launchctl unload /System/Library/LaunchDaemons/com.apple.mobileactivationd.plist >/dev/null 2>&1; rm -f /usr/libexec/mobileactivationd" >/dev/null
  cat "$DIR/mobileactivationd" | ssh_r "cat > /usr/libexec/mobileactivationd" >/dev/null
  ssh_r "chmod 755 /usr/libexec/mobileactivationd && launchctl load /System/Library/LaunchDaemons/com.apple.mobileactivationd.plist" >/dev/null

  info "[3/4] purplebuddy + springboard flags"
  ssh_r "killall cfprefsd >/dev/null 2>&1; chflags nouchg /var/mobile/Library/Preferences/com.apple.purplebuddy.plist >/dev/null 2>&1" || true
  cat "$DIR/com.apple.purplebuddy.plist" | ssh_r "cat > /var/mobile/Library/Preferences/com.apple.purplebuddy.plist; chown mobile:mobile /var/mobile/Library/Preferences/com.apple.purplebuddy.plist; chmod 600 /var/mobile/Library/Preferences/com.apple.purplebuddy.plist" >/dev/null
  cat "$DIR/com.apple.springboard.plist" | ssh_r "cat > /var/mobile/Library/Preferences/com.apple.springboard.plist; chown mobile:mobile /var/mobile/Library/Preferences/com.apple.springboard.plist; chmod 600 /var/mobile/Library/Preferences/com.apple.springboard.plist" >/dev/null

  info "[4/4] Respring"
  ssh_r "killall Setup >/dev/null 2>&1; sleep 1; killall -9 SpringBoard" >/dev/null 2>&1 || true

  ok "Done. Home screen appears in ~10-15 sec (verify: ./iphone.sh check)."
}

print_help() {
  cat <<'HELP'
iphone.sh — helper for iPhone 5s / checkra1n / iOS 12.5.8 (macOS + Linux)

  ./iphone.sh            interactive menu
  ./iphone.sh check      check utilities, USB, tunnel, SSH, device status
  ./iphone.sh reapply    re-apply bypass (daemon patch + flags + respring)
  ./iphone.sh help       this help

Host requirements:
  macOS: brew install libimobiledevice openssh
  Linux: apt install libimobiledevice-utils usbmuxd openssh-client

Before running: phone jailbroken via checkra1n and plugged in via USB.
HELP
}

# ============================================================================
# interactive menu
# ============================================================================
do_menu() {
  while true; do
    printf '%s\n' \
      "=============================================" \
      " iPhone 5s / checkra1n / iOS 12.5.8 helper" \
      "=============================================" \
      "" \
      " 1) Check system (utilities, USB, tunnel, SSH, status)" \
      " 2) Re-apply bypass (after reboot / re-restore)" \
      " 4) Show help" \
      " 0) Exit" \
      "" \
      "Your choice: "
    read -r choice
    case "$choice" in
      1) check_utils; usb_present && ok "iPhone visible via USB" || warn "iPhone NOT visible via USB"; start_iproxy; device_status ;;
      2) check_utils; start_iproxy; do_reapply ;;
      4) print_help ;;
      0) info "Bye."; exit 0 ;;
      *) warn "Unknown choice: $choice" ;;
    esac
    sep
    printf '%s\n' "Press Enter to return to the menu..."
    read -r _
  done
}

# ============================================================================
cmd="${1:-}"
case "$cmd" in
  ""|menu)  do_menu ;;
  check)    check_utils; usb_present && ok "iPhone visible via USB" || warn "iPhone NOT visible via USB"; start_iproxy; device_status ;;
  reapply)  check_utils; start_iproxy; do_reapply ;;
  zebra)    check_utils; start_iproxy; do_zebra ;;
  help|-h|--help) print_help ;;
  *)        echo "Unknown command: $cmd"; print_help; exit 1 ;;
esac
