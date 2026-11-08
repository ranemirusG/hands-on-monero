# D2. A miner on the machine: what cryptojacking leaves behind

Switch back to the incident-response chair. In D1 you looked at what
a *wallet* leaves on disk. Here you look at what a *miner* leaves: the single
most common thing found on a compromised Linux server, cloud instance or
container is a Monero miner someone else put there (**cryptojacking**).

You will run the real tool attackers use (XMRig), point it at a harmless local
stand-in for a pool, and then investigate your own machine as if you had been
called to the incident: find the process, its configuration, its network
connections and how it would persist, and write it up.

Nothing here mines real coins or pays anyone. The miner talks only to a fake
pool on `127.0.0.1`.

## What a miner is, and isn't

A miner is **not** a wallet. It holds no keys. It only needs:

- a **pool** (or a node) to get work from and send results to;
- a Monero **address** to tell the pool who to pay.

That is the whole reason cryptojacking is so common: the attacker drops a
single ~5 MB binary and a short config with *their* address. No wallet, no
node, no keys on your machine. So in an investigation you will find the miner,
its config and its traffic, but **never the wallet** — that stays with the
attacker. The address is your main lead (see "The IR note" below).

## Safety and honesty for this exercise

- **We use the official XMRig, unmodified, and verify it** (step 1), the same
  way `scripts/lab-setup.sh` verifies Monero. Trusting a binary is itself an IR
  skill.
- **The miner never touches a wallet.** It holds no keys, points at a local
  fake pool on `127.0.0.1`, and pays a stagenet address. Nothing it mines there
  is worth anything.
- **One real-network exception — the donation.** The official build donates
  part of its hashing to XMRig's developers by connecting out to
  `donate.v2.xmrig.com` and mining real mainnet Monero for them (1% by
  default). That funds the project and is legitimate; it never touches your
  wallet. We run with `--donate-level 99` so that phone-home fires within about
  a minute instead of 40+ — it's the artifact step 5 is about. The connection
  really goes out, so you're briefly donating real hashrate: run it a minute or
  two to watch it, then stop. **If you ever run XMRig for real, leave the
  donation on — support the project, don't strip it.**
- Everything lives under `lab/`, so `scripts/lab-run.sh reset --all` removes it.

## 1. Get XMRig and verify it

The quick way is the lab's installer, which does for XMRig exactly what
`scripts/lab-setup.sh` does for Monero: it downloads the official Linux build, checks the
XMRig signing key's fingerprint, verifies the signed `SHA256SUMS`, confirms the
download's hash, and unpacks it under `lab/bin/`. It installs the official
binary unmodified and **never runs the miner**:

```bash
./scripts/get-xmrig.sh
```

That leaves the binary at `lab/bin/xmrig/xmrig` (a symlink to
`lab/bin/xmrig-6.26.0/`). Continue with the terminals below once it finishes.

If you'd rather walk the whole trust chain by hand once — worth doing — do it
manually instead. Download the official Linux build and its checksums from the
project's GitHub releases (https://github.com/xmrig/xmrig/releases):

```bash
mkdir -p lab/bin/xmrig-dl && cd lab/bin/xmrig-dl
# Download (adjust the version to the current release):
V=6.26.0
curl -fLO https://github.com/xmrig/xmrig/releases/download/v$V/xmrig-$V-linux-static-x64.tar.gz
curl -fLO https://github.com/xmrig/xmrig/releases/download/v$V/SHA256SUMS
```

Check the download against the published checksum:

```bash
sha256sum --ignore-missing -c SHA256SUMS
```

You should see `xmrig-$V-linux-static-x64.tar.gz: OK`. If it does not say OK,
stop: the file is not what the project published.

The XMRig releases are also GPG-signed. If you want the full chain, import the
signing key listed on the release page and verify the `SHA256SUMS` signature,
exactly as you did for binaryFate in `scripts/lab-setup.sh`. Then unpack (the archive
extracts to a `xmrig-$V/` folder):

```bash
tar xzf xmrig-$V-linux-static-x64.tar.gz -C ..
cd ../../.. && ls lab/bin/xmrig-$V/
```

