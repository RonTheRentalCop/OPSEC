# OPSEC
OPSEC (Based off the meme) is an open source tool that applies a tiered security and privacy configuration to a computer with one command. (Hopefully)


## I am looking for contributers! Please DM me on Discord at courtleeoed.



# Tier Configurations

How the tiers work:

Tiers are seporated based off a sliding line chart of 
        
Fast <-----------------------> Secure

Lower tiers will focus security but not so much anonimity. You will leave traces much of where you track. Used mostly for simple browser and device security practices. As you reach tier 3/4 browsing will become extremely slow due to routing and covering traces across the net. Listed 
## Tier 0: Hygiene
Baseline internet safety and security. Prioritizes speed, with some privacy on the clear web.

Goals: stronger passwords, ads blocked, updates on, trackers blocked.

- Browser: Firefox. Enhanced Tracking Protection set to Strict, HTTPS-Only Mode on, telemetry and studies off, password saving off.
- Ad and tracker blocking: uBlock Origin. Default filter lists plus EasyPrivacy and AdGuard Tracking Protection.
- Search: DuckDuckGo, set as the default in Firefox.
- Passwords: Bitwarden. Browser extension installed; prompt the user to create a vault and turn on two-factor login.
- Two-factor codes: Ente Auth or Aegis (Android). Avoid SMS codes where possible.
- Encrypted DNS: Quad9, using DNS over HTTPS in Firefox and at the system level.
- Updates: automatic security updates on. Windows Update, unattended-upgrades (Debian, Ubuntu), dnf-automatic (Fedora), Software Update (macOS).
- Firewall: on, blocking unsolicited incoming connections. Windows Defender Firewall, ufw, firewalld or the macOS firewall.
- Malware protection: Microsoft Defender (Windows) or XProtect (macOS), with real-time protection on. No third-party antivirus.

## Tier 1: Private
Deeper into privacy and security. Still prioritizes speed, but accepts some slowdown for stronger protection of your data.

Goals: hidden from ISPs, networks and data collectors; automatic cookie denial; heightened site and device security.

- Network privacy: Mullvad VPN by default, or Cloudflare WARP as the free option. Kill switch on, DNS leak protection on, connect on startup. WARP is labeled as ISP and Wi-Fi protection only.

- Private browser: Mullvad Browser for sensitive browsing; Firefox stays for everyday use.

- Firefox hardening: arkenfox user.js, with a relaxed overrides file so common sites still work.

- Cookie denial: Consent-O-Matic auto-rejects cookie banners. Firefox Total Cookie Protection on, with cookies and site data deleted on close (allow list for trusted sites).

- Disk encryption, required to pass this tier: BitLocker or Device Encryption (Windows), LUKS2 (Linux), FileVault (macOS). Recovery key saved in Bitwarden.

- Telemetry: O&O ShutUp10++ recommended preset on Windows; system settings on Linux and macOS. Advertising ID, diagnostics and activity history off.

- Network identity: MAC address randomized per network and a generic hostname. NetworkManager (Linux), Windows random hardware addresses, macOS private Wi-Fi address.

- Messaging: Signal/Telegram

- Email aliases: SimpleLogin or Firefox Relay, so sign-ups don't expose your real email address.

## Tier 2: Hardened
Much more focus on moving to a hardened operating system. Security comes before convenience, and some apps may stop working.

Goals: device locked down against attacks; apps sandboxed; recommended move to a Linux base.

- Base system: Fedora or Debian with Kicksecure hardening is recommended, with a guided migration from Windows. Windows users get the partial track below.

- Kernel and system: Kicksecure security-misc. Hardened sysctl and boot parameters; unused kernel modules disabled.
- Mandatory access control: AppArmor (Debian, Ubuntu) or SELinux enforcing (Fedora), with profiles for the browser and common apps.
- App sandboxing: Firejail, or Flatpak with Flatseal. Browsers, PDF readers and chat apps sandboxed with restricted permissions.
- USB devices: USBGuard blocks unknown devices until approved.
- Firewall: ufw or firewalld. All incoming traffic denied; outgoing allowed by default.
- Windows track: Microsoft Defender with attack surface reduction rules, Smart App Control, Windows Sandbox, Microsoft Security Baselines, and a standard user account for daily use.
- Secure boot: UEFI Secure Boot and a firmware password; booting from external devices blocked.
- Audit: Lynis (Linux) or Hardening Kitty (Windows) runs after setup, with results shown in `opsec status`.

