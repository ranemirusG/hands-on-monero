# Hands-on Monero

A hands-on lab to see how Monero really works, on Linux, in an afternoon.
You install the official wallets, get free test coins from a faucet, send
them between two wallets, and then take the transactions apart: subaddresses,
one-time addresses, rings and decoys, key images, payment proofs, restoring
from a seed, and signing a transaction on an offline ("cold") wallet.

Then a second track turns the same wallets into an incident: what Monero
activity leaves behind on a host — on disk, in memory, on the wire — and how a
responder would find and read it (DFIR).

Everything runs on **stagenet**, Monero's public test network: same rules
and same software as the real network (mainnet), but the coins are free and
worth nothing. You don't run your own node and there's nothing to sync: the
wallets talk to a public stagenet node.

## What you need

- Linux on x86_64 (tested on Debian 13; any recent distribution should do)
- About 500 MB of disk and an internet connection
- `curl`, `gpg`, `tar`, `bzip2`, `sha256sum`, `python3`
  (`scripts/lab-setup.sh` tells you if one is missing)
- For Part 2 (DFIR): `tcpdump` (used by the packet-capture exercises). `tmux` is
  optional — D2 ships a launcher (`scripts/d2-tmux.sh`) and a few labs suggest a
  quick two-pane split, but separate terminals work everywhere.
- A desktop, for the GUI wallet (the CLI-only exercises work without one:
  `scripts/lab-setup.sh --no-gui`)

## Quick start

```bash
git clone <this repo> hands-on-monero
cd hands-on-monero
scripts/lab-setup.sh
```

`scripts/lab-setup.sh` downloads the official Monero CLI and GUI, **verifies
them** (binaryFate's signature on the list of hashes, then each file's
SHA-256), unpacks them into `lab/` inside the repo (no `sudo`), and picks a
public stagenet node that answers. Then start with
[exercise 00](exercises/1-fundamentals/00-wallets.md).

`scripts/lab-run.sh` opens the wallets the same way every time:

```bash
scripts/lab-run.sh new alice      # create a CLI wallet
scripts/lab-run.sh open alice     # open it again later
scripts/lab-run.sh gui            # start the GUI wallet
scripts/lab-run.sh node           # which node the lab uses, and its height
scripts/lab-run.sh help           # everything else
```

## Exercises

Two tracks. Do **Part 1** in order — each exercise uses what the previous ones
built. **Part 2** is a DFIR track that turns those same wallets into an
incident; do it after Part 1.

### Part 1 — Monero fundamentals

| # | Exercise | Wallets |
|---|---|---|
| 00 | [Create two wallets](exercises/1-fundamentals/00-wallets.md): seed, restore height, no password | CLI + GUI |
| 01 | [Receive from a faucet](exercises/1-fundamentals/01-faucet.md) on a labelled subaddress | CLI + GUI |
| 02 | [Send between your wallets](exercises/1-fundamentals/02-send.md), then read the tx in the wallet and in an explorer | CLI + GUI |
| 03 | [Prove a payment](exercises/1-fundamentals/03-proofs.md) without revealing your keys | CLI + GUI |
| 04 | [Key images and rings](exercises/1-fundamentals/04-rings.md): find your real input among 16 | CLI |
| 05 | [Restore from the seed](exercises/1-fundamentals/05-restore.md), and what a wrong restore height does | CLI |
| 06 | [Integrated addresses](exercises/1-fundamentals/06-integrated.md) and why subaddresses replaced them | CLI + GUI |
| 07 | [Coin control](exercises/1-fundamentals/07-coin-control.md): accounts, `index=`, `freeze`, `sweep_single` | CLI |
| 08 | [Offline signing](exercises/1-fundamentals/08-offline-signing.md): view-only GUI online, cold CLI offline | CLI + GUI |
| 09 | [2-of-2 multisig](exercises/1-fundamentals/09-multisig.md) | CLI |
| 10 | [Talk to the node from Python](exercises/1-fundamentals/10-rpc.md) | — |

