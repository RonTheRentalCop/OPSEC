# Tier 2: Hardened
Much more focus on moving to a hardened operating system. Security comes before convenience, and some apps may stop working.

Includes everything in Tiers 3 and 4.

Goals: device locked down against attacks; apps sandboxed; recommended move to a Linux base.

Threat model:
- Protects you from: a malicious file, app or website taking over the whole computer; a rogue USB device; someone tampering with how the computer starts up.
- Does not protect you from: being identified online (that is Tier 1), an attacker with long unsupervised access to the device, or being tricked into handing over a password.

- Base system: Fedora or Debian with Kicksecure hardening is recommended, with a guided migration from Windows. Windows users get the partial track below.

- Kernel and system: Kicksecure security-misc. Hardened sysctl and boot parameters; unused kernel modules disabled.
- Mandatory access control: AppArmor (Debian, Ubuntu) or SELinux enforcing (Fedora), with profiles for the browser and common apps.
- App sandboxing: Firejail, or Flatpak with Flatseal. Browsers, PDF readers and chat apps sandboxed with restricted permissions.
- USB devices: USBGuard blocks unknown devices until approved.
- Firewall: ufw or firewalld. All incoming traffic denied; outgoing allowed by default.
- Windows track: Microsoft Defender with attack surface reduction rules, Smart App Control, Windows Sandbox, Microsoft Security Baselines, and a standard user account for daily use.
- Secure boot: UEFI Secure Boot and a firmware password; booting from external devices blocked.
- Audit: Lynis (Linux) or Hardening Kitty (Windows) runs after setup, with results shown in `opsec status`.