(`xmrig` is a statically linked binary; it needs no install and no root to
run at a normal priority. The one-time "MSR" / huge-pages tuning it suggests
needs root and only raises the hashrate — skip it for the lab.)

### Terminals: by hand, or one tmux window

Steps 2–5 run in several terminals at once: the fake pool (step 2), the miner
(step 3), an IR shell (step 4), and a packet capture (step 5).

**Without tmux (the default).** Just open those terminals yourself and follow
steps 2–5 in order. Nothing here needs tmux.

**With tmux (optional).** If you have it, the lab ships a launcher that lays it
all out in two windows:

```bash
./scripts/d2-tmux.sh
```

- **Window `run`:** the fake pool (started for you) and the miner (pre-typed,
  press Enter to start). The miner's console shows the donation phone-home live.
- **Window `analysis`:** an IR-sweep shell, the `tcpdump` capture (pre-typed,
  asks sudo on Enter), and a live temperature/CPU view.

Switch windows with `Ctrl-b n` / `Ctrl-b p`. It uses absolute paths (runs from
any directory) and writes the miner's `config.json` under `lab/` (see step 4).
Quit with `Ctrl-C` in the running panes, then `tmux kill-session -t d2`.

## 2. Start the fake pool

In its own terminal, from the repo folder:

```bash
python3 scripts/fakepool.py --log lab/logs/fakepool.log
```

It listens on `127.0.0.1:3333`, prints every message it gets, and mines
nothing. Leave it running. `scripts/fakepool.py` is a ~150-line stub; read it,
it is part of the lesson (it is roughly what the pool side of a miner looks
like).

## 3. Run XMRig at the fake pool

