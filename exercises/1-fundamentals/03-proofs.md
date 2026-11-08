# 03. Prove a payment without revealing your keys

Prove one fact about a payment (from exercise 02) and nothing else. This is
what you'd use in a dispute, or as evidence.

Proof files land in `lab/files/`, where the CLI wallets start.

## 1. Tx key (sender → anyone)

Every transaction has a random private key, known only to the sender. With
it and the receiver's address, anyone can check what that address got.

```
get_tx_key <txid>
check_tx_key <txid> <tx key> <bob's "from alice" subaddress>
```

It lives only in the sender's wallet cache: restore from seed and it's gone
(exercise 05).

## 2. Tx proof (receiver or sender → anyone)

A signature: "this address received X in this tx", made with your own keys.

Receiver, in bob (GUI): **Advanced** > **Prove/check** > **Prove
transaction**, with the txid and the subaddress. Save the `InProofV2...`
text with no trailing newline:

```bash
printf '%s' 'InProofV2...' > lab/files/bob-in-proof
```

Check it in alice:

```
check_tx_proof <txid> <bob's "from alice" subaddress> bob-in-proof
```

Expect `Good signature`. A trailing newline gives `Wrong signature size`.

Sender side, in alice (writes `monero_tx_proof`, check it in the GUI):

```
get_tx_proof <txid> <bob's "from alice" subaddress>
```

## 3. Spend proof (sender → anyone)

"I spent these inputs", without saying which ring member was real.

```
get_spend_proof <txid>
check_spend_proof <txid> monero_spend_proof
```

## 4. Reserve proof (owner → anyone)

"I hold at least X", e.g. an exchange showing reserves.

```
get_reserve_proof all
check_reserve_proof <alice's main address> monero_reserve_proof
```

It reveals the key images of the coins it covers, so anyone holding it sees
when they're spent. It leaks more than the others.

## Highlights

| Proof | Made by | Proves | Needs |
|---|---|---|---|
| tx key | sender | address got X | tx key (sender's cache only) |
| tx proof | receiver or sender | address got X | own keys |
| spend proof | sender | I spent these inputs | sender's keys |
| reserve proof | owner | I hold ≥ X | owner's keys; reveals key images |

- After a restore from seed, every proof still works except the tx key.
- A tx proof shows that an address received a payment, not who sent it;
  that's the spend proof.
