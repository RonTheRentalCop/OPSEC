# OPSEC
OPSEC is an open source tool that sets up privacy and security on your computer, one level at a time. You pick a tier, from everyday safety (Tier 4) to full lockdown (Tier 0), and OPSEC applies the matching settings and tools for you.

**Status: early development.** `opsec up` can apply Tiers 4 to 1 on macOS, Debian, Ubuntu and Fedora, and Tiers 4 to 2 on Windows. So far the tier steps have only been run as a preview (dry run) on macOS; the Linux and Windows versions have not been tested on real machines yet. The Tier 1 sealed VM is new and experimental: on an Apple Silicon Mac its build has been run as far as the Tor lockdown, the Tor Browser signature check and the leak tests, but a complete build and a desktop start have not been confirmed yet, and it has not been run on Linux at all. Try it on a spare computer first.

Contributors are welcome. Message `courtleeoed` on Discord or open an issue.

## Install

One command. It needs `git`, does not ask for your password, and changes no system settings.

```bash
git clone https://github.com/RonTheRentalCop/OPSEC.git ~/.local/share/opsec && ~/.local/share/opsec/install.sh
```

Then try it:

```bash
opsec tiers
```

Why this is a safe way to install:

- The download comes straight from GitHub over an encrypted connection.
- The code is saved on your computer before anything runs, so you can read [install.sh](./install.sh) first. It is short.
- The installer refuses to run as an administrator, and only touches two places: `~/.local/share/opsec` (the code) and `~/.local/bin/opsec` (the command).

If you would rather look before you run, do it in two steps:

```bash
git clone https://github.com/RonTheRentalCop/OPSEC.git ~/.local/share/opsec
```

```bash
less ~/.local/share/opsec/install.sh && ~/.local/share/opsec/install.sh
```

### Install without git

