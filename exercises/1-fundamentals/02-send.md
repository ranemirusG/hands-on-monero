# 02. Send between your wallets and read the transaction

alice pays bob, then you read the same transaction from the sender, the
receiver and the public blockchain.

You need alice's faucet coins unlocked (`balance`).

## bob makes a subaddress for alice (GUI)

**Receive** > **Create new address**, label `from alice`. Copy it.

## alice pays it (CLI)

```
transfer <bob's "from alice" subaddress> 0.002
```

Before typing `y`, read:

- **Spending from address index 1**: it pays from one subaddress alone, so
  it doesn't link subaddresses together.
- The **fee**.

Then:

```
show_transfers out
show_transfer <txid>
get_tx_key <txid>        # keep it for exercise 03
```

Change always goes back to alice's index 0.

## bob sees it (GUI)

**Transactions**: it appears on "from alice" within a block or two, locked
for 10 blocks.

## On the blockchain

Open the txid in a stagenet explorer:

- https://stagenet.xmrchain.net/
- https://xmr-stagenet.librenode.com/

| You see | Means |
|---|---|
| Amounts `?` | Hidden (RingCT). Only the fee is public |
| 2 outputs, each a one-time address | One for bob, one change. Neither address appears |
| Inputs with a **ring of 16** | 1 real coin + 15 decoys (exercise 04) |
| **Key image** per input | Blocks double spends without saying which ring member is real |
| Encrypted 8-byte payment ID | A dummy in every 2-output tx, so they all look alike |
| View tag per output | 1 byte that lets wallets skip ~255 of 256 outputs fast |

### Decode it on purpose (stagenet only)

The explorer's **Decode outputs** form takes an address and its private view
key (GUI: **Settings** > **Wallet** > **Show seed & keys**). With bob's, it
shows which output is his and the amount.

You just gave a website the power of bob's view key. Never on mainnet.
**Prove sending** with the tx key is the same from the sender's side.

## The fee

```bash
scripts/rpc.py fee
```

Fee per byte for each priority. You paid the transaction's weight × the
lowest rate. Stagenet blocks are nearly empty, so the lowest is enough.

## Highlights

- Bob's subaddress never appears on the chain: each one-time address is
  derived from it plus alice's random data, and only bob's view key
  recognises it.
- A small payment can still need two input coins: the coin has to cover the
  amount plus the fee.
