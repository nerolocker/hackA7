#!/bin/bash
# ============================================================
# iPhone 5s (iOS 12.5.8 / 16H88) — повторное применение байпаса
# После КАЖДОЙ перезагрузки телефона (джейл тетhered, он слетает).
#
# Требуется:
#   1) Снова заджейлбрейкать телефон через checkra1n (порт 44 SSH)
#   2) Запустить iproxy:  iproxy 2222 44   (держать открытым)
#   3) Запустить этот скрипт на хосте:  ./reapply_bypass.sh
#
# Через ~10-15 секунд после финиша у телефона должен появиться
# рабочий стол без экрана настройки.
# ============================================================
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

export SSH_ASKPASS_REQUIRE=force
export SSH_ASKPASS="$DIR/askpass.sh"
export DISPLAY=:0

S() {
  setsid ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa \
    -o KexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 \
    -o Ciphers=+aes128-cbc,aes256-cbc,3des-cbc -o ConnectTimeout=8 \
    -p 2222 root@127.0.0.1 "$@"
}

echo "[1/5] Ремаунт rootfs в RW..."
S "mount -o rw,union,update /"

echo "[2/5] Удаляю стоковый mobileactivationd и регистрирую демон..."
S "launchctl unload /System/Library/LaunchDaemons/com.apple.mobileactivationd.plist 2>/dev/null; rm -f /usr/libexec/mobileactivationd"
cat "$DIR/mobileactivationd" | S "cat > /usr/libexec/mobileactivationd"
S "chmod 755 /usr/libexec/mobileactivationd && launchctl load /System/Library/LaunchDaemons/com.apple.mobileactivationd.plist"

echo "[3/5] Обновляю флаги обхода Setup (purplebuddy)..."
S "killall cfprefsd 2>/dev/null || true; chflags nouchg /var/mobile/Library/Preferences/com.apple.purplebuddy.plist 2>/dev/null || true"
cat "$DIR/com.apple.purplebuddy.plist" | S "cat > /var/mobile/Library/Preferences/com.apple.purplebuddy.plist; chown mobile:mobile /var/mobile/Library/Preferences/com.apple.purplebuddy.plist; chmod 600 /var/mobile/Library/Preferences/com.apple.purplebuddy.plist"
cat "$DIR/com.apple.springboard.plist" | S "cat > /var/mobile/Library/Preferences/com.apple.springboard.plist; chown mobile:mobile /var/mobile/Library/Preferences/com.apple.springboard.plist 2>/dev/null; chmod 600 /var/mobile/Library/Preferences/com.apple.springboard.plist 2>/dev/null"

echo "[4/5] Убиваю Setup и респринжю SpringBoard..."
S "killall Setup 2>/dev/null || true; sleep 1; killall -9 SpringBoard"

echo "[5/5] Готово. Через ~10-15 сек должен появиться рабочий стол."
echo "(Проверка: ps aux | grep Setup.app  — пусто)"