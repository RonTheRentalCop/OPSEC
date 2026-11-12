# OPSEC
OPSEC is an open source tool that sets up privacy and security on your computer, one level at a time. You pick a tier, from everyday safety (Tier 4) to full lockdown (Tier 0), and OPSEC applies the matching settings and tools for you.

[![Watch the video](https://youtube.com)](https://youtu.be/b3kNMt3jgnE)

**Status: early development.** The tiers are the plan. The `opsec` command installs today and can explain the tiers, but it does not change any settings on your computer yet.

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

To update, run the installer again. To remove OPSEC completely:

```bash
rm -rf ~/.local/bin/opsec ~/.local/share/opsec
```

# Which tier do I need?

Tiers are numbered like the protection rings in a computer's kernel: **Tier 0 is the innermost and most locked down**, and the numbers get more relaxed as they go up. Tier 4 is the everyday starting point.

Every step toward Tier 0 trades some speed and convenience for more protection. Each tier includes everything in the higher-numbered tiers.

Tier 0 (most secure) <-----------------------> Tier 4 (fastest)

| Tier | Who it is for | Protects you from | Cost |
| --- | --- | --- | --- |
| [0: Lockdown](./tiers/tier0-lockdown.md) | People at serious risk, such as journalists and their sources | A well-funded adversary mapping who you talk to, or seizing your device | Very slow; a different operating system |
| [1: Anonymous](./tiers/tier1-anonymous.md) | People who need to hide who they are online | Websites and network watchers linking your activity to you | Slow browsing; strict habits required |
| [2: Hardened](./tiers/tier2-hardened.md) | People who may be targeted, or who handle sensitive work | Someone trying to break into the computer itself | Some apps stop working; best on Linux |
| [3: Private](./tiers/tier3-private.md) | People who do not want to be watched online | Your internet provider, public Wi-Fi, advertisers, a lost or stolen laptop | Slightly slower; some sites ask you to log in more often |
| [4: Hygiene](./tiers/tier4-hygiene.md) | Everyone | Ads, trackers, scam sites, weak passwords, common malware | None you will notice |

Most people only need Tier 4 or Tier 3. Pick the highest-numbered tier that covers what you are worried about.

Each tier has its own page with the full list of tools and settings, plus a plain statement of what it does not protect you from. No tool can promise perfect security or anonymity.

You can also read a tier from the command line:

```bash
opsec tier 4
```

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
