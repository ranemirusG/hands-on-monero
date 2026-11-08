# D1. What a wallet leaves on disk

You're the incident responder on a machine that ran Monero wallets (this one).
Find them, and work out what they give you.

## Find the wallets

```bash
find ~ -name '*.keys' -size -20k 2>/dev/null
find ~ -name '*.address.txt' 2>/dev/null -exec sh -c 'echo "$1: $(cat "$1")"' _ {} \;
ls -la ~/.shared-ringdb lab/shared-ringdb 2>/dev/null
```

- `.keys` files are small (a few KB) and can have any name; the cache file
  next to them has the same name without extension.
- `.shared-ringdb` is the wallets' ring database. The GUI always creates
  `~/.shared-ringdb`: its presence alone says a wallet ran here.
- Check cloud-synced folders too (Dropbox, Nextcloud, OneDrive): wallet
  copies uploaded without anyone noticing are a classic finding.

The GUI remembers the last wallet and node:

```bash
grep -i -E 'wallet|node|daemon' lab/gui/monero-storage/settings.ini
```

(A normal install keeps this in `~/.config/monero-project/monero-core.conf`.)

## Find addresses anywhere

Standard addresses are 95 base58 characters (integrated: 106). Stagenet
`5`/`7`, mainnet `4`/`8`:

```bash
ADDR='\b[4578][1-9A-HJ-NP-Za-km-z]{94}\b'
grep -rEoh "$ADDR" lab/logs/ ~/.bitmonero/ 2>/dev/null | sort | uniq -c
grep -Eo "$ADDR" ~/.bash_history 2>/dev/null
```

The lab's CLI logs at level 4, far more than a default install (level 0;
`set_log 0` lowers it live). An address in a log ties the machine to the
wallet even after the wallet is deleted.

## No password = open wallet

Copy alice's keys file, as an attacker would:

```bash
mkdir -p /tmp/stolen && cp lab/wallets/alice/alice.keys /tmp/stolen/
lab/bin/monero/monero-wallet-cli --stagenet --offline \
  --wallet-file /tmp/stolen/alice --password ""
```

```
seed
```

The seed, from the `.keys` file alone. With it, the wallet can be restored
anywhere and emptied. With a password, the question becomes how strong it
is.

```bash
rm -r /tmp/stolen
```

## Passwords on the command line

`scripts/lab-run.sh` passes `--password ""`. With alice open:

```bash
ps -eo pid,args | grep [m]onero-wallet-cli
cat /proc/$(pgrep -nf monero-wallet-cli)/cmdline | tr '\0' ' '; echo
```

Any user on the machine can read this. A real password passed this way (in
a script, systemd unit, cron job or shell history) is a classic finding.
`--password-file` is better.

## What a view key gives you

An address plus its private view key shows every **incoming** payment and
amount, but not reliably the spends (exercise 08). That's what a seized
view-only wallet, or a view key from a suspect or an exchange, gives an
investigator.

## Highlights

- A `.keys` file with no (or a weak) password is the whole wallet: its seed
  restores and empties it anywhere.
- An address in a log, history or config ties the machine to the wallet even
  after the wallet file is gone.
- A password on the command line is readable by any user on the box, and often
  survives in scripts, units, cron and shell history.
- A view key (seized, or from an exchange) reveals every incoming payment and
  amount, but not reliably the spends.

## IR note

Record, as the start of the case file:

- which wallets exist, their addresses, and which are password-protected;
- which node they used — the third party that saw their traffic (D4);
- where addresses turned up off the wallet (logs, history, configs);
- what you could recover without a password (seed, view key) and what a
  password would have cost the attacker.