### Part 2 — DFIR

| # | Exercise | Wallets |
|---|---|---|
| D1 | [Wallet artifacts on disk](exercises/2-dfir/D1-wallet-artifacts.md): what a wallet leaves on the filesystem | CLI |
| D2 | [Cryptojacking](exercises/2-dfir/D2-cryptojacking.md): a miner on the machine (XMRig against a local fake pool) | CLI |
| D3 | [Keys in memory](exercises/2-dfir/D3-memory.md): pull a live key out of the wallet's RAM | CLI |
| D4 | [What the node sees](exercises/2-dfir/D4-network.md): what your traffic to the node leaks | CLI |

[docs/glossary.md](docs/glossary.md) explains the terms in one line each, and
[docs/troubleshooting.md](docs/troubleshooting.md) covers the usual snags.

## Choices this lab makes, and why

| Choice | Why | On mainnet you'd... |
|---|---|---|
| **Stagenet** | Same rules and version as mainnet, free coins. (Testnet is for Monero's developers: it runs ahead of mainnet and can be reset.) | — |
| **Wallets without a password** | Shorter exercises. Part 2 (D1, D3) shows what it costs: anyone with the wallet file, or the running process, has the coins. | Always use a strong password. |
| **A public remote node** | Nothing to download or sync. | Run your own node, or at least use Tor: a remote node sees your IP, when you're online, and which transactions you broadcast first (D4). It can't see your keys or balance. |
| **No Tor** | One thing less to set up. | Consider it, see above. |
| **Official binaries, verified** | The download is checked against binaryFate's signature, the way Monero recommends. | The same. |

## Safety

- Never type a **mainnet** seed into anything in this lab, and never reuse a
  stagenet seed on mainnet. Make new ones.
- Block explorers offer "decode outputs" and "prove sending" forms. They send
  your private view key or transaction key to the website. Fine on stagenet
  (exercise 02 tries it), never with real money.
- A seed or spend key shown on screen is a seed or spend key leaked. On
  stagenet that's the point; on mainnet it isn't.

## What goes where

| Path | What |
|---|---|
| `scripts/lab-setup.sh` | Installs and verifies everything, picks a node |
| `scripts/lab-run.sh` | Opens wallets (`scripts/lab-run.sh help`) |
| `scripts/rpc.py` | Asks the node questions: block, transaction, rings, key images, fees |
| `scripts/get-xmrig.sh` | Installs and verifies the official XMRig, for the cryptojacking exercise (D2) |
| `scripts/fakepool.py` | A local-only fake mining pool for D2 (listens on `127.0.0.1` only) |
| `scripts/d2-tmux.sh` | Optional tmux layout for D2 |
| `exercises/` | The exercises: `1-fundamentals/` and `2-dfir/` |
| `lab/bin/` | Monero CLI and GUI (`monero`, `monero-gui` link to the current version) |
| `lab/wallets/` | The wallets, one folder each |
| `lab/files/` | Files passed between wallets: outputs, key images, transactions, proofs |
| `lab/logs/` | CLI and GUI wallet logs |
| `lab/gui/monero-storage/` | The lab GUI's settings |
| `lab/shared-ringdb/` | The shared ring database (used by offline signing) |
| `lab/settings.env` | The lab's settings (version, node) |

Everything the lab installs lives under `lab/` in the repo, which is
git-ignored. If you already run Monero (your own node in `~/.bitmonero`,
wallets in `~/Monero`, a GUI with its own settings), none of it is touched:
the lab's GUI keeps its settings in `lab/gui/` (the GUI's portable mode).
Already downloaded the current release?
`scripts/lab-setup.sh --from ~/Downloads/<folder>` reuses the archives and
still verifies them.

To remove the lab: close the wallets and delete the `lab/` folder (or run the
lab's reset).
