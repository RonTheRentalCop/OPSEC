#!/usr/bin/env bash

FIREWALL_TOOL="/usr/libexec/ApplicationFirewall/socketfilterfw"
MAC_FIREFOX_PLIST="/Library/Preferences/org.mozilla.firefox.plist"

mac_need_brew() {
  if ! have brew; then
    note "Homebrew is needed to install apps on macOS. Install it from https://brew.sh and run this again."
    return 1
  fi
}

mac_cask() {
  mac_need_brew || return 1
  if brew list --cask "$1" >/dev/null 2>&1; then
    note "$1 is already installed"
    return 0
  fi
  brew install --cask "$1"
}

mac_formula() {
  mac_need_brew || return 1
  if brew list --formula "$1" >/dev/null 2>&1; then
    note "$1 is already installed"
    return 0
  fi
  brew install "$1"
}

mac_firefox() {
  if [ -d "/Applications/Firefox.app" ]; then
    note "Firefox is already installed"
    return 0
  fi
  mac_cask firefox
}

mac_firefox_policies() {
  local tmp status
  tmp="$(mktemp -d)" || return 1
  plutil -extract policies xml1 -o "$tmp/policies.plist" "$(firefox_policy_source)" &&
    plutil -insert EnterprisePoliciesEnabled -bool true "$tmp/policies.plist" &&
    backup_file "$MAC_FIREFOX_PLIST" &&
    sudo defaults import "${MAC_FIREFOX_PLIST%.plist}" "$tmp/policies.plist"
  status=$?
  rm -rf "$tmp"
  [ "$status" -eq 0 ] || return 1
  note "Restart Firefox to pick up the new settings. They survive Firefox updates."
}

mac_updates() {
  local domain="/Library/Preferences/com.apple.SoftwareUpdate"
  sudo defaults write "$domain" AutomaticCheckEnabled -bool true &&
    sudo defaults write "$domain" AutomaticDownload -bool true &&
    sudo defaults write "$domain" CriticalUpdateInstall -bool true &&
    sudo defaults write "$domain" ConfigDataInstall -bool true &&
    sudo defaults write "$domain" AutomaticallyInstallMacOSUpdates -bool true &&
    sudo defaults write /Library/Preferences/com.apple.commerce AutoUpdate -bool true
}

mac_firewall() {
  sudo "$FIREWALL_TOOL" --setglobalstate on
}

mac_firewall_stealth() {
  sudo "$FIREWALL_TOOL" --setstealthmode on
}

vpn_install_mullvad() {
  if [ -d "/Applications/Mullvad VPN.app" ]; then
    note "Mullvad VPN is already installed"
    return 0
  fi
  mac_cask mullvad-vpn
}

vpn_install_warp() {
  if [ -d "/Applications/Cloudflare WARP.app" ]; then
    note "Cloudflare WARP is already installed"
    return 0
  fi
  mac_cask cloudflare-warp
}

mac_mullvad_browser() { mac_cask mullvad-browser; }
mac_signal()          { mac_cask signal; }
mac_lynis()           { mac_formula lynis; }
vm_install_qemu()     { mac_formula qemu; }

mac_disk_encrypted() {
  fdesetup status 2>/dev/null | grep -q "FileVault is On"
}

mac_ad_tracking() {
  defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false &&
    defaults write com.apple.AdLib allowIdentifierForAdvertising -bool false
}

plan_tier4() {
  step "Install Firefox" mac_firefox
  step "Set up Firefox: strict tracking protection, HTTPS only, encrypted DNS (Quad9), DuckDuckGo, uBlock Origin and Bitwarden" mac_firefox_policies
  step "Turn on automatic macOS and security updates" mac_updates
  step "Turn on the macOS firewall" mac_firewall
  manual "Open Firefox and accept the uBlock Origin and Bitwarden add-ons when it asks."
  manual "Create a Bitwarden vault and turn on two-step login."
  manual "Put an authenticator app (Ente Auth) on your phone and use it instead of text-message codes."
}

plan_tier3() {
  plan_vpn_settings
  step "Install Mullvad Browser for sensitive browsing" mac_mullvad_browser
  step "Install Signal" mac_signal
  step "Turn off Apple's personalised ads" mac_ad_tracking
  if ! mac_disk_encrypted; then
    manual "Your disk is NOT encrypted. OPSEC never encrypts a disk for you. If you want it, turn on FileVault yourself in System Settings > Privacy & Security, and save the recovery key somewhere safe first."
  fi
  manual "Accept the Consent-O-Matic add-on in Firefox so cookie banners are rejected for you."
  manual "In System Settings > Wi-Fi, set Private Wi-Fi Address to Rotating for each network."
  manual "Sign up for SimpleLogin or Firefox Relay so sign-ups do not get your real email address."
}

plan_tier2() {
  step "Turn on firewall stealth mode" mac_firewall_stealth
  step "Install the Lynis security audit tool" mac_lynis
  manual "macOS can only be partly hardened. Linux is the recommended base for this tier."
  manual "Use a standard (non-admin) account for daily work."
  manual "Run 'sudo lynis audit system' to see what else can be tightened."
}

plan_tier1() {
  step "Install QEMU, the virtual machine software" vm_install_qemu
  step "Build the sealed, Tor-only VM. Asks you for a passphrase, then takes 15 to 40 minutes" vm_create_step
  vm_manual_tier1
}
