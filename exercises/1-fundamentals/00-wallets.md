# 00. Create two wallets

Two independent wallets, so one can pay the other. **alice** lives in the CLI,
**bob** in the GUI.

Run everything from the repo folder.

## alice (CLI)

```bash
scripts/lab-run.sh new alice
```

- Note the **25-word seed**: it rebuilds the whole wallet (keys, addresses,
  coins). On stagenet a text file is fine.
- Wait until it stops printing "Height ...".

At the `[wallet 5...]:` prompt:

```
address              # main address; stagenet starts with 5
restore_height       # the block the wallet was born at: note it with the seed
status               # node, and whether the wallet is caught up
wallet_info          # file, type, network
```

The restore height tells a restored wallet where to start scanning
(exercise 05 shows what a wrong one does).

The wallet has no password but still asks before some commands, and locks
itself after a few idle minutes. Press Enter, or turn both off:

```
set ask-password 0
set inactivity-lock-timeout 0
```

`set` alone lists every setting. Fine on stagenet, never on mainnet: the
keys stay decrypted in memory, and an unlocked wallet is open to anyone at
the keyboard.

Keep this terminal for alice. `exit` saves and closes;
`scripts/lab-run.sh open alice` reopens.

## bob (GUI)

```bash
scripts/lab-run.sh gui
```

1. Language, then **Advanced mode** (Simple mode picks mainnet nodes).
2. Tick **Advanced options** and set the network to **Stagenet**: the
   buttons say "(stagenet)".
3. **Create a new wallet**: name `bob`, location the **full path** of
   `lab/wallets` (printed by `scripts/lab-run.sh gui`).
4. Note the seed and restore height.
5. Password: leave both fields empty (stagenet only).
6. **Connect to a remote node**: address and port from
   `scripts/lab-run.sh node`. Leave "trusted daemon" unticked.

bob's address must start with `5`. If it starts with `9` or `A`, it was
created on testnet: delete it and redo step 2.

## What's on disk

```bash
ls -l lab/wallets/*/
```

| File | What | Secret? |
|---|---|---|
| `alice.keys` | the keys, encrypted with the password | Yes: with no password, a copy is the coins (D1) |
| `alice` | cache: transactions, labels, notes | Leaks your history |
| `alice.address.txt` | main address | No |

Both wallets share `lab/wallets/` and `lab/files/` on one machine and one
user, only to keep the lab simple. In real life they'd be different people
on different machines.

## Highlights

- Only the address is safe to share. The view key reveals every incoming
  payment; the seed and spend key spend the coins.
