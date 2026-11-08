# 01. Receive from a faucet on a labelled subaddress

Get free stagenet coins on a subaddress made for that payer. A faucet is a
wallet with a web page that sends coins to whoever asks.

## Make the subaddress (alice)

```
address new from faucet
address all
```

Subaddress 1, labelled "from faucet". Subaddresses start with `7` on
stagenet (`8` on mainnet); index 0 is the main address.

Same keys, so the wallet sees payments to all of them, but nobody else can
link two subaddresses of one wallet. Habit: one subaddress per payer.

## Ask the faucet

Paste the subaddress into one of these (search "monero stagenet faucet" if
both are down):

- https://cypherfaucet.com/
- https://stagenet-faucet.xmr-tw.org/

Then in alice:

```
refresh
show_transfers           # the payment, and which subaddress got it
balance                  # total vs unlocked
balance detail           # per subaddress
```

Received coins are **locked for 10 blocks** (~20 minutes).

## The same in bob (GUI)

**Receive** > **Create new address**, label `from faucet`, ask a faucet,
watch **Transactions**.

## Highlights

- The blockchain never shows which subaddress got paid (exercise 02 shows
  what it does hold).
- One subaddress per payer keeps payers apart; everything sent to the main
  address mixes together.
