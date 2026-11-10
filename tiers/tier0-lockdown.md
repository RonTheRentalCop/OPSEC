# Tier 0: Lockdown
Maximum isolation. Built for communicating and hosting without anyone mapping who talks to whom. Convenience is traded away almost entirely.

Includes everything in Tiers 1 to 4.

Goals: traffic analysis resisted; every activity compartmentalized; nothing left behind on shutdown; emergency data destruction available.

Threat model:
- Protects you from: a well-funded adversary working out who you talk to; one compromised app or file exposing everything else; data being recovered from a seized, powered-off device.
- Does not protect you from: being forced to unlock the device, tampered hardware, a device seized while it is on and unlocked, or the people you talk to being compromised. Destroying data you are legally required to keep can be a crime; see [Legal.md](../Legal.md).

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

Note: PGP email is still being considered. It protects the body of a message, but the subject line, sender, recipient and timestamps stay visible, and it is inconvenient to use.

Decision: the P2P messaging service uses 4096-bit RSA keys. See [P2P Messaging Service](../README.md#p2p-messaging-service-planned) in the README.
