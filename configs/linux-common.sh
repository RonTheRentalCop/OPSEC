#!/usr/bin/env bash

linux_firefox_policies() {
  local src
  src="$(firefox_policy_source)"
  install_root_file "$src" /etc/firefox/policies/policies.json || return 1
  if have firefox-esr; then
    install_root_file "$src" /etc/firefox-esr/policies/policies.json || return 1
  fi
  note "Restart Firefox to pick up the new settings."
}

linux_system_dns() {
  if ! systemctl is-active --quiet systemd-resolved; then
    note "systemd-resolved is not in use here, so system-wide encrypted DNS was skipped."
    note "Firefox still uses encrypted DNS."
    return 0
  fi
  write_root_file /etc/systemd/resolved.conf.d/opsec-quad9.conf <<'EOF' || return 1
[Resolve]
DNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net 2620:fe::fe#dns.quad9.net
DNSOverTLS=yes
EOF
  sudo systemctl restart systemd-resolved
}

linux_mac_randomization() {
  if ! have nmcli; then
    note "NetworkManager is not in use here, so this was skipped."
    return 0
  fi
  write_root_file /etc/NetworkManager/conf.d/00-opsec-mac.conf <<'EOF' || return 1
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=stable
ethernet.cloned-mac-address=stable
EOF
  sudo systemctl reload NetworkManager
}

linux_disk_encrypted() {
  lsblk -o TYPE 2>/dev/null | grep -q crypt
}

linux_sysctl_hardening() {
  write_root_file /etc/sysctl.d/60-opsec.conf <<'EOF' || return 1
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
kernel.unprivileged_bpf_disabled=1
kernel.yama.ptrace_scope=1
kernel.kexec_load_disabled=1
net.core.bpf_jit_harden=2
net.ipv4.tcp_syncookies=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.all.accept_source_route=0
fs.protected_symlinks=1
fs.protected_hardlinks=1
fs.protected_fifos=2
fs.protected_regular=2
fs.suid_dumpable=0
EOF
  sudo sysctl --system >/dev/null
}

linux_flathub() {
  have flatpak || linux_pkg flatpak || return 1
  sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

linux_flatpak_app() {
  linux_flathub || return 1
  sudo flatpak install -y --noninteractive flathub "$1"
}

linux_flatseal() { linux_flatpak_app com.github.tchx84.Flatseal; }

linux_usbguard() {
  if ! have usbguard; then
    sudo systemctl mask usbguard.service >/dev/null 2>&1
    linux_pkg usbguard
    local status=$?
    sudo systemctl unmask usbguard.service >/dev/null 2>&1
    [ "$status" -eq 0 ] || return 1
  fi
  if ! sudo test -s /etc/usbguard/rules.conf; then
    sudo sh -c 'umask 077 && usbguard generate-policy > /etc/usbguard/rules.conf' || return 1
  fi
  if ! sudo test -s /etc/usbguard/rules.conf; then
    note "Could not list the USB devices plugged in now, so USBGuard was left off to avoid locking out your keyboard."
    return 1
  fi
  sudo systemctl enable --now usbguard.service || return 1
  note "USB devices plugged in right now are trusted. New ones are blocked until you allow them with 'usbguard allow-device'."
}

linux_network_leaks() {
  write_root_file /etc/sysctl.d/61-opsec-anonymity.conf <<'EOF' || return 1
net.ipv4.tcp_timestamps=0
net.ipv6.conf.all.use_tempaddr=2
net.ipv6.conf.default.use_tempaddr=2
EOF
  sudo sysctl --system >/dev/null
}

linux_mac_random() {
  if ! have nmcli; then
    note "NetworkManager is not in use here, so this was skipped."
    return 0
  fi
  write_root_file /etc/NetworkManager/conf.d/01-opsec-mac-random.conf <<'EOF' || return 1
[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
EOF
  sudo systemctl reload NetworkManager
}

linux_plan_tier1() {
  step "Stop the computer leaking its clock and permanent network address" linux_network_leaks
  step "Use a new random network hardware address on every connection" linux_mac_random
  step "Install QEMU, the virtual machine software" vm_install_qemu
  step "Build the sealed, Tor-only VM. Asks you for a passphrase, then takes 15 to 40 minutes" vm_create_step
  vm_manual_tier1
}

linux_lynis() { linux_pkg lynis; }

linux_manual_tier4() {
  manual "Open Firefox and accept the uBlock Origin and Bitwarden add-ons when it asks."
  manual "Create a Bitwarden vault and turn on two-step login."
  manual "Put an authenticator app (Ente Auth or Aegis) on your phone and use it instead of text-message codes."
}

linux_manual_tier3() {
  if ! linux_disk_encrypted; then
    manual "Your disk does NOT look encrypted. OPSEC never encrypts a disk for you. On Linux this is normally chosen when the system is installed, so it is your decision to back up and reinstall with disk encryption."
  fi
  manual "Accept the Consent-O-Matic add-on in Firefox so cookie banners are rejected for you."
  manual "Sign up for SimpleLogin or Firefox Relay so sign-ups do not get your real email address."
}

linux_manual_tier2() {
  manual "Turn on Secure Boot and set a firmware password in your computer's startup settings."
  manual "Open Flatseal to tighten what each app is allowed to access."
  manual "Run 'sudo lynis audit system' to see what else can be tightened."
}