## Tier 3: Anonymous
Activity on the open web can't be traced back to you. Speed is no longer a priority, and identities are kept separate.

Goals: real IP address hidden; browser fingerprint shared with other users; anonymous activity isolated from personal activity.

- Anonymous browser: Tor Browser. Security level Safer by default, Safest offered. No added extensions; window size left at default.

- System isolation: Whonix Gateway and Workstation VMs force all workstation traffic through Tor. Runs in VirtualBox or KVM, including on Windows hosts.

- Leak protection: host firewall rules block any traffic from the anonymous environment that bypasses Tor.

- Censorship bypass: Tor bridges (obfs4, Snowflake), offered when Tor is blocked on the network.

- Separate identities: a separate browser and VM per identity. The first-run guide says never to log into personal accounts or reuse usernames here.

- Metadata removal: mat2 strips metadata from files before sharing.

- Anonymous messaging: SimpleX Chat or Briar, no phone number required.

Note: Tor is not routed through a VPN or WARP by default. That adds another party who can see your traffic.

## Tier 4: Lockdown
Maximum isolation. Built for communicating and hosting without anyone mapping who talks to whom. Convenience is traded away almost entirely.

Goals: traffic analysis resisted; every activity compartmentalized; nothing left behind on shutdown; emergency data destruction available.

- Base system: Qubes OS installed, or Tails on USB (leaves no trace). Guided install with verified downloads; Whonix qubes for Tor.

- Anonymous network: i2pd or Java I2P with strict settings: hidden mode, no floodfill, longer tunnels, reduced bandwidth sharing, no outproxy by default.

- Open-web access: Tor Browser in a Whonix qube. Tor and I2P are kept separate and never layered.

- Compartments: separate qubes for personal, anonymous, I2P and offline work, plus disposable qubes for untrusted files.

- Egress firewall: Qubes firewall or nftables. All outgoing traffic denied except Tor and I2P.

- Memory wiping: RAM cleared on shutdown, through Tails or Kicksecure ram-wipe.

- Hidden storage: VeraCrypt hidden volume for deniable encrypted storage.

- Emergency wipe: destroys the LUKS header and keyslots. Off by default; typed confirmation to enable; test mode; manual trigger.

- Dead-man timer: a systemd timer that calls the emergency wipe. Off by default; advance warnings; a simple check-in resets it.

- Offline secrets: encryption keys and sensitive files kept on an air-gapped qube or device.

Note: I2P handles hidden services and messaging inside its own network. Tor handles reaching the regular internet.

Note: PGP Communication would not be a bad idea although I'm still unsure. Some protocalls are uncracked but it is inconvient but still might be suitible. Still leave behind timestamp subjects email subject line and timestamps. 

Decision: the P2P messaging service uses 4096-bit RSA keys. See [P2P Messaging Service](#p2p-messaging-service-planned) below.


## P2P Messaging Service (planned)
A peer-to-peer encrypted messenger with no user IDs and no central servers, routed over Tor or Yggdrasil.

### Encryption decision: RSA-4096
- Identity keys: 4096-bit RSA. Each user's long-term key signs and verifies their identity.
- Message encryption: the Double Ratchet algorithm gives every message its own AES-256 key and deletes old keys, which provides forward secrecy.
- Ratchet key exchange: the per-message key exchanges inside the ratchet use X25519, because generating a fresh RSA-4096 key for every message takes too long (from half a second to several seconds each). The RSA-4096 identity key signs these exchanges, so they stay tied to the user's identity.

### Known risks (accepted)
- Quantum computing: a large enough quantum computer could break both RSA and elliptic curve cryptography. This risk is accepted for now. Public-key crypto used across the internet and in cryptocurrency faces the same threat, and no practical attack exists yet. A post-quantum key exchange such as ML-KEM can be added later if needed.
- Performance: RSA-4096 keys are about 512 bytes and private-key operations are roughly 100 to 200 times slower than Ed25519. Because the keys are used only for identity, users won't notice the difference.
- Metadata: encryption protects message content only. Hiding who talks to whom depends on the network layer (Tor or Yggdrasil, no user IDs, and rotating queue IDs).

## License
This project is licensed under the GNU General Public License v3.0 (GPLv3). See the [LICENSE](./LICENSE) file for the full text.

## Legal Disclaimer
This project is provided for lawful, authorized use only. The author is not responsible for criminal, illegal, or unlawful misuse of the software. See [Legal.md](./Legal.md) for the full legal notice and liability disclaimer.


