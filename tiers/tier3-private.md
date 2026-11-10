# Tier 3: Private
Deeper into privacy and security. Still prioritizes speed, but accepts some slowdown for stronger protection of your data.

Includes everything in Tier 4.

Goals: hidden from ISPs, networks and data collectors; automatic cookie denial; heightened site and device security.

Threat model:
- Protects you from: your internet provider, school, workplace or public Wi-Fi logging the sites you visit; advertisers building a profile of you; someone reading your files after the laptop is lost or stolen.
- Does not protect you from: the VPN company itself, which can see what your internet provider used to see, so you are moving your trust rather than removing it. It also does not hide you from sites you log into, and it is not anonymity.

- Network privacy: Mullvad VPN by default, or Cloudflare WARP as the free option. Kill switch on, DNS leak protection on, connect on startup. WARP is labeled as ISP and Wi-Fi protection only.

- Private browser: Mullvad Browser for sensitive browsing; Firefox stays for everyday use.

- Firefox hardening: arkenfox user.js, with a relaxed overrides file so common sites still work.

- Cookie denial: Consent-O-Matic auto-rejects cookie banners. Firefox Total Cookie Protection on, with cookies and site data deleted on close (allow list for trusted sites).

- Disk encryption, recommended for this tier: BitLocker or Device Encryption (Windows), LUKS2 (Linux), FileVault (macOS). OPSEC only checks whether it is on. It never turns it on for you, so you cannot be locked out by accident. If you turn it on yourself, save the recovery key in Bitwarden first.

- Telemetry: O&O ShutUp10++ recommended preset on Windows; system settings on Linux and macOS. Advertising ID, diagnostics and activity history off.

- Network identity: MAC address randomized per network and a generic hostname. NetworkManager (Linux), Windows random hardware addresses, macOS private Wi-Fi address.

- Messaging: Signal/Telegram

- Email aliases: SimpleLogin or Firefox Relay, so sign-ups don't expose your real email address.
