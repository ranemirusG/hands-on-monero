#!/usr/bin/env python3
"""Ask a Monero stagenet node questions over its RPC (HTTP + JSON).

The node is the one in lab/settings.env (written by scripts/lab-setup.sh), unless
--node or the NODE environment variable says otherwise. Public nodes run in
restricted mode: they answer these read-only questions but no admin ones.

    rpc.py info                     # height, sync state, version
    rpc.py block [HEIGHT]           # block header (default: newest block)
    rpc.py tx TXID                  # a transaction, decoded (rings, outputs...)
    rpc.py outs INDEX [INDEX ...]   # global output index -> one-time address, tx, height
    rpc.py spent KEY_IMAGE [...]    # has this key image been spent?
    rpc.py fee                      # fee per byte for each priority
    rpc.py check                    # exit 0 if the node is a synced stagenet node

Only the Python standard library is used. rpc() and other() are the
building blocks for your own scripts.
"""
import argparse
import json
import os
import sys
import urllib.request
from pathlib import Path

# The lab folder: $LAB_HOME if set, else lab/ in this repo (the parent of scripts/).
LAB_HOME = Path(os.environ.get("LAB_HOME") or Path(__file__).resolve().parent.parent / "lab")
LAB_ENV = LAB_HOME / "settings.env"
TIMEOUT = 15


def node_from_env():
    if os.environ.get("NODE"):
        return os.environ["NODE"]
    if LAB_ENV.exists():
        for line in LAB_ENV.read_text().splitlines():
            if line.startswith("NODE="):
                return line.split("=", 1)[1].strip()
    sys.exit(f"No node configured: {LAB_ENV} is missing. Run scripts/lab-setup.sh first, or pass --node URL.")


def base_url(node):
    return node if "://" in node else "http://" + node


