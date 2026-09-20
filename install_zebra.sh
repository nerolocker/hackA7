#!/bin/bash
# Ручная установка Zebra 1.1.36 (iphoneos-arm) на iPhone 5s / checkra1n iOS 12.5.8.
#
# Почему вручную: dpkg-deb на устройстве экстрактит deb через старый системный
# tar (apple-bsdtar), который не понимает ни `--warning=no-timestamp`, ни lzma
# (data.tar.lzma внутри deb) -> `dpkg -i` падает. Поэтому файлы раскладываются
# напрямую, а пакет регистрируется в базе dpkg вручную.
#
# Использование: телефон подключён по USB, OpenSSH включён, iproxy 2222 44 запущен
#   ./install_zebra.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
STAGE="$HERE/zebra_stage"
PORT=2222

export SSH_ASKPASS="$HERE/askpass.sh" SSH_ASKPASS_REQUIRE=force DISPLAY=:0
SSHOPT="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa -o KexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -o Ciphers=+aes128-cbc,aes256-cbc,3des-cbc -o ConnectTimeout=6"
ssh_r() { setsid ssh $SSHOPT -p "$PORT" root@127.0.0.1 "$@"; }

echo "[1/7] Проверка SSH..."
if ! ssh_r 'echo SSH_OK' >/dev/null 2>&1; then
  echo "Проблема: SSH не отвечает. Телефон подключён по USB? OpenSSH в выключен? iproxy запущен?"
  exit 1
fi
[ -d "$STAGE/Applications" ] || { echo "Нет стадии $STAGE (запускать из ~/iphone5s_bypass)"; exit 1; }

echo "[2/7] Проверка, не установлена ли уже..."
if ssh_r 'dpkg -s xyz.willy.zebra 2>/dev/null | grep -q "install ok installed"'; then
  echo "Zebra уже установлена — просто обновляю иконки."
  ssh_r '/usr/bin/uicache -a >/dev/null 2>&1; killall SpringBoard' >/dev/null 2>&1
  echo "Готово."
  exit 0
fi

echo "[3/7] Бэкап dpkg status..."
ssh_r 'cp /var/lib/dpkg/status /var/lib/dpkg/status.bak && echo ok' || { echo "Не удалось"; exit 1; }

echo "[4/7] Заливка Zebra.app на устройство (rootfs)..."
( cd "$STAGE" && tar --no-xattrs -cf - . ) | \
  ssh_r 'cd / && tar -xf -' 2>&1 | grep -v 'Warning:' | grep -vE '^$' || true
ssh_r 'ls -d /Applications/Zebra.app >/dev/null 2>&1 && echo "app на месте"' || { echo "Zebra.app не появился"; exit 1; }

echo "[5/7] Регистрация в dpkg..."
# список файлов для dpkg (каталоги — с завершающим слэшем)
( cd "$STAGE" && find . -mindepth 1 | while read -r p; do
    q="${p#./}"
    if [ -d "$p" ]; then echo "/$q/"; else echo "/$q"; fi
  done
) | ssh_r 'cat > /var/lib/dpkg/info/xyz.willy.zebra.list' || { echo "list не ушёл"; exit 1; }

# postinst-бинарь — в info-папку dpkg
ssh_r 'cat > /var/lib/dpkg/info/xyz.willy.zebra.postinst; chmod 755 /var/lib/dpkg/info/xyz.willy.zebra.postinst' < "$STAGE/postinst_bin" \
  || { echo "postinst не ушёл"; exit 1; }

# запись в status-базу (пропустить, если уже есть)
if ssh_r 'grep -q "^Package: xyz.willy.zebra$" /var/lib/dpkg/status'; then
  echo "Запись в status уже есть — пропускаю."
else
  ssh_r 'printf "\n" >> /var/lib/dpkg/status; cat >> /var/lib/dpkg/status' <<'EOF'
Package: xyz.willy.zebra
Status: install ok installed
Priority: Optional
Section: Packaging
Installed-Size: 15032
Maintainer: Zebra Team <team@getzbra.com>
Architecture: iphoneos-arm
Version: 1.1.36
Depends: dpkg, uikittools, firmware (>= 9.0)
Description: A Useful Package Manager
Name: Zebra
Author: Zebra Team <team@getzbra.com>
Tag: compatible::9.0-16.6
EOF
fi

# репозиторий Zebra для обновлений (увидит и Cydia, и Zebra)
ssh_r 'printf "deb http://getzbra.com/repo/ ./\n" > /etc/apt/sources.list.d/zebra.list; echo "репо добавлен"' >/dev/null 2>&1 || true

echo "[6/7] postinst configure + проверка..."
ssh_r '/var/lib/dpkg/info/xyz.willy.zebra.postinst configure' || echo "  (postinst exit=$?)"
ssh_r 'dpkg -s xyz.willy.zebra 2>/dev/null | grep -E "^Status|^Version"'

echo "[7/7] Обновление иконок и респринг..."
ssh_r '/usr/bin/uicache -a 2>&1 | tail -2' 2>&1 | grep -v 'Warning:'
echo "Респринг..."
ssh_r 'killall SpringBoard' >/dev/null 2>&1 || true
echo "Готово! Иконка Zebra на рабочем столе."
echo "(бэкап status: /var/lib/dpkg/status.bak)"