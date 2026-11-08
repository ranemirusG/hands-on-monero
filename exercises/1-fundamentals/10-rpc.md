# 10. Bonus: talk to the node from Python

The RPC that wallets, explorers and scripts all use: HTTP + JSON.
`scripts/rpc.py` (standard library only) wraps it.

## By hand

```bash
source lab/settings.env
curl -s "$NODE/json_rpc" -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' | python3 -m json.tool
```

`height` is the block count (newest = `height - 1`). Public nodes run
restricted: read-only questions work, admin ones don't.

| Style | Examples | Path |
|---|---|---|
| JSON-RPC | `get_info`, `get_block_header_by_height`, `get_fee_estimate` | `/json_rpc` |
| Older endpoints | `get_transactions`, `get_outs`, `is_key_image_spent` | own path, e.g. `/get_outs` |

## With rpc.py

```bash
scripts/rpc.py info
scripts/rpc.py block                 # newest block
scripts/rpc.py tx <txid>             # rings, key images, outputs
scripts/rpc.py tx <txid> --raw       # full decoded JSON
scripts/rpc.py outs <index>          # global index -> tx and height
scripts/rpc.py spent <key image>
scripts/rpc.py fee
```

`rpc()` and `other()` in the script are the building blocks.

## Ideas

- **Who got the fee?** `block <height>` of alice's payment, then
  `tx <miner tx hash>`: no ring, one `gen` input, amount in plain sight.
- **Decoy ages.** For each ring member, fetch its height and print its age.
- **Where do my coins appear?** Scan transactions from a start height and
  list rings that contain your global indices.

## Highlights

- Every `tx` or `spent` question tells the node your IP cares about that tx
  or key image. One more reason to run your own node.
