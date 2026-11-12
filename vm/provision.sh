#!/bin/bash

set -u
export DEBIAN_FRONTEND=noninteractive
export HOME=/root
umask 022

TB_KEY_FPR="EF6E286DDA85EA2A4BA7DE684E2C6E8793298290"
TB_KEY_URL="https://openpgpkey.torproject.org/.well-known/openpgpkey/torproject.org/hu/kounek7zrdx745qydx6p59t9mqjpuhdf"
TB_RELEASES_URL="https://aus1.torproject.org/torbrowser/update_3/release/downloads.json"
VM_USER="user"
WORK="/root/opsec-setup"

console() {
  local dev
  for dev in /dev/ttyAMA0 /dev/ttyS0; do
    if [ -c "$dev" ]; then
      printf '%s\n' "$*" >"$dev" 2>/dev/null
    fi
  done
  return 0
}

say() { console "OPSEC: $*"; }

die() {
  say "FAILED: $*"
  console "OPSEC-RESULT: failed"
  sync
  systemctl poweroff
  exit 1
}

apt_install() {
  apt-get -y \
    -o DPkg::Lock::Timeout=300 \
    -o Acquire::Retries=8 \
    -o Acquire::http::Timeout=90 \
    -o Acquire::https::Timeout=90 \
    -o Dpkg::Options::=--force-confold \
    install --no-install-recommends "$@"
}

apt_refresh() {
  local try=0
  while [ "$try" -lt 5 ]; do
    apt-get -o DPkg::Lock::Timeout=300 -o Acquire::Retries=8 update && return 0
    try=$((try + 1))
    sleep 10
  done
  return 1
}

