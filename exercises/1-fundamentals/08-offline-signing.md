# 08. Offline signing: view-only GUI online, cold CLI offline

Spend without the spend key ever touching a network. Split alice in two:

| | **alice-view** (GUI) | **alice-cold** (CLI) |
|---|---|---|
| Has | address + private **view** key | seed: all keys, incl. **spend** |
| Network | online | **offline** (`--offline`) |
| Can | see incoming, build unsigned txs, broadcast | sign |
| Can't | sign, see what was spent | see the blockchain |

Files move through `lab/files/` (in real life: USB stick or QR code).

**Lab shortcut:** here the cold wallet runs on the same online machine,
only to practise the flow. In a real setup it lives on a separate machine
that never connects.

Close alice first (`exit`): both are copies of her.

Why CLI for cold: `--offline` guarantees it never connects. A cold wallet
that synced even once refuses `import_outputs` for good.

## Set up

**alice-cold (CLI):**

```bash
scripts/lab-run.sh restore alice-cold --offline
```

Seed, Enter, alice's restore height. `balance` says **zero**: it has every
key but has never seen the chain.

Get what the view-only wallet needs:

```
address
viewkey          # the "secret" line
```

**alice-view (GUI):** close bob (**Settings** > **Wallet** > **Close this
wallet**), then **Restore wallet from keys or mnemonic seed** > **Restore
from keys**:

- name `alice-view`, location: full path of `lab/wallets`
- address and private view key from above
- spend key: **empty** (that makes it view-only)
- alice's restore height, no password

Its balance is **too high**: it counts every coin alice received, including
spent ones. Spends only show as key images, and computing those needs the
spend key. The cold wallet has to tell it.

## The round trip

In the GUI, tick **Advanced options** on the **Send** page. Use full paths
of `lab/files/...` in every GUI dialog.

1. **View → cold.** GUI: **Outputs** > **Export** to
   `lab/files/alice-outputs`.
2. **Cold.**
   ```
   import_outputs alice-outputs
   export_key_images alice-key-images
   ```
3. **Cold → view.** GUI: **Key images** > **Import**
   `lab/files/alice-key-images`. It asks the node which are spent
   (exercise 04): **the balance drops to the real one.**
4. **View.** GUI **Send**: an address of yours, 0.001, then **Offline
   transaction signing** > **Create** to `lab/files/unsigned_monero_tx`.
5. **Cold.** Never sign what you haven't read:
   ```
   describe_transfer
   sign_transfer
   ```
   It writes `signed_monero_tx`.
6. **View.** **Offline transaction signing** > **Submit**
   `lab/files/signed_monero_tx`. Check the txid in the explorer.

The spend key never left the offline wallet. Each new spend starts again at
step 1.

## Challenge: the other way round

CLI view-only + GUI cold:

```bash
scripts/lab-run.sh view alice-view-cli
```

The GUI cold wallet must never sync: before restoring it, set **Settings** >
**Node** to an address that can't answer (`127.0.0.1` port `1`) and check it
stays "Disconnected". CLI side: `export_outputs all <file>`,
`import_key_images <file>`, `transfer`, `submit_transfer`. Restore the GUI's
node afterwards.

## Highlights

- Stealing the online machine gets the view key: incoming payments and
  balance, not one coin.
- `describe_transfer` matters: a compromised online machine could build a
  payment to someone else. The cold side is what you trust.
- A hardware wallet plays the cold wallet, with USB and a screen instead of
  files.
