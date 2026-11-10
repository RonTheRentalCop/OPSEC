#!/usr/bin/env bash

status_line() {
  local mark
  case "$1" in
    on)  mark=" on " ;;
    off) mark=" OFF" ;;
    *)   mark=" ?? " ;;
  esac
  printf '  [%s] %s\n' "$mark" "$2"
}

status_check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    status_line on "$label"
  else
    status_line off "$label"
  fi
}

status_vpn_kill_switch() {
  local cli
  cli="$(mullvad_cli)"
  [ -n "$cli" ] && "$cli" lockdown-mode get 2>/dev/null | grep -qiw "on"
}

status_file() { [ -e "$1" ]; }

status_sysctl() { [ "$(sysctl -n "$1" 2>/dev/null)" = "$2" ]; }

status_mac_firewall() { "$FIREWALL_TOOL" --getglobalstate | grep -qiE "enabled|State = [12]"; }
status_mac_stealth()  { "$FIREWALL_TOOL" --getstealthmode | grep -qiE "enabled|is on"; }
status_mac_updates() {
  local domain="/Library/Preferences/com.apple.SoftwareUpdate"
  [ "$(defaults read "$domain" AutomaticCheckEnabled 2>/dev/null)" != "0" ] &&
    [ "$(defaults read "$domain" AutomaticallyInstallMacOSUpdates 2>/dev/null)" = "1" ]
}
status_mac_firefox()  { [ "$(defaults read "${MAC_FIREFOX_PLIST%.plist}" EnterprisePoliciesEnabled 2>/dev/null)" = "1" ]; }

status_linux_firewall() {
  systemctl is-active --quiet ufw || systemctl is-active --quiet firewalld
}

status_linux_updates() {
  grep -qs 'Unattended-Upgrade "1"' /etc/apt/apt.conf.d/20auto-upgrades ||
    systemctl is-enabled --quiet dnf5-automatic.timer 2>/dev/null ||
    systemctl is-enabled --quiet dnf-automatic-install.timer 2>/dev/null ||
    systemctl is-enabled --quiet dnf-automatic.timer 2>/dev/null
}

status_linux_confinement() {
  if have getenforce; then
    [ "$(getenforce)" = "Enforcing" ]
  else
    [ "$(cat /sys/module/apparmor/parameters/enabled 2>/dev/null)" = "Y" ]
  fi
}

status_tier4() {
  echo "Tier 4: Hygiene"
  case "$OPSEC_OS" in
    macos)
      status_check "Firewall" status_mac_firewall
      status_check "Automatic updates" status_mac_updates
      status_check "Firefox privacy settings" status_mac_firefox
      ;;
    *)
      status_check "Firewall" status_linux_firewall
      status_check "Automatic security updates" status_linux_updates
      status_check "Firefox privacy settings" status_file /etc/firefox/policies/policies.json
      ;;
  esac
}

status_tier3() {
  echo "Tier 3: Private"
  status_check "VPN connected" vpn_connected
  status_check "VPN kill switch (Mullvad lockdown mode)" status_vpn_kill_switch
  case "$OPSEC_OS" in
    macos)
      status_check "Disk encryption (FileVault)" mac_disk_encrypted
      ;;
    *)
      status_check "Disk encryption" linux_disk_encrypted
      status_check "Encrypted DNS for the whole system" status_file /etc/systemd/resolved.conf.d/opsec-quad9.conf
      status_check "Network hardware address randomised per network" status_file /etc/NetworkManager/conf.d/00-opsec-mac.conf
      ;;
  esac
}

status_tier2() {
  echo "Tier 2: Hardened"
  case "$OPSEC_OS" in
    macos)
      status_check "Firewall stealth mode" status_mac_stealth
      ;;
    *)
      status_check "Hardened kernel settings" status_sysctl kernel.kptr_restrict 2
      status_check "App confinement (AppArmor or SELinux)" status_linux_confinement
      status_check "USBGuard" systemctl is-active --quiet usbguard
      ;;
  esac
}

status_tier1() {
  echo "Tier 1: Anonymous"
  status_check "QEMU installed" have "$(vm_qemu)"
  status_check "Sealed VM built" vm_exists
  case "$OPSEC_OS" in
    macos) ;;
    *)
      status_check "TCP timestamps off" status_sysctl net.ipv4.tcp_timestamps 0
      status_check "Random network hardware address on every connection" status_file /etc/NetworkManager/conf.d/01-opsec-mac-random.conf
      ;;
  esac
}

status_online() {
  echo "What the internet sees (asked from Mullvad's and Cloudflare's check pages)"
  local reply
  reply="$(curl -fsS -m 15 --proto '=https' https://am.i.mullvad.net/json 2>/dev/null)" || reply=""
  if [ -z "$reply" ]; then
    status_line unknown "Could not reach the check page"
    return 0
  fi
  local ip country
  ip="$(printf '%s' "$reply" | sed -n 's/.*"ip":"\([^"]*\)".*/\1/p')"
  country="$(printf '%s' "$reply" | sed -n 's/.*"country":"\([^"]*\)".*/\1/p')"
  echo "  Websites see the address $ip ($country)"
  if printf '%s' "$reply" | grep -q '"mullvad_exit_ip":true'; then
    status_line on "Traffic leaves through Mullvad"
  elif curl -fsS -m 15 --proto '=https' https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | grep -qE '^warp=(on|plus)'; then
    status_line on "Traffic leaves through Cloudflare WARP"
  else
    status_line off "Traffic leaves through a VPN that OPSEC knows"
  fi
  echo "  For DNS and WebRTC leaks, open https://mullvad.net/check in the browser you use."
}

opsec_status() {
  local online=0 arg
  for arg in "$@"; do
    case "$arg" in
      --online) online=1 ;;
      *)
        echo "Usage: opsec status [--online]" >&2
        exit 1
        ;;
    esac
  done
  if ! detect_os; then
    echo "OPSEC does not support this system yet." >&2
    exit 1
  fi
  . "$ROOT_DIR/lib/vm.sh"
  . "$ROOT_DIR/configs/$OPSEC_OS.sh"

  echo "OPSEC status on $(os_label). Nothing is changed and nothing is recorded."
  echo ""
  status_tier4
  echo ""
  status_tier3
  echo ""
  status_tier2
  echo ""
  status_tier1
  echo ""
  if [ "$online" -eq 1 ]; then
    status_online
  else
    echo "Add --online to also check which address websites see. That contacts"
    echo "Mullvad's and Cloudflare's check pages."
  fi
}
