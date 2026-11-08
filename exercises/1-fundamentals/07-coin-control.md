# 07. Coin control: accounts, `index=`, `freeze`, `sweep_single`

Pick which coins a transaction spends. That decides what an observer could
link together.

First get a few coins into alice on different subaddresses (faucet again
with `address new from faucet 2`, or two small payments from bob).

## Accounts

```
account
account new savings
account switch 1
address
account switch 0
```

An account is a separate pocket: the wallet never mixes accounts in one
transaction. Subaddresses inside one account can be mixed.

## Choose which subaddress pays

```
balance detail
transfer index=2 <bob's subaddress> 0.001
```

Now an amount only two subaddresses together can cover:

```
transfer index=1,2 <bob's subaddress> <amount>
```

It warns you: someone who paid you on both could see both coins in one
transaction and link them to one wallet. Answer `n` unless you mean it.

## Freeze a coin

```
incoming_transfers available verbose
freeze <key image>
frozen <key image>
balance
```

A frozen coin is never picked. `thaw <key image>` releases it.

## Spend exactly one coin

```
sweep_single <key image> <alice's "savings" subaddress>
```

That coin only, minus the fee. `sweep_all` does a whole account.

## Highlights

- Freezing matters for a possibly "tainted" coin, or one set aside for a
  purpose.
