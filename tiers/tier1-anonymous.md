# Tier 1: Anonymous
Activity on the open web can't be traced back to you. Speed is no longer a priority, and identities are kept separate.

Includes everything in Tiers 2 to 4.

Goals: real IP address hidden; browser fingerprint shared with other users; anonymous activity sealed off from personal activity; as little left behind as possible.

Threat model:
- Protects you from: websites learning who or where you are; your network seeing what you visit or that you use Tor; your everyday browser, accounts and apps seeing your anonymous activity; someone reading that activity off the computer while the VM is switched off.
- Does not protect you from: your own mistakes, such as logging into a personal account, reusing a username or sharing identifying details. It does not protect you from monitoring software installed on the computer itself, such as device management, screen recording or a keylogger, because that software sees the screen and keyboard whatever runs in the VM. Do not use a computer your school or employer manages. An adversary able to watch large parts of the internet at once may still link traffic by timing.

## The sealed VM

Tier 1 no longer installs Tor software on your computer. Everything anonymous happens inside one virtual machine that OPSEC builds for you.

- Build: `opsec up 1` installs QEMU and builds the VM, or run `opsec vm create` yourself. It is a minimal Debian system with Tor Browser.
- Tor only: a firewall inside the VM drops every connection that does not come from Tor itself. Apps that are not set up for Tor get no internet at all, and there is no name lookup outside Tor. If Tor stops, everything stops.
- Encrypted from the start: the VPN on your computer must be connected before the VM is downloaded, built or started. During the build, only Tor and the firewall are fetched over an ordinary encrypted connection (HTTPS, inside your VPN). The firewall then locks, and the desktop and Tor Browser are fetched through Tor.
- Verified: the Debian image is checked against Debian's published checksum, and Tor Browser against the Tor Project's signing key, before either is used.
- Encrypted at rest: the whole VM is one file, encrypted with a passphrase only you know. Without it nobody can tell that Tor Browser is inside, or what you did with it. There is no recovery if you forget it.
- No administrator: the desktop account has no password and no administrator rights, the administrator account is locked, and remote login is removed. Something that breaks out of the browser cannot change the firewall. Security updates install themselves through Tor.
- No sharing: no shared folders, no shared clipboard, no USB pass-through, no microphone, no camera.
- Few logs: the VM keeps system logs in memory only, keeps no shell history or recent-file lists, and writes no crash dumps. OPSEC itself keeps no record of what you run.
- Clock: if the computer sleeps, the VM corrects its clock within a minute of waking, so Tor reconnects by itself.
- Self-test: before the build is accepted, the VM proves that direct connections and name lookups are blocked and that Tor works. If any test fails, the VM is deleted.

Commands:

- `opsec vm create` builds it.
- `opsec vm start` unlocks and opens it.
- `opsec vm start --amnesic` opens it for one throwaway session. Everything done or saved in the VM that time, including bookmarks, downloads and updates, is discarded at shutdown. Start it the normal way now and then so security updates are kept.
- `opsec vm status` shows whether it is built and whether it can start.
- `opsec vm destroy` deletes it and everything inside.

What the computer still shows: that QEMU and OPSEC are installed, that one large encrypted file exists, and whatever your shell history records. The VPN company can see that you use Tor, but not what you do.

Known quirk: Tor Browser shows a yellow notice that it cannot communicate with the external Tor application. That is expected. The VM deliberately gives the browser no control over Tor, so the "New circuit" button and the circuit display do not work. Browsing is unaffected, and the notice can be closed.

Not built yet: Windows (it gets a Whonix checklist instead), Tor bridges inside the VM, OnionShare, a messenger, and wallet software.

## Other parts of this tier

- Anonymous browser: Tor Browser inside the VM. Set the security level to Safer, or Safest when the stakes are high. No added extensions; window size left at default.
- Network identity: on Linux, the hardware address is randomised on every connection, TCP timestamps are turned off and temporary IPv6 addresses are turned on.
- Separate identities: never log into personal accounts or reuse usernames inside the VM. For a second anonymous identity, use a second computer or Tails, not the same VM.
- Money: see the [crypto guide](../crypto/README.md) before paying for anything from an anonymous identity.

## Known Tor weaknesses and what OPSEC does about them

Tor is strong, but it has well-known weak spots. Most of them come from how it is used rather than from Tor itself.

| Weakness | What OPSEC does |
| --- | --- |
| Your network can see that you use Tor | The VM only starts while the VPN is connected, so the network sees a VPN. Mullvad's kill switch keeps it that way if the VPN drops. WARP has no kill switch, and OPSEC makes you accept that before it continues. |
| Malicious web pages attack the browser with scripts | You are told to set Tor Browser's security level to Safer. OPSEC does not change Tor Browser's settings itself, because a changed browser stands out. |
| A browser exploit reveals your real address | Inside the VM there is no route to the internet except Tor, and the browser has no rights to change that. |
| Extensions and custom settings make your browser unique | OPSEC adds nothing to Tor Browser and reminds you not to either. |
| Downloaded documents contact the internet when opened | Apps in the VM have no internet access except through Tor. Keep downloads inside the VM. |
| Files you share carry hidden details such as names, locations and device models | mat2 is installed in the VM to strip them. |
| Apps other than Tor Browser ignore Tor | In the VM they get no connection at all. |
| Tor software on the computer is evidence | None is installed on the computer. It exists only inside the encrypted VM. |
| Someone watching both ends of the connection can match the timing | Nothing on an ordinary computer fixes this. It is why Tier 0 exists. |
| Logging into a personal account, or reusing a username, links you instantly | No tool can fix this. OPSEC reminds you at the end of every run. |

Note: a VPN you pay for with your real name knows who you are, so Mullvad (which takes anonymous payment) is the better choice here than WARP.

Note: this VM is new and has had far less review than Whonix or Tails. If your safety depends on it, use Tails (Tier 0).