In another terminal, use alice's address as the payout address, so the lab is
self-contained (on a real incident this would be the attacker's address):

```bash
ADDR=$(cat lab/wallets/alice/alice.address.txt)
lab/bin/xmrig-6.26.0/xmrig \
  --url 127.0.0.1:3333 \
  --user "$ADDR" \
  --pass x \
  --cpu-max-threads-hint=50 \
  --no-color \
  --donate-level 99 \
  --log-file lab/logs/xmrig.log
```

XMRig prints its config, connects, logs in, spends a few seconds building the
RandomX dataset, and starts hashing. The fake-pool terminal shows the
`LOGIN` line with the address, then `SHARE` lines. On an X220, expect a few
hundred hashes/second and the CPU fans to spin up. Let it run a minute or two,
enough to investigate it while it is live.

## 4. Investigate the live process

This is the incident-response sweep. Do it from a third terminal.

**The process and its CPU:**

```bash
ps -eo pid,pcpu,comm,args | grep [x]mrig
top -b -n1 | head -12          # xmrig at the top, cores near 100%
```

**Where the binary really is, and what it is** (the process name can be
faked; the path and hash cannot):

```bash
PID=$(pgrep -n xmrig)
ls -l /proc/$PID/exe                       # the real binary path
cat  /proc/$PID/cmdline | tr '\0' ' '; echo   # the exact command line + address
ls -l /proc/$PID/cwd                       # where it runs
sha256sum /proc/$PID/exe                   # identify the binary
```

**Its network connections** (the miner-to-pool link):

```bash
ss -tnp | grep xmrig            # the TCP connection to 127.0.0.1:3333
```

**Its configuration.** A miner keeps its settings in a `config.json` — the one
file that, on a real case, hands you the pool and the attacker's address. If
you launched with `./scripts/d2-tmux.sh`, it wrote one at `lab/config.json`
and pointed XMRig at it. If you ran XMRig by hand with only command-line flags,
add `--config lab/config.json` to make it create one. Either way:

```bash
find . -name config.json 2>/dev/null       # where the miner's config lives
grep -E 'url|user' lab/config.json          # the pool and the payout address
```

## 5. See the "phone home"

A miner on a host reaches out: to its pool, and — with the official build — to
XMRig's donation server. That outbound traffic is the classic network signal of
cryptojacking. You'll watch both go out.

Capture the loopback pool traffic, the DNS lookups, and the donation connection
in a fourth terminal (sudo only for the capture):

```bash
sudo tcpdump -n -A -i any 'port 3333 or port 53 or host donate.v2.xmrig.com'
```

> `tcpdump` is part of the lab's toolset — install it with
> `sudo apt install tcpdump` if `scripts/lab-setup.sh` didn't.

On the loopback (`port 3333`) you'll see the Stratum JSON in clear text: the
`login` with alice's address, the `job`, the `submit` shares. That clear-text
login is the classic pcap finding in a real cryptojacking case.

For the donation, within about a minute (`--donate-level 99`) you'll see the DNS
lookup for `donate.v2.xmrig.com` and then a real TCP connection to it — XMRig
switching to the dev pool to mine mainnet for its developers. The same switch
shows up in `lab/logs/xmrig.log` as a new job from the donation host. That
outbound connection is exactly what an IDS or endpoint agent flags as
"possible cryptojacking".

> The deeper lesson: don't trust the miner's own log. A *failed* donate (host
> unreachable) logs **nothing** — XMRig runs its donation client in quiet mode
> (`FailoverStrategy(m_pools, …, true)` in `DonateStrategy.cpp`, with error logs
> gated behind `if (!isQuiet())`). And an attacker's recompiled build often
> strips the donation entirely. The reliable catch is the **network** and the
> sustained full-core CPU, not what the process chooses to print.

> On a monitored network (work, campus) the pool and donation connections are
> what triggers "possible cryptojacking" alerts — how real miners get caught.
> Run the lab on a machine and network you control, and expect those connections
> to light up any monitoring: that's the point.

Stop XMRig (Ctrl-C) and the pool (Ctrl-C) when done.

## 6. Where a real miner would hide to survive a reboot

You did not install persistence, but an IR sweep always checks the usual
places. Look at them so you know them:

```bash
crontab -l 2>/dev/null; ls -la /etc/cron.* 2>/dev/null
systemctl --user list-units 'xmr*' '*mine*' 2>/dev/null
ls -la ~/.config/autostart/ 2>/dev/null
grep -riE 'xmrig|stratum|donate' ~/.bashrc ~/.profile ~/.bash_history 2>/dev/null
```

Real cryptojackers also rename the binary (`kworker`, `systemd-logind`...),
hide it in `/tmp` or `/dev/shm`, and sometimes install a cron that re-downloads
it. The lesson: a name proves nothing; check `/proc/PID/exe`, the hash and the
behaviour.

## 7. Why a hash IOC is not enough

You identified the binary by its SHA-256. On a real case the attacker's XMRig
is often recompiled (different donation, renamed, config baked in), so its
hash matches no public release. A hash-only indicator misses it. What survives
recompilation is **behaviour and content**:

```bash
strings lab/bin/xmrig-6.26.0/xmrig | grep -iE 'randomx|stratum|donate|xmrig' | head
```

Those strings, the RandomX usage, the Stratum traffic pattern (a `submit`
every few seconds), and sustained full-core CPU are what a good detection
(for example a YARA rule, or an EDR behavioural rule) keys on instead.

## The IR note

Write it up as in D1, now for a "miner found on this host":

- **What is running:** the binary (path, hash), its command line, since when,
  CPU cost.
- **The lead:** the payout address from the config / cmdline / pcap. Note what
  it does and does not give you — it cannot be followed on-chain (Monero hides
  that), but it can be searched in threat-intel, matched across incidents, and
  taken to the **pool**, which does see which IPs mined to it and what it paid.
  The pool is the equivalent of the lab's "remote node that sees your IP",
  only more so.
- **Blast radius / containment:** the outbound connections (pool, donation),
  and that isolating the host from the network stops the mining without
  needing to kill the process first — useful when you want to keep it live for
  analysis.
- **Persistence:** which of the locations in step 6 were used (none, here).
- **How a real one would differ:** renamed/hidden binary, a recompiled build
  with no matching hash, an attacker address, real persistence, and a dropper
  that brought it in — which is the thread you would pull next.

## Check yourself

- Why is there no wallet to recover on the victim machine, even though the
  miner clearly knows an address?
- Your EDR only has the SHA-256 of the official XMRig release. Name two ways
  the same tool would still run undetected, and two things you would detect it
  by instead.
- The miner connects out to `donate.v2.xmrig.com`. What is that connection and
  why is it there — and why is it still a useful detection signal even though
  it's legitimate?
