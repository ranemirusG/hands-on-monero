# 04. Key images and rings: find your real input among 16

Every input points at 16 outputs, 1 real and 15 decoys. An observer can't tell
which; you can, because you know your coins.

## Your coins (alice)

```
incoming_transfers verbose
```

Per coin: amount, spent or not, **global index** (its number on the chain)
and **key image**.

A key image comes from the coin's one-time private key. Same coin, same key
image, and the network rejects it a second time: no double spends, without
revealing which ring member was spent.

## The rings of your payment

```
print_ring <txid of the payment to bob>
```

Per input: its key image and 16 global indices. Match each key image with
`incoming_transfers verbose`: that coin's global index is the real one.

From the chain's side, without the wallet:

```bash
scripts/rpc.py tx <txid>
```

Key images, rings (rebuilt from the relative offsets stored in the tx), and
each output's one-time address and global index.

## Where decoys come from

```bash
scripts/rpc.py outs <a few indices from one ring>
```

The block each ring member came from. Wallets favour recent outputs (a
gamma distribution), because real coins tend to be spent soon.

## Ask the network about a key image

```bash
scripts/rpc.py spent <spent key image> <unspent key image>
```

"Spent" or "unspent", nothing about which ring. A view-only wallet uses
exactly this (exercise 08).

## Highlights

- Your spent coin keeps appearing as a decoy in other people's rings, which
  gives an observer more places to consider.
- Seeing a known output inside a ring proves nothing: it's 1 of 16 and may
  be a decoy.
- A key image must be unlinkable to its coin, or it would point straight at
  the real ring member.
