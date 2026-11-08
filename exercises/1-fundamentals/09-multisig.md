# 09. Bonus: a 2-of-2 multisig wallet

A wallet that needs two signatures for every spend. You play both parties in
two terminals. Multisig is still experimental — stagenet is the place to try it.

Lay the two terminals out in one tmux window:

```bash
tmux new-session -s ms \; split-window -h    # left: terminal A (ms-a) · right: terminal B (ms-b)
```

Switch panes with `Ctrl-b o`. Two separate terminals work just as well.

Multisig wallets must start empty:

```bash
scripts/lab-run.sh new ms-a        # terminal A (left pane)
scripts/lab-run.sh new ms-b        # terminal B (right pane)
```

In both:

```
set ask-password 0
set enable-multisig-experimental 1
```

## Build it

1. **Both:** `prepare_multisig`. Copy each `MultisigxV2R1...` string to the
   other terminal.
2. **A:** `make_multisig 2 <B's string>`; **B:** `make_multisig 2 <A's string>`.
3. **A:** `exchange_multisig_keys <B's new string>`; **B:** the same with A's.
   Repeat while either says "Another step is needed".
4. **Both:** `address`. Same address on both: the multisig wallet.

## Fund it

Send 0.005 to it from alice or bob. Wait 10 blocks.

## Spend from it

Both CLIs start in `lab/files/`:

1. **A:** `export_multisig_info ms-a-info`; **B:** `export_multisig_info ms-b-info`
2. **A:** `import_multisig_info ms-b-info`; **B:** `import_multisig_info ms-a-info`
3. **A:** `transfer <bob's address> 0.001`. It writes `multisig_monero_tx`,
   signed by A only.
4. **B:** `sign_multisig multisig_monero_tx`, check it, `y`, then
   `submit_multisig multisig_monero_tx`.

On the explorer it looks like any other transaction.

## Highlights

- Each side holds part of every key image, so they swap multisig info before
  every spend.
- 2-of-3 lets any two of three parties spend (e.g. buyer, seller, arbiter).