You do not need git, an account, or a package manager to get OPSEC. Each release on the [Releases page](https://github.com/RonTheRentalCop/OPSEC/releases) has a single installer file and a list of checksums.

1. Download `opsec-installer.sh`, `SHA256SUMS` and `SHA256SUMS.sig` into the same folder.
2. Check that the installer matches the checksum list. It should say `OK`:

```bash
shasum -a 256 -c SHA256SUMS --ignore-missing
```

3. Check that the checksum list was signed by the OPSEC release key. This is what protects you if the download page itself is tampered with. Get [keys/allowed_signers](./keys/allowed_signers) from a copy of this repository you already trust, then run the command below. It should say `Good "opsec-release" signature`:

```bash
ssh-keygen -Y verify -f allowed_signers -I opsec-release -n opsec-release -s SHA256SUMS.sig < SHA256SUMS
```

4. Run it:

```bash
bash opsec-installer.sh
```

On Windows, download `opsec-<version>-windows.zip`, unzip the whole folder, and double-click `windows\OPSEC.cmd`. It asks Windows for administrator rights and then walks you through the same questions.

There is no `.exe` on purpose. An `.exe` from an unknown publisher cannot be read before running, is blocked by Windows SmartScreen, and is often flagged by antivirus. A plain script in a zip does the same job and anyone can open it to see what it does.

Maintainers build these files with `scripts/build-release.sh`.

To update, run the installer again. To remove OPSEC completely:

```bash
rm -rf ~/.local/bin/opsec ~/.local/share/opsec
```

## Apply a tier

Run one command, pick a tier, and read the list of changes. Nothing happens until you type `yes`.

```bash
opsec up
```

What happens:

1. OPSEC works out which system you are on and asks which tier you want.
2. It shows every change it will make, and a separate list of things only you can do (such as creating accounts).
3. You type `yes` to go ahead, or anything else to cancel.
4. For Tier 3 and stronger, it asks whether you have a Mullvad account, installs Mullvad VPN or the free Cloudflare WARP first, and waits for you to connect it.
5. It installs and sets up the rest, then tells you what worked, what failed and what is left for you.

To see the plan without changing anything:

```bash
opsec up 4 --dry-run
```

Good to know:

- Run it as your normal user. It asks for your password when it needs to.
- macOS needs [Homebrew](https://brew.sh) to install apps.
- Any file OPSEC replaces is kept next to the original with `.opsec-backup` on the end. `opsec down` puts those back and removes the settings files OPSEC added. It does not uninstall apps or turn off the firewall, updates or VPN.
- OPSEC keeps no log of what you run. `opsec status` checks the live settings instead, and `opsec status --online` also asks Mullvad's and Cloudflare's check pages which address websites see.
- Software sources that OPSEC adds on Linux (Mullvad, Cloudflare, Signal) are only trusted if their signing key matches the fingerprint written in [lib/engine.sh](./lib/engine.sh).
- For Tier 3 and stronger, the VPN is installed first. OPSEC then pauses until the VPN is connected, and re-checks before every step, so your internet provider cannot see which privacy tools are downloaded afterwards. The provider can still see the VPN itself being downloaded. Tier 4 has no VPN, so its downloads are visible.
- OPSEC asks whether you have a Mullvad account. Mullvad VPN is the recommended choice but is paid. If you answer no, OPSEC installs Cloudflare WARP instead, which is free. WARP hides your activity from your internet provider and Wi-Fi, but it has no kill switch and does not hide your location from websites.
- If a VPN is already connected when you start, OPSEC uses it and does not ask.
- OPSEC never encrypts your computer's disk or your own files. If disk encryption is off, it tells you and leaves the decision, and the recovery key, to you. The Tier 1 sealed VM is the one exception: it is always encrypted with a passphrase you choose.
- Some things cannot be automated, such as paid VPN accounts, phone apps and firmware settings. OPSEC lists these at the end instead.
- Tier 0 is a different operating system (Tails or Qubes OS), so `opsec up 0` gives you a checklist and changes nothing.

### Windows

Open PowerShell as administrator (right-click, "Run as administrator") and run:

```powershell
git clone https://github.com/RonTheRentalCop/OPSEC.git "$HOME\opsec"; powershell -ExecutionPolicy Bypass -File "$HOME\opsec\windows\opsec.ps1"
```

It asks the same questions and waits for the same `yes`. It needs `git` and `winget`, which come with current versions of Windows 11. Add `-DryRun` to the end to only see the plan.

On Windows, Tier 1 is a checklist for setting up Whonix yourself. The sealed VM, `opsec status` and `opsec down` are not built for Windows yet.

## The sealed VM (Tier 1)

Tier 1 does not put Tor software on your computer. It builds one encrypted virtual machine and keeps everything anonymous inside it.

```bash
opsec vm create
```

```bash
opsec vm start
```

- A firewall inside the VM drops everything that is not Tor. Apps that are not set up for Tor get no internet, and if Tor stops, everything stops.
- The VPN on your computer must be connected before the VM is downloaded, built or started, so your network sees a VPN and never sees Tor.
- The whole VM is one file encrypted with your passphrase. Tor Browser exists only inside it.
- The desktop account inside has no administrator rights, and there are no shared folders or shared clipboard.
- Logs inside the VM live in memory only and are gone at shutdown.
- Before the build is accepted, the VM tests that direct connections and name lookups are blocked and that Tor works.

What it cannot do: a VM does not hide anything from monitoring software installed on the computer itself, such as school or workplace device management, screen recording or a keylogger. It keeps the anonymous work away from your everyday browser, accounts and network. Do not use a managed computer for this. The computer also still shows that QEMU and OPSEC are installed and that one large encrypted file exists.

Full details, limits and what is not built yet: [tiers/tier1-anonymous.md](./tiers/tier1-anonymous.md).

## Crypto

People lose cryptocurrency, and their privacy, through a small number of repeated mistakes. The [crypto guide](./crypto/README.md) covers:

- where to keep it, with offline hardware wallets first
- how to handle a recovery phrase
- what exchanges such as Kraken and Coinbase record about you, and why withdrawing to your own wallet does not make you anonymous
- the mistakes that cost people their coins

### Where the settings live

| System | File |
| --- | --- |
| macOS | [configs/macos.sh](./configs/macos.sh) |
| Debian and Ubuntu | [configs/debian.sh](./configs/debian.sh) |
| Fedora | [configs/fedora.sh](./configs/fedora.sh) |
| Shared Linux steps | [configs/linux-common.sh](./configs/linux-common.sh) |
| Windows | [windows/opsec.ps1](./windows/opsec.ps1) |
| Sealed VM, on your computer | [lib/vm.sh](./lib/vm.sh) |
| Sealed VM, set up inside it | [vm/provision.sh](./vm/provision.sh) |
| Firefox settings (all systems) | [configs/firefox](./configs/firefox) |

Phones, tablets and other Linux families such as Arch are not supported yet.

# Which tier do I need?

Tiers are numbered like the protection rings in a computer's kernel: **Tier 0 is the innermost and most locked down**, and the numbers get more relaxed as they go up. Tier 4 is the everyday starting point.

Every step toward Tier 0 trades some speed and convenience for more protection. Each tier includes everything in the higher-numbered tiers.

Tier 0 (most secure) <-----------------------> Tier 4 (fastest)

| Tier | Who it is for | Protects you from | Cost |
| --- | --- | --- | --- |
| [0: Lockdown](./tiers/tier0-lockdown.md) | People at serious risk, such as journalists and their sources | A well-funded adversary mapping who you talk to, or seizing your device | Very slow; a different operating system |
| [1: Anonymous](./tiers/tier1-anonymous.md) | People who need to hide who they are online | Websites and network watchers linking your activity to you | Slow browsing inside a sealed VM; strict habits required |
| [2: Hardened](./tiers/tier2-hardened.md) | People who may be targeted, or who handle sensitive work | Someone trying to break into the computer itself | Some apps stop working; best on Linux |
| [3: Private](./tiers/tier3-private.md) | People who do not want to be watched online | Your internet provider, public Wi-Fi, advertisers, a lost or stolen laptop | Slightly slower; some sites ask you to log in more often |
| [4: Hygiene](./tiers/tier4-hygiene.md) | Everyone | Ads, trackers, scam sites, weak passwords, common malware | None you will notice |

Most people only need Tier 4 or Tier 3. Pick the highest-numbered tier that covers what you are worried about.

Each tier has its own page with the full list of tools and settings, plus a plain statement of what it does not protect you from. No tool can promise perfect security or anonymity.

You can also read a tier from the command line:

```bash
opsec tier 4
```

## For maintainers

Releases are signed so that a tampered download page cannot pass off a changed installer.

One time, create the release key with a passphrase, keep the private half off this computer when you are not releasing, and publish the public half:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/opsec-release -C opsec-release
```

```bash
printf 'opsec-release %s\n' "$(cut -d' ' -f1,2 ~/.ssh/opsec-release.pub)" > keys/allowed_signers
```

Commit `keys/allowed_signers`, and post the same line somewhere outside GitHub so people can compare. For each release, tag it and build with the key:

```bash
OPSEC_SIGNING_KEY=~/.ssh/opsec-release scripts/build-release.sh
```

Upload everything in `dist/`, including `SHA256SUMS.sig`. The installer uses the newest `v*` tag when one exists. Every push runs the checks in [.github/workflows/ci.yml](./.github/workflows/ci.yml).

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
