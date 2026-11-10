#!/usr/bin/env bash

. "$ROOT_DIR/configs/linux-common.sh"

linux_pkg() {
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

deb_refresh() { sudo apt-get update; }

deb_firefox() {
  if have firefox || have firefox-esr; then
    note "Firefox is already installed"
    return 0
  fi
  linux_pkg firefox || linux_pkg firefox-esr
}

deb_updates() {
  linux_pkg unattended-upgrades || return 1
  write_root_file /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
}

deb_firewall() {
  linux_pkg ufw || return 1
  sudo ufw default deny incoming || return 1
  sudo ufw default allow outgoing || return 1
  if [ -n "${SSH_CONNECTION:-}" ]; then
    note "You are connected over SSH, so SSH is kept open to avoid locking you out."
    sudo ufw allow ssh || return 1
  fi
  sudo ufw --force enable
}

deb_pinned_key() {
  local url="$1" expected="$2" dest="$3" tmp status
  linux_pkg curl gpg || return 1
  tmp="$(mktemp -d)" || return 1
  fetch_pinned_key "$url" "$expected" "$tmp/key" &&
    gpg --batch --yes --dearmor --output "$tmp/key.gpg" "$tmp/key" &&
    sudo install -m 644 "$tmp/key.gpg" "$dest"
  status=$?
  rm -rf "$tmp"
  return "$status"
}

vm_install_qemu() {
  case "$(dpkg --print-architecture)" in
    amd64) linux_pkg qemu-system-x86 qemu-system-gui qemu-utils ;;
    arm64) linux_pkg qemu-system-arm qemu-system-gui qemu-utils qemu-efi-aarch64 ;;
    *)
      note "The sealed VM does not support this kind of processor yet."
      return 1
      ;;
  esac
}

deb_mullvad_repo() {
  deb_pinned_key https://repository.mullvad.net/deb/mullvad-keyring.asc "$MULLVAD_KEY_FPR" /usr/share/keyrings/mullvad-keyring.gpg || return 1
  echo "deb [signed-by=/usr/share/keyrings/mullvad-keyring.gpg arch=$(dpkg --print-architecture)] https://repository.mullvad.net/deb/stable stable main" |
    sudo tee /etc/apt/sources.list.d/mullvad.list >/dev/null || return 1
  sudo apt-get update
}

vpn_install_mullvad() {
  if have mullvad; then
    note "Mullvad VPN is already installed"
    return 0
  fi
  deb_mullvad_repo && linux_pkg mullvad-vpn
}

vpn_install_warp() {
  if have warp-cli; then
    note "Cloudflare WARP is already installed"
    return 0
  fi
  linux_pkg lsb-release || return 1
  deb_pinned_key https://pkg.cloudflareclient.com/pubkey.gpg "$CLOUDFLARE_KEY_FPR" /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg || return 1
  echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" |
    sudo tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null || return 1
  sudo apt-get update && linux_pkg cloudflare-warp
}

deb_mullvad_browser() {
  [ -f /etc/apt/sources.list.d/mullvad.list ] || deb_mullvad_repo || return 1
  linux_pkg mullvad-browser
}

deb_signal() {
  if have signal-desktop; then
    note "Signal is already installed"
    return 0
  fi
  if [ "$(dpkg --print-architecture)" != "amd64" ]; then
    note "Signal only publishes its Linux app for 64-bit Intel/AMD computers."
    return 1
  fi
  deb_pinned_key https://updates.signal.org/desktop/apt/keys.asc "$SIGNAL_KEY_FPR" /usr/share/keyrings/signal-desktop-keyring.gpg || return 1
  write_root_file /etc/apt/sources.list.d/signal-desktop.sources <<'EOF' || return 1
Types: deb
URIs: https://updates.signal.org/desktop/apt
Suites: xenial
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/signal-desktop-keyring.gpg
EOF
  sudo apt-get update && linux_pkg signal-desktop
}

deb_usage_reports() {
  if have ubuntu-report; then
    ubuntu-report -f send no || return 1
  fi
  if dpkg -s popularity-contest >/dev/null 2>&1; then
    sudo env DEBIAN_FRONTEND=noninteractive apt-get purge -y popularity-contest || return 1
  fi
  if dpkg -s apport >/dev/null 2>&1; then
    sudo systemctl disable --now apport.service >/dev/null 2>&1
  fi
  return 0
}

deb_apparmor() {
  linux_pkg apparmor apparmor-utils apparmor-profiles || return 1
  sudo systemctl enable --now apparmor.service
}

plan_tier4() {
  step "Refresh the list of available software" deb_refresh
  step "Install Firefox" deb_firefox
  step "Set up Firefox: strict tracking protection, HTTPS only, encrypted DNS (Quad9), DuckDuckGo, uBlock Origin and Bitwarden" linux_firefox_policies
  step "Turn on automatic security updates" deb_updates
  step "Turn on the firewall and block incoming connections" deb_firewall
  linux_manual_tier4
}

plan_tier3() {
  plan_vpn_settings
  step "Install Mullvad Browser for sensitive browsing" deb_mullvad_browser
  step "Install Signal" deb_signal
  step "Use encrypted DNS (Quad9) for the whole system" linux_system_dns
  step "Randomise the network hardware address on each network" linux_mac_randomization
  step "Turn off usage and crash reporting" deb_usage_reports
  linux_manual_tier3
}

plan_tier2() {
  step "Turn on AppArmor app confinement with extra profiles" deb_apparmor
  step "Apply hardened kernel and network settings" linux_sysctl_hardening
  step "Install Flatpak and Flatseal for sandboxed apps" linux_flatseal
  step "Install USBGuard to block unknown USB devices" linux_usbguard
  step "Install the Lynis security audit tool" linux_lynis
  linux_manual_tier2
}

plan_tier1() {
  linux_plan_tier1
}
