#!/usr/bin/env bash

. "$ROOT_DIR/configs/linux-common.sh"

linux_pkg() {
  sudo dnf install -y "$@"
}

fed_firefox() {
  if have firefox; then
    note "Firefox is already installed"
    return 0
  fi
  linux_pkg firefox
}

fed_updates() {
  linux_pkg dnf-automatic || return 1
  write_root_file /etc/dnf/automatic.conf <<'EOF' || return 1
[commands]
upgrade_type = security
apply_updates = yes
EOF
  local timer
  for timer in dnf5-automatic.timer dnf-automatic-install.timer dnf-automatic.timer; do
    if systemctl list-unit-files "$timer" 2>/dev/null | grep -q "$timer"; then
      sudo systemctl enable --now "$timer"
      return $?
    fi
  done
  note "The automatic update timer was not found."
  return 1
}

fed_firewall() {
  have firewall-cmd || linux_pkg firewalld || return 1
  sudo systemctl enable --now firewalld.service || return 1
  sudo firewall-cmd --set-default-zone=public
}

fed_pinned_key() {
  local url="$1" expected="$2" dest="$3" tmp status
  tmp="$(mktemp -d)" || return 1
  fetch_pinned_key "$url" "$expected" "$tmp/key" &&
    sudo install -D -m 644 "$tmp/key" "$dest"
  status=$?
  rm -rf "$tmp"
  return "$status"
}

vm_install_qemu() {
  case "$(uname -m)" in
    x86_64)  linux_pkg qemu-system-x86 qemu-img qemu-ui-gtk ;;
    aarch64) linux_pkg qemu-system-aarch64 qemu-img qemu-ui-gtk edk2-aarch64 ;;
    *)
      note "The sealed VM does not support this kind of processor yet."
      return 1
      ;;
  esac
}

fed_mullvad_repo() {
  [ -f /etc/yum.repos.d/mullvad.repo ] && return 0
  fed_pinned_key https://repository.mullvad.net/rpm/mullvad-keyring.asc "$MULLVAD_KEY_FPR" /etc/pki/rpm-gpg/opsec-mullvad.asc || return 1
  write_root_file /etc/yum.repos.d/mullvad.repo <<'EOF'
[mullvad-stable]
name=Mullvad VPN
baseurl=https://repository.mullvad.net/rpm/stable/$basearch
type=rpm
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/opsec-mullvad.asc
EOF
}

vpn_install_mullvad() {
  if have mullvad; then
    note "Mullvad VPN is already installed"
    return 0
  fi
  fed_mullvad_repo && linux_pkg mullvad-vpn
}

vpn_install_warp() {
  if have warp-cli; then
    note "Cloudflare WARP is already installed"
    return 0
  fi
  if [ ! -f /etc/yum.repos.d/cloudflare-warp.repo ]; then
    fed_pinned_key https://pkg.cloudflareclient.com/pubkey.gpg "$CLOUDFLARE_KEY_FPR" /etc/pki/rpm-gpg/opsec-cloudflare.asc || return 1
    write_root_file /etc/yum.repos.d/cloudflare-warp.repo <<'EOF' || return 1
[cloudflare-warp-stable]
name=cloudflare-warp-stable
baseurl=https://pkg.cloudflareclient.com/rpm/$releasever
enabled=1
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/opsec-cloudflare.asc
EOF
  fi
  linux_pkg cloudflare-warp
}

fed_mullvad_browser() {
  fed_mullvad_repo || return 1
  linux_pkg mullvad-browser
}

fed_signal() { linux_flatpak_app org.signal.Signal; }

fed_usage_reports() {
  if systemctl list-unit-files abrtd.service 2>/dev/null | grep -q abrtd.service; then
    sudo systemctl disable --now abrtd.service || return 1
  fi
  return 0
}

fed_selinux() {
  if ! have getenforce; then
    note "SELinux tools were not found."
    return 1
  fi
  if [ "$(getenforce)" = "Enforcing" ]; then
    note "SELinux is already enforcing"
    return 0
  fi
  if [ "$(getenforce)" = "Disabled" ]; then
    backup_file /etc/selinux/config
    sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config || return 1
    note "SELinux was disabled. It will be enforcing after a restart."
    return 0
  fi
  backup_file /etc/selinux/config
  sudo setenforce 1 && sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
}

plan_tier4() {
  step "Install Firefox" fed_firefox
  step "Set up Firefox: strict tracking protection, HTTPS only, encrypted DNS (Quad9), DuckDuckGo, uBlock Origin and Bitwarden" linux_firefox_policies
  step "Turn on automatic security updates" fed_updates
  step "Turn on the firewall and block incoming connections" fed_firewall
  linux_manual_tier4
}

plan_tier3() {
  plan_vpn_settings
  step "Install Mullvad Browser for sensitive browsing" fed_mullvad_browser
  step "Install Signal" fed_signal
  step "Use encrypted DNS (Quad9) for the whole system" linux_system_dns
  step "Randomise the network hardware address on each network" linux_mac_randomization
  step "Turn off crash reporting" fed_usage_reports
  linux_manual_tier3
}

plan_tier2() {
  step "Make sure SELinux is enforcing" fed_selinux
  step "Apply hardened kernel and network settings" linux_sysctl_hardening
  step "Install Flatpak and Flatseal for sandboxed apps" linux_flatseal
  step "Install USBGuard to block unknown USB devices" linux_usbguard
  step "Install the Lynis security audit tool" linux_lynis
  linux_manual_tier2
}

plan_tier1() {
  linux_plan_tier1
}
