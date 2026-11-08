# 05. Restore from the seed, and what a wrong restore height does

Test your backup. Rebuild alice from her seed, first with a restore height
that's too high, then the right one.

## Too high

```bash
scripts/lab-run.sh node              # note the current height
scripts/lab-run.sh restore alice-restored
```

Give it alice's seed, Enter for no passphrase, and the **current** height.
Then:

```
balance
```

**Zero.** It only scans from the restore height on, so it never saw the
earlier payments. The coins are still on the chain.

## Fix it

```
set refresh-from-block-height <alice's restore height>
rescan_bc
balance
```

Now it matches. Too high misses coins; too low only costs time.

## What didn't come back

```
address all
show_transfers
get_tx_key <txid of the payment to bob>
```

- Subaddresses: back (derived from the seed). Their **labels**: gone.
- Address book and notes: gone.
- `get_tx_key`: fails; it lived only in the old cache (exercise 03).

Seeds hold keys, not history.

## Clean up

```
exit
```

```bash
rm -r lab/wallets/alice-restored
```

## Highlights

- Lost the restore height? Use one you're sure is earlier, or a date before
  the wallet existed: the CLI accepts `YYYY-MM-DD`.