def post(url, body):
    req = urllib.request.Request(url, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return json.load(r)


def rpc(node, method, params=None):
    """JSON-RPC 2.0 method on /json_rpc (get_info, get_block_header_by_height...)."""
    body = {"jsonrpc": "2.0", "id": "0", "method": method}
    if params:
        body["params"] = params
    reply = post(base_url(node) + "/json_rpc", body)
    if "error" in reply:
        raise RuntimeError(reply["error"].get("message", reply["error"]))
    return reply["result"]


def other(node, path, body):
    """The older endpoints with their own path (/get_transactions, /get_outs...)."""
    return post(base_url(node) + "/" + path, body)


def show(obj):
    print(json.dumps(obj, indent=2))


def cmd_info(node, args):
    i = rpc(node, "get_info")
    nettype = i.get("nettype") or ("stagenet" if i.get("stagenet") else "?")
    print(f"node      {node}")
    print(f"network   {nettype}")
    print(f"height    {i['height']:,}  (newest block is {i['height'] - 1:,})")
    print(f"synced    {i.get('synchronized')}")
    print(f"version   {i.get('version', '?')}")
    print(f"tx pool   {i.get('tx_pool_size')} transactions waiting")


def cmd_block(node, args):
    height = args.height
    if height is None:
        height = rpc(node, "get_block_count")["count"] - 1
    h = rpc(node, "get_block_header_by_height", {"height": height})["block_header"]
    print(f"height    {h['height']:,}")
    print(f"hash      {h['hash']}")
    print(f"time      {h['timestamp']}")
    print(f"txs       {h['num_txes']} (plus the miner transaction)")
    print(f"reward    {h['reward'] / 1e12:.12f} XMR (base reward + fees)")
    print(f"miner tx  {h['miner_tx_hash']}")


def cmd_tx(node, args):
    r = other(node, "get_transactions", {"txs_hashes": [args.txid], "decode_as_json": True})
    if not r.get("txs"):
        sys.exit(f"Transaction not found: {r.get('missed_tx', args.txid)}")
    t = r["txs"][0]
    tx = json.loads(t["as_json"])
    print(f"txid           {t['tx_hash']}")
    print(f"block height   {t.get('block_height', 'in the pool (unconfirmed)')}")
    print(f"fee            {tx.get('rct_signatures', {}).get('txnFee', 0) / 1e12:.12f} XMR")
    for n, vin in enumerate(tx["vin"]):
        if "key" not in vin:
            print(f"input {n}: {list(vin)[0]} (coinbase)")
            continue
        key = vin["key"]
        # key_offsets are relative: each is the distance from the previous one.
        absolute, total = [], 0
        for off in key["key_offsets"]:
            total += off
            absolute.append(total)
        print(f"input {n}: key image {key['k_image']}")
        print(f"         ring of {len(absolute)} (global output indices): {absolute}")
    indices = t.get("output_indices", [])
    for n, vout in enumerate(tx["vout"]):
        target = vout["target"]
        if "tagged_key" in target:      # since 2022: output key + 1-byte view tag
            key, tag = target["tagged_key"]["key"], target["tagged_key"]["view_tag"]
        else:
            key, tag = target.get("key", target), "-"
        idx = indices[n] if n < len(indices) else "?"
        print(f"output {n}: one-time address {key}  view tag {tag}  global index {idx}")
    if args.raw:
        show(tx)


def cmd_outs(node, args):
    r = other(node, "get_outs", {"outputs": [{"amount": 0, "index": i} for i in args.index],
                                 "get_txid": True})
    for i, o in zip(args.index, r.get("outs", [])):
        print(f"index {i}: height {o['height']:,}  tx {o['txid']}  one-time address {o['key']}")


def cmd_spent(node, args):
    r = other(node, "is_key_image_spent", {"key_images": args.key_image})
    meaning = {0: "unspent", 1: "spent in a block", 2: "spent in a tx waiting in the pool"}
    for ki, s in zip(args.key_image, r.get("spent_status", [])):
        print(f"{ki}  {meaning.get(s, s)}")


def cmd_fee(node, args):
    r = rpc(node, "get_fee_estimate")
    fees = r.get("fees") or [r["fee"]]
    names = ["unimportant (1)", "normal (2)", "elevated (3)", "priority (4)"]
    for name, f in zip(names, fees):
        print(f"{name:16} {f:>10,} piconero per byte")
    print(f"rounded up to a multiple of {r.get('quantization_mask', 1):,} piconero")


def cmd_check(node, args):
    i = rpc(node, "get_info")
    if not (i.get("stagenet") or i.get("nettype") == "stagenet"):
        sys.exit("not a stagenet node")
    if not i.get("synchronized", True) or i.get("busy_syncing"):
        sys.exit(f"still syncing, height {i['height']:,}")
    print(f"stagenet, synced, height {i['height']:,}")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--node", help="node URL, e.g. http://node.example.org:38089")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("info").set_defaults(fn=cmd_info)
    s = sub.add_parser("block"); s.add_argument("height", type=int, nargs="?"); s.set_defaults(fn=cmd_block)
    s = sub.add_parser("tx"); s.add_argument("txid"); s.add_argument("--raw", action="store_true",
                                                                       help="also print the full JSON")
    s.set_defaults(fn=cmd_tx)
    s = sub.add_parser("outs"); s.add_argument("index", type=int, nargs="+"); s.set_defaults(fn=cmd_outs)
    s = sub.add_parser("spent"); s.add_argument("key_image", nargs="+"); s.set_defaults(fn=cmd_spent)
    sub.add_parser("fee").set_defaults(fn=cmd_fee)
    sub.add_parser("check").set_defaults(fn=cmd_check)
    args = p.parse_args()
    node = args.node or node_from_env()
    try:
        args.fn(node, args)
    except (OSError, ValueError, KeyError, RuntimeError) as e:
        sys.exit(f"{type(e).__name__}: {e}")


if __name__ == "__main__":
    main()