write_sources() {
  local scheme="$1" codename
  codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  rm -f /etc/apt/sources.list /etc/apt/sources.list.d/*
  cat >/etc/apt/sources.list.d/debian.sources <<EOF
Types: deb
URIs: $scheme://deb.debian.org/debian
Suites: $codename $codename-updates
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: $scheme://deb.debian.org/debian-security
Suites: $codename-security
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
}

tcurl() {
  curl --socks5-hostname 127.0.0.1:9050 --retry 5 --retry-delay 5 -fsSL "$@"
}

tfetch() {
  local out="$1" url="$2" try=0
  rm -f "$out"
  while [ "$try" -lt 20 ]; do
    if curl --socks5-hostname 127.0.0.1:9050 -fsSL -C - -o "$out" "$url"; then
      return 0
    fi
    try=$((try + 1))
    sleep 5
  done
  return 1
}

tor_ready() {
  local try=0
  while [ "$try" -lt 36 ]; do
    if tcurl -m 20 https://check.torproject.org/api/ip 2>/dev/null | grep -q '"IsTor":true'; then
      return 0
    fi
    try=$((try + 1))
    sleep 5
  done
  return 1
}

bootstrap_packages() {
  say "1/8 Getting Tor and the firewall over an encrypted connection"
  systemctl stop apt-daily.timer apt-daily-upgrade.timer unattended-upgrades.service >/dev/null 2>&1
  write_sources https
  apt_refresh || die "could not reach the Debian package servers"
  apt_install tor nftables apt-transport-tor curl ca-certificates || die "could not install Tor and the firewall"
}

lock_network() {
  say "2/8 Locking the network so that only Tor can leave this machine"
  local tor_uid
  tor_uid="$(id -u debian-tor)" || die "the Tor service account is missing"

  cat >/etc/tor/torrc <<'EOF'
SocksPort 127.0.0.1:9050
SocksPort 127.0.0.1:9150
ClientOnly 1
AvoidDiskWrites 1
EOF

  cat >/etc/nftables.conf <<EOF
flush ruleset

table inet opsec {
  chain input {
    type filter hook input priority 0; policy drop;
    iifname "lo" accept
    ct state established,related accept
    udp sport 67 udp dport 68 accept
  }

  chain forward {
    type filter hook forward priority 0; policy drop;
  }

  chain output {
    type filter hook output priority 0; policy drop;
    oifname "lo" accept
    ct state established,related accept
    meta skuid $tor_uid meta l4proto tcp accept
    udp sport 68 udp dport 67 accept
  }
}
EOF

  cat >/etc/sysctl.d/60-opsec.conf <<'EOF'
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv4.tcp_timestamps=0
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.all.accept_source_route=0
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
kernel.unprivileged_bpf_disabled=1
kernel.yama.ptrace_scope=2
kernel.kexec_load_disabled=1
kernel.core_pattern=|/bin/false
net.core.bpf_jit_harden=2
fs.protected_symlinks=1
fs.protected_hardlinks=1
fs.protected_fifos=2
fs.protected_regular=2
fs.suid_dumpable=0
EOF
  sysctl --system >/dev/null 2>&1

  systemctl enable nftables.service >/dev/null 2>&1 || die "could not enable the firewall"
  nft -f /etc/nftables.conf || die "could not load the firewall rules"
  systemctl disable --now systemd-timesyncd.service >/dev/null 2>&1
  systemctl restart tor.service || die "could not restart Tor"

  tor_ready || die "Tor could not connect. If Tor is blocked on this network, connect the VPN on the host first."
  write_sources tor+https
  apt_refresh || die "could not reach the Debian package servers through Tor"
}

install_desktop() {
  say "3/8 Installing the desktop through Tor. This is the slow part"
  apt_install \
    xserver-xorg-core xserver-xorg-input-libinput xinit x11-xserver-utils \
    lightdm lightdm-gtk-greeter \
    xfce4-session xfwm4 xfce4-panel xfdesktop4 xfce4-settings xfce4-terminal thunar \
    dbus-x11 dbus-user-session libpam-systemd polkitd \
    adwaita-icon-theme fonts-dejavu-core fonts-liberation \
    libgtk-3-0t64 libdbus-glib-1-2 libxt6t64 libasound2t64 libx11-xcb1 \
    gnupg xz-utils mat2 unattended-upgrades util-linux-extra ||
    die "could not install the desktop"
}

install_tor_browser() {
  say "4/8 Downloading Tor Browser through Tor and checking its signature"
  local key urls binary sig status
  case "$(uname -m)" in
    aarch64) key="linux-aarch64" ;;
    x86_64)  key="linux-x86_64" ;;
    *) die "Tor Browser is not published for this kind of processor" ;;
  esac

  mkdir -p "$WORK"
  tfetch "$WORK/releases.json" "$TB_RELEASES_URL" || die "could not read the Tor Browser release list"
  urls="$(python3 -c '
import json, sys
entry = json.load(open(sys.argv[1]))["downloads"][sys.argv[2]]["ALL"]
print(entry["binary"])
print(entry["sig"])
' "$WORK/releases.json" "$key")" || die "the Tor Browser release list has no build for this processor"
  binary="$(printf '%s\n' "$urls" | sed -n 1p)"
  sig="$(printf '%s\n' "$urls" | sed -n 2p)"
  case "$binary$sig" in
    *[!A-Za-z0-9._:/-]*) die "the Tor Browser release list looks wrong" ;;
  esac
  case "$binary" in
    https://dist.torproject.org/*|https://archive.torproject.org/*) ;;
    *) die "the Tor Browser download address is not on torproject.org" ;;
  esac
  case "$sig" in
    https://dist.torproject.org/*|https://archive.torproject.org/*) ;;
    *) die "the Tor Browser signature address is not on torproject.org" ;;
  esac

  tfetch "$WORK/tor-browser.tar.xz" "$binary" || die "could not download Tor Browser"
  tfetch "$WORK/tor-browser.tar.xz.asc" "$sig" || die "could not download the Tor Browser signature"
  tfetch "$WORK/tor-browser.key" "$TB_KEY_URL" || die "could not download the Tor Browser signing key"

  export GNUPGHOME="$WORK/gnupg"
  mkdir -p "$GNUPGHOME"
  chmod 700 "$GNUPGHOME"
  gpg --batch --quiet --import "$WORK/tor-browser.key" >/dev/null 2>&1 || die "could not read the Tor Browser signing key"
  status="$(gpg --batch --status-fd 1 --verify "$WORK/tor-browser.tar.xz.asc" "$WORK/tor-browser.tar.xz" 2>/dev/null)"
  if ! printf '%s\n' "$status" | grep -q "^\[GNUPG:\] VALIDSIG .* $TB_KEY_FPR\$"; then
    die "Tor Browser did not pass its signature check, so it was not installed"
  fi
  unset GNUPGHOME

  tar -xJf "$WORK/tor-browser.tar.xz" -C "/home/$VM_USER" || die "could not unpack Tor Browser"
  [ -x "/home/$VM_USER/tor-browser/Browser/start-tor-browser" ] || die "Tor Browser unpacked to an unexpected place"
  chown -R "$VM_USER:$VM_USER" "/home/$VM_USER/tor-browser"
}

create_user() {
  useradd -m -s /bin/bash "$VM_USER" || die "could not create the desktop account"
  passwd -l "$VM_USER" >/dev/null
}

configure_desktop() {
  say "5/8 Setting up the desktop"
  mkdir -p /etc/lightdm/lightdm.conf.d
  cat >/etc/lightdm/lightdm.conf.d/50-opsec.conf <<EOF
[Seat:*]
autologin-user=$VM_USER
autologin-user-timeout=0
user-session=xfce
EOF

  cat >/usr/local/bin/tor-browser <<EOF
#!/bin/sh
export TOR_SKIP_LAUNCH=1
export TOR_SOCKS_HOST=127.0.0.1
export TOR_SOCKS_PORT=9050
exec /home/$VM_USER/tor-browser/Browser/start-tor-browser "\$@"
EOF
  chmod 755 /usr/local/bin/tor-browser

  cat >/usr/share/applications/tor-browser.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Tor Browser
Exec=/usr/local/bin/tor-browser %u
Icon=/home/$VM_USER/tor-browser/Browser/browser/chrome/icons/default/default128.png
Categories=Network;WebBrowser;
EOF
  cp /usr/share/applications/tor-browser.desktop /etc/xdg/autostart/tor-browser.desktop

  mkdir -p /etc/gtk-3.0
  cat >/etc/gtk-3.0/settings.ini <<'EOF'
[Settings]
gtk-recent-files-enabled=false
gtk-recent-files-max-age=0
EOF

  hostnamectl set-hostname host >/dev/null 2>&1 || echo host >/etc/hostname
  if ! grep -q '^127\.0\.1\.1' /etc/hosts; then
    echo "127.0.1.1 host" >>/etc/hosts
  else
    sed -i 's/^127\.0\.1\.1.*/127.0.1.1 host/' /etc/hosts
  fi
  systemctl set-default graphical.target >/dev/null 2>&1
}

