# Tier 4: Hygiene
Baseline internet safety and security. Prioritizes speed, with some privacy on the clear web.

The starting point. Every other tier builds on this one.

Goals: stronger passwords, ads blocked, updates on, trackers blocked.

Threat model:
- Protects you from: advertisers and trackers following you between sites, scam and malware sites, stolen or reused passwords, attacks on out-of-date software.
- Does not protect you from: your internet provider or network seeing which sites you visit, websites knowing your location from your IP address, or someone who has your unlocked computer.

- Browser: Firefox. Enhanced Tracking Protection set to Strict, HTTPS-Only Mode on, telemetry and studies off, password saving off.
- Ad and tracker blocking: uBlock Origin. Default filter lists plus EasyPrivacy and AdGuard Tracking Protection.
- Search: DuckDuckGo, set as the default in Firefox.
- Passwords: Bitwarden. Browser extension installed; prompt the user to create a vault and turn on two-factor login.
- Two-factor codes: Ente Auth or Aegis (Android). Avoid SMS codes where possible.
- Encrypted DNS: Quad9, using DNS over HTTPS in Firefox and at the system level.
- Updates: automatic security updates on. Windows Update, unattended-upgrades (Debian, Ubuntu), dnf-automatic (Fedora), Software Update (macOS).
- Firewall: on, blocking unsolicited incoming connections. Windows Defender Firewall, ufw, firewalld or the macOS firewall.
- Malware protection: Microsoft Defender (Windows) or XProtect (macOS), with real-time protection on. No third-party antivirus.
