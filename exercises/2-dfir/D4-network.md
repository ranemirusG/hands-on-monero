# D4. What the node sees

Monero hides the sender, receiver and amount *on-chain*. But your wallet talks
to a node over the network, and whoever runs that node — and anyone watching
the link — sees things the blockchain doesn't. Here you capture that traffic
and read what leaks.

The lab uses a public remote node (convenient, but it sees your side). This is
the reason the lab keeps saying "use your own node, or Tor".

This needs two terminals (the capture, and the wallet). To lay them out in one
tmux window:

```bash
tmux new-session -s d4 \; split-window -h    # left: step 2 (capture) · right: step 3 (wallet)
```

Switch panes with `Ctrl-b o`. Two separate terminals work just as well.

## 1. Which node, and is it encrypted?

```bash
scripts/lab-run.sh node
```

Note the address and port. `http://…` means the RPC travels in clear text;
`https://…` means it's encrypted (you still get the metadata below). Resolve
the IP if you need it: `getent hosts <host>`.

## 2. Start a capture on that link

Second terminal (needs sudo):

```bash
sudo tcpdump -n -A -i any host <NODE_IP> and port <NODE_PORT>
```

## 3. Make the wallet talk

```bash
scripts/lab-run.sh open alice
# then, in the wallet:
refresh                         # syncs — lots of node traffic
transfer <bob_address> 0.1      # broadcasts a tx (see the send exercise)
```

## 4. Read what leaked

On an **HTTP** node, `-A` lets you read the JSON-RPC bodies:

- `get_info` / `get_height` — your wallet polling the node.
- `/sendrawtransaction` — the raw transaction hex, leaving **from your IP**.
  The node now knows that IP broadcast that transaction first.

On an **HTTPS** node the bodies are encrypted, but the capture still shows the
node's IP, that you connected, **when** and for how long, and the traffic
pattern (a sync looks nothing like a single send).

Either way the node operator can log: your IP, your online times, that you're a
Monero wallet, and — the big one — which transactions your IP broadcast first.
That links a network identity (your IP) to a transaction that is otherwise
unlinkable on-chain.

## 5. The fix (not set up here)

Your own node means no third party sees your side. Tor means the node sees a
Tor exit, not your IP. The lab skips both for simplicity — now you've seen the
cost.

## Highlights

- On-chain Monero hides sender/receiver/amount; on the wire, a remote node
  still sees your IP, your online times, and which tx you broadcast first.
- That broadcast-source link is the real deanonymization risk — it ties your IP
  to a specific transaction.
- HTTP node = clear-text JSON-RPC; HTTPS hides the contents but not the
  metadata (IP, timing, volume), which already fingerprints a Monero client.
- Mitigations: your own node, or Tor. The remote node is the convenient, leaky
  default.

## IR note

From a capture (or the node's own logs) you can place a host as a Monero user,
say when it was active and which node it used, and flag transaction broadcasts
from its IP. What you can't get this way: keys, balances, or amounts — those
stay private. Record the node endpoint, the times, and whether the link was
HTTP (contents readable) or HTTPS (metadata only).
