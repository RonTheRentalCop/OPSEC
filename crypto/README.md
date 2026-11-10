# Crypto: keeping it, and keeping it private

Most people who lose cryptocurrency are not hacked by a genius. They type a recovery phrase into a fake website, leave coins on an exchange that freezes or fails, or send to an address that malware swapped in. Most people who lose their privacy do it by buying on an exchange that knows their name and then assuming the coins are anonymous.

This guide is about avoiding both. It is not financial or tax advice. Using crypto privately is legal in most places; using it to hide a crime or to avoid tax you owe is not. See [Legal.md](../Legal.md).

## The two things to understand first

1. **Whoever holds the keys owns the coins.** A recovery phrase (12 or 24 words) is the money. Anyone who sees it can take everything, from anywhere, and nobody can reverse it.
2. **Most blockchains are public forever.** Bitcoin, Ethereum and most others record every payment where anyone can read it. Addresses are not names, but once one address is tied to you, your history and your future payments can be followed from it.

## Where to keep it, best first

| Option | What it is | Use it for |
| --- | --- | --- |
| **1. Offline hardware wallet (recommended)** | A small device that holds your keys and never connects to the internet. It signs payments by QR code or memory card, so the keys never touch your computer. | Anything you would be upset to lose |
| 2. USB or Bluetooth hardware wallet | The same idea, but it plugs into a computer or pairs with a phone. Keys still stay on the device. | Savings, if option 1 is out of reach |
| 3. Software wallet on your own device | An app that keeps the keys on your computer or phone. Only as safe as that device. | Small spending amounts |
| 4. Exchange account | The exchange holds the keys. You hold a promise. | Buying and selling only. Move coins out afterwards |

### 1. Offline hardware wallets

These are the safest option for almost everyone, and the one this guide recommends.

- Examples that work fully offline: Coldcard, Foundation Passport, Keystone, SeedSigner (build it yourself), Blockstream Jade in QR mode.
- Buy **directly from the maker**. Never buy from a marketplace reseller or second-hand, and never use a device that arrives with a recovery phrase already filled in. That is a known scam.
- Think about the delivery address. Hardware wallet makers have leaked customer lists before (Ledger, 2020), and the people on those lists received phishing and threats for years. A parcel locker or work address is better than home.
- Update the firmware only with a file from the maker's own site, and verify it the way the maker describes.
- **Check the address on the device's own screen** before you approve a payment. Malware on a computer can change what the computer shows. It cannot change the device's screen.

### 2. USB and Bluetooth hardware wallets

Trezor, Ledger, BitBox02 and similar. Still far safer than a software wallet, because the keys stay on the device. The weaker points are the cable or radio link and the companion app, which often reports your addresses to the maker's servers. Where the app lets you, connect it to your own node or through Tor.

### 3. Software wallets

Sparrow or Electrum for Bitcoin, Feather for Monero. Download only from the project's own site and verify the signature. Fake wallet apps in app stores and search adverts are one of the most common ways people are robbed.

A software wallet is a reasonable place for an amount you would carry in cash. It is not a reasonable place for savings.

### 4. Exchanges

Kraken, Coinbase, Binance and the rest are for converting money, not for storing it. Exchanges have frozen withdrawals, been hacked and gone bankrupt with customer funds inside (Mt. Gox, FTX). If you use one, turn on two-step login with an authenticator app or a security key, never text messages, and turn on the withdrawal address allow-list.

## Your recovery phrase

- Write it on paper, or stamp it into steel if the amount justifies it. Keep it somewhere that survives fire, water and a burglary.
- **Never** photograph it, type it into a computer or phone, store it in a password manager, email it, or put it in cloud storage.
- **Never** enter it into a website or give it to anyone. No real support agent, wallet update or airdrop will ever ask for it. Every request for it is a theft attempt.
- Do a test recovery once, on the device itself, before you put real money on the wallet. A backup you have not tested is a guess.
- An optional extra passphrase (sometimes called the 25th word) protects you if someone finds the written phrase. Forgetting it loses the coins just as surely, so only use one if you have a plan for remembering it.
- Decide who should be able to recover it if something happens to you, and make sure they can.

## What can be tracked, and by whom

This is the part most people get wrong.

- **Exchanges know exactly who you are.** Kraken, Coinbase and every other regulated exchange check your identity document, and record every deposit, trade and withdrawal against it, along with the device and internet address you used. They keep that for years, report to tax authorities, and hand it over when legally required.
- **Withdrawing links your wallet to your name.** When you move coins from an exchange to your own wallet, the exchange records the destination address. From then on, that address and whatever it pays can be tied back to you.
- **Analysis companies follow the chain.** Firms such as Chainalysis and TRM Labs sell tools that trace payments across addresses. Exchanges and governments use them. A payment made years ago can be analysed with tools that did not exist at the time.
- **Reusing an address ties your payments together.** Anyone you pay, or who pays you, can see everything else that address has done. Use a fresh receiving address every time; good wallets do this for you.
- **Your wallet app can give you away.** Most wallets ask someone else's server about your addresses, which shows that server your addresses and your internet address together. Run your own node, or connect the wallet through Tor.
- **Peer-to-peer apps and "no-KYC" services still see something.** The other person, the payment method and the app's server all learn a little. They reduce what is recorded; they do not make it nothing.
- **Monero hides amounts, senders and receivers by default**, which Bitcoin does not. It is not magic: how you bought it, how you spend it and the timing between the two can still point to you, and many exchanges restrict or have delisted it.

In short: buying on an exchange and withdrawing to your own wallet protects you from the exchange failing. It does **not** make you anonymous. Treat anything that started at an exchange as permanently linked to your name.

## Mistakes that cost people their coins

- Leaving savings on an exchange.
- Keeping the recovery phrase in photos, notes apps or cloud storage.
- Installing a wallet from an advert or an app store search instead of the project's own site.
- Trusting someone who contacts you first. Support staff, recovery services and investment managers who message you are scammers. So is anyone who promises a return.
- Approving a transaction or "connecting a wallet" on a site without reading what it allows. On Ethereum and similar chains, one approval can let a contract drain a token balance later.
- Copying an address without checking it. Clipboard malware swaps in the thief's address. Compare the first and last characters on the hardware wallet's screen.
- Sending a large amount without sending a small test first.
- Sending on the wrong network, or to an exchange deposit address without the required memo.
- Talking about how much you hold. That makes you a target for phishing, SIM swaps and people at your door.
- Using text-message codes on an exchange account. A stolen phone number is enough to take it over.
- Assuming private means untaxed. Selling, swapping and spending are taxable events in many countries. Keep your own records.

## How this fits the OPSEC tiers

| Tier | What to do |
| --- | --- |
| 4: Hygiene | Authenticator app or security key on every exchange account. Unique passwords in Bitwarden. Never store a recovery phrase in Bitwarden. |
| 3: Private | Move savings to a hardware wallet. Keep the VPN on when using exchanges and wallets, so your network does not see which ones you use. |
| 2: Hardened | Keep signing on an offline hardware wallet so a compromised computer cannot spend. Verify every wallet download. |
| 1: Anonymous | Run wallet software inside the sealed VM so it only ever connects through Tor. Never mix coins that are tied to your name with an identity that is meant to be anonymous. |
| 0: Lockdown | Keys live on a device that never goes online. Unsigned and signed transactions cross by QR code or memory card only. |

The sealed VM in Tier 1 ships with Tor Browser only. Wallet software is not installed in it yet.
