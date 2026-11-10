# Tier 1: Anonymous
Activity on the open web can't be traced back to you. Speed is no longer a priority, and identities are kept separate.

Includes everything in Tiers 2 to 4.

Goals: real IP address hidden; browser fingerprint shared with other users; anonymous activity isolated from personal activity.

Threat model:
- Protects you from: websites learning who or where you are; your network seeing what you visit; your anonymous activity being linked to your real identity.
- Does not protect you from: your own mistakes, such as logging into a personal account, reusing a username or sharing identifying details. Your network can still see that you use Tor unless you use a bridge. An adversary able to watch large parts of the internet at once may still link traffic by timing.

- Anonymous browser: Tor Browser. Security level Safer by default, Safest offered. No added extensions; window size left at default.

- System isolation: Whonix Gateway and Workstation VMs force all workstation traffic through Tor. Runs in VirtualBox or KVM, including on Windows hosts.

- Leak protection: host firewall rules block any traffic from the anonymous environment that bypasses Tor.

- Censorship bypass: Tor bridges (obfs4, Snowflake), offered when Tor is blocked on the network.

- Separate identities: a separate browser and VM per identity. The first-run guide says never to log into personal accounts or reuse usernames here.

- Metadata removal: mat2 strips metadata from files before sharing.

- Anonymous messaging: SimpleX Chat or Briar, no phone number required.

Note: Tor is not routed through a VPN or WARP by default. That adds another party who can see your traffic.
