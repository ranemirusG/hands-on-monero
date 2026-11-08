# D3. Keys in memory

A running wallet keeps its private keys in RAM, in the clear. You'll read
alice's live process memory and pull a key straight out of it — which is why
responders capture RAM *before* touching the disk, and why disk or wallet
encryption does nothing for a wallet that's currently open.

D1 looked at what a wallet leaves on *disk*. This is what it leaves in *memory*
while it runs.

This needs two terminals (alice open, and the search). To lay them out in one
tmux window:

```bash
tmux new-session -s d3 \; split-window -h    # left: step 1 (alice) · right: step 3 (search)
```

Switch panes with `Ctrl-b o`. Two separate terminals work just as well.

## 1. Have alice open

```bash
scripts/lab-run.sh open alice
```

Leave this terminal running. These wallets have no password, so the keys sit
decrypted in RAM the whole session — and a password wouldn't help here anyway:
it protects the file at rest, but the moment you unlock a wallet its keys are
in memory.

## 2. Grab a key to look for

In alice, print the secret view key — you'll search RAM for it:

```
viewkey
```

Copy the **secret view key** (64 hex chars) and keep alice open.

## 3. Find it in live memory (no extra tools)

From a second terminal. This reads the process's own memory map
(`/proc/PID/maps`) and then each readable region straight out of
`/proc/PID/mem`, looking for the 32 raw bytes the hex key stands for:

```bash
PID=$(pgrep -nf monero-wallet-cli)   # -f: match the full command line
read -rsp 'paste the view key (64 hex): ' KEY; echo
KEY="$KEY" python3 - "$PID" <<'PY'
import os, sys
pid = sys.argv[1]
needle = bytes.fromhex(os.environ["KEY"])     # the 64 hex chars -> 32 raw bytes
hits = 0
with open(f"/proc/{pid}/maps") as maps, open(f"/proc/{pid}/mem", "rb", 0) as mem:
    for ln in maps:
        fld = ln.split()
        if "r" not in fld[1]:                  # readable regions only
            continue
        lo, hi = (int(x, 16) for x in fld[0].split("-"))
        try:
            mem.seek(lo); buf = mem.read(hi - lo)
        except (OSError, OverflowError, ValueError):
            continue
        if needle in buf:
            where = fld[5] if len(fld) > 5 else "[anon]"
            print(f"  found at {fld[0]}  {where}")
            hits += 1
print(f"{hits} hit(s): the 32-byte secret key is in RAM, in the clear")
PY
```

It reports at least one hit, in the heap — the secret is sitting in RAM
unencrypted. This is exactly what `gcore` does internally; you just don't need
it, and you write no dump to disk.

> Reading another process's memory needs ptrace permission. If you get
> `Permission denied`, prefix the line with `sudo` (`sudo KEY="$KEY" python3 …`),
> or relax it once with `sudo sysctl kernel.yama.ptrace_scope=0`.

## 4. Now the spend key

Print `spendkey` in alice and run the same block with that value. The spend key
is **full control of the wallet** — recovered from memory alone, no file, no
password.

## 5. Optional: capture a real memory image

Searching in place proves the point. In a real case you *image* memory first,
then analyse it offline. If you have `gdb`, snapshot this one process the way a
responder would:

```bash
gcore -o /tmp/alice-mem "$PID"                 # writes /tmp/alice-mem.$PID
strings /tmp/alice-mem.$PID | grep -i "$(cat lab/wallets/alice/alice.address.txt)"
shred -u /tmp/alice-mem.$PID                   # it is a file full of live keys
```

A full-host capture (LiME, AVML) grabs *all* of RAM, not one process — same
idea, bigger net. Treat any such dump like the live keys it contains: on
stagenet it's harmless, but build the habit now.

## Highlights

- A wallet's secrets live in RAM, decrypted, the whole time it's open — one
  read of `/proc/PID/mem`, no dump file and no special tool, hands them over.
- At-rest protection (wallet password, disk encryption) buys nothing once the
  wallet is unlocked and running.
- That's the order-of-volatility rule: live IR captures RAM *before* powering
  off or imaging disk, because pulling the plug destroys this evidence.
- It breaks down where the key never reaches host RAM — wallet closed, or a
  hardware wallet that signs on-device and never hands over the spend key.

## IR note

Add to your notes (as in D1): that the wallet process held recoverable key
material in memory, how you captured it (read `/proc/PID/mem`, or imaged it with
gcore/LiME/AVML; which user; root or not), and what you pulled out (view key,
spend key, cached addresses). Note the order-of-volatility rule — RAM first,
then disk: pulling the plug on this host would have destroyed the best evidence.