seal_system() {
  say "6/8 Removing remote access and administrator rights"
  apt-get -y purge openssh-server >/dev/null 2>&1
  local account
  for account in $(awk -F: '$3 >= 1000 && $3 < 60000 { print $1 }' /etc/passwd); do
    if [ "$account" != "$VM_USER" ]; then
      userdel -r "$account" >/dev/null 2>&1
    fi
  done
  rm -f /etc/sudoers.d/*
  passwd -l root >/dev/null
  systemctl mask serial-getty@ttyAMA0.service serial-getty@ttyS0.service >/dev/null 2>&1

  cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
}

keep_clock_right() {
  cat >/etc/systemd/system/opsec-clock.service <<'EOF'
[Unit]
Description=Set the clock from the virtual hardware clock

[Service]
Type=oneshot
ExecStart=/usr/sbin/hwclock --hctosys --utc
EOF
  cat >/etc/systemd/system/opsec-clock.timer <<'EOF'
[Unit]
Description=Keep the clock right after the host computer sleeps

[Timer]
OnBootSec=30
OnUnitActiveSec=60
AccuracySec=5

[Install]
WantedBy=timers.target
EOF
  systemctl daemon-reload
  systemctl enable opsec-clock.timer >/dev/null 2>&1 || die "could not enable the clock repair timer"
  systemctl start opsec-clock.service || die "could not read the virtual hardware clock"
}

reduce_logs() {
  say "7/8 Turning off logs and history"
  mkdir -p /etc/systemd/journald.conf.d
  cat >/etc/systemd/journald.conf.d/opsec.conf <<'EOF'
[Journal]
Storage=volatile
RuntimeMaxUse=16M
ForwardToSyslog=no
EOF

  echo "tmpfs /var/log tmpfs nosuid,nodev,noexec,mode=0755,size=64m 0 0" >>/etc/fstab
  cat >/etc/tmpfiles.d/opsec-log.conf <<'EOF'
d /var/log/apt 0755 root root -
d /var/log/unattended-upgrades 0750 root adm -
d /var/log/lightdm 0710 root root -
d /var/log/tor 2750 debian-tor adm -
d /var/log/private 0700 root root -
f /var/log/wtmp 0664 root utmp -
f /var/log/btmp 0660 root utmp -
f /var/log/lastlog 0664 root utmp -
EOF

  cat >/etc/profile.d/opsec-history.sh <<'EOF'
unset HISTFILE
export HISTSIZE=0
export LESSHISTFILE=-
EOF

  cat >/etc/security/limits.d/opsec.conf <<'EOF'
* hard core 0
EOF
}

self_test() {
  say "8/8 Testing that nothing can leave without Tor"
  if curl -m 15 -fsS https://deb.debian.org/ >/dev/null 2>&1; then
    die "leak test: the administrator account reached the internet without Tor"
  fi
  if runuser -u "$VM_USER" -- curl -m 15 -fsS https://deb.debian.org/ >/dev/null 2>&1; then
    die "leak test: the desktop account reached the internet without Tor"
  fi
  if timeout 15 getent hosts example.com >/dev/null 2>&1; then
    die "leak test: a name lookup left the machine without Tor"
  fi
  tor_ready || die "Tor stopped working after the lockdown"
  say "Leak tests passed: direct connections and name lookups are blocked, Tor works"
}

clean_up() {
  apt-get clean
  touch /etc/cloud/cloud-init.disabled
  rm -rf "$WORK" /var/lib/cloud /root/.bash_history /root/.gnupg
  find /var/log -mindepth 1 -delete 2>/dev/null
  sync
}

main() {
  bootstrap_packages
  lock_network
  install_desktop
  create_user
  install_tor_browser
  configure_desktop
  seal_system
  keep_clock_right
  reduce_logs
  self_test
  clean_up
  console "OPSEC-RESULT: ok"
  sync
  systemctl poweroff
}

main "$@"
