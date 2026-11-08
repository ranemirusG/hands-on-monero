#!/usr/bin/env bash
# d2-tmux.sh: a two-window tmux session with every terminal the cryptojacking
# exercise (D2) needs, so you are not juggling shells by hand.
#
# D2 is the only exercise with its own tmux launcher (it has four terminals
# going at once). A few other labs suggest a quick two-pane split inline;
# this one is scripted because there's more to lay out. It is OPTIONAL — D2
# also works with terminals opened by hand.
#
# Window 1 "run" — the live miner, split left/right:
#   fakepool    (left)  the local fake Stratum pool, started for you (127.0.0.1 only)
#   xmrig       (right) the miner, pre-typed but NOT run; this pane has the focus,
#               so you just press Enter to start it. Its console shows the
#               donation phone-home live (or tail lab/logs/xmrig.log).
#
# Window 2 "analysis" — the incident response:
#   IR sweep    a shell for the step-4 sweep (ps / ss / /proc/PID)
#   tcpdump     the loopback/donation capture, pre-typed but NOT run (asks sudo)
#   temp/CPU    live `watch sensors + uptime`, to keep an eye on heat and load
#
# Switch windows with Ctrl-b n / Ctrl-b p (or Ctrl-b 0 and Ctrl-b 1).
#
# Every path below is ABSOLUTE, anchored to this repo via the script's own
# location, so it works no matter which directory you launch it from. It also
# writes an XMRig config.json under lab/ (kept out of git) and points the miner
# at it, so step 4's "find the config.json" has a real artifact to find — the
# file that, on a real case, hands you the pool and the payout address.
#
# Usage:  ./scripts/d2-tmux.sh
# Quit:   Ctrl-C in the running panes, then  tmux kill-session -t d2
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
LAB_HOME=${LAB_HOME:-$REPO_DIR/lab}
SESSION=d2

die() { printf '\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }

command -v tmux    >/dev/null || die "tmux is not installed (sudo apt install tmux)."
command -v tcpdump >/dev/null || die "tcpdump is not installed (sudo apt install tcpdump) — it is required for step 5."
[[ -x $LAB_HOME/bin/xmrig/xmrig ]] || die "XMRig not found. Run ./scripts/get-xmrig.sh first."
[[ -f $REPO_DIR/scripts/fakepool.py ]] || die "scripts/fakepool.py is missing."
addr_file=$LAB_HOME/wallets/alice/alice.address.txt
[[ -f $addr_file ]] || die "alice's address not found ($addr_file). Create the wallets first (run scripts/lab-setup.sh)."
ADDR=$(cat "$addr_file")
mkdir -p "$LAB_HOME/logs"

# Already running? Land on the run window and attach.
if tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux select-window -t "$SESSION:run" 2>/dev/null || true
  exec tmux attach -t "$SESSION"
fi

# Write the miner's config.json under lab/ (regenerated each launch). This is
# the forensic artifact for step 4: it carries the pool and the payout address.
cat > "$LAB_HOME/config.json" <<JSON
{
    "autosave": false,
    "colors": false,
    "donate-level": 99,
    "log-file": "$LAB_HOME/logs/xmrig.log",
    "cpu": { "enabled": true, "max-threads-hint": 50 },
    "pools": [
        { "algo": "rx/0", "url": "127.0.0.1:3333", "user": "$ADDR", "pass": "x", "keepalive": true, "tls": false }
    ]
}
JSON

# The commands each pane will hold (absolute paths throughout).
pool_cmd="python3 '$REPO_DIR/scripts/fakepool.py' --log '$LAB_HOME/logs/fakepool.log'"
xmrig_cmd="'$LAB_HOME/bin/xmrig/xmrig' --config '$LAB_HOME/config.json'"
# Capture the local pool (3333), DNS (53), and the real donation connection to
# donate.v2.xmrig.com — the on-wire trace of the miner phoning home.
tcpdump_cmd="sudo tcpdump -n -A -i any 'port 3333 or port 53 or host donate.v2.xmrig.com'"
temp_cmd="watch -n 2 'sensors 2>/dev/null; uptime'"

# --- Window 1: run — fakepool (left) and xmrig (right), a vertical divider. ---
pool=$(tmux new-session -d -s "$SESSION" -n run -c "$REPO_DIR" -P -F '#{pane_id}')
xmr=$(tmux split-window -h -t "$pool" -c "$REPO_DIR" -P -F '#{pane_id}')

# --- Window 2: analysis (IR sweep / tcpdump / temp-CPU) ---
invs=$(tmux new-window  -t "$SESSION" -n analysis -c "$REPO_DIR" -P -F '#{pane_id}')
tcpd=$(tmux split-window -t "$invs" -c "$REPO_DIR" -P -F '#{pane_id}'); tmux select-layout -t "$SESSION:analysis" tiled >/dev/null
temp=$(tmux split-window -t "$invs" -c "$REPO_DIR" -P -F '#{pane_id}'); tmux select-layout -t "$SESSION:analysis" tiled >/dev/null

# Pane titles (cosmetic; ignored if this tmux is too old to support them).
tmux set -t "$SESSION" pane-border-status top   >/dev/null 2>&1 || true
tmux set -t "$SESSION" pane-border-format ' #{pane_title} ' >/dev/null 2>&1 || true
tmux select-pane -t "$pool" -T 'fakepool'  2>/dev/null || true
tmux select-pane -t "$xmr"  -T 'xmrig'     2>/dev/null || true
tmux select-pane -t "$invs" -T 'IR sweep'  2>/dev/null || true
tmux select-pane -t "$tcpd" -T 'tcpdump'   2>/dev/null || true
tmux select-pane -t "$temp" -T 'temp/CPU'  2>/dev/null || true

# Start the read-only / harmless panes (fake pool, temp view).
tmux send-keys -t "$pool" "$pool_cmd" C-m
tmux send-keys -t "$temp" "$temp_cmd" C-m

# xmrig: pre-typed, NOT run — press Enter to start it.
tmux send-keys -t "$xmr" "clear; echo '>> Press Enter to start XMRig (runs a minute or two, then Ctrl-C):'" C-m
tmux send-keys -t "$xmr" "$xmrig_cmd"

# tcpdump: pre-typed, NOT run (it asks for sudo when you press Enter).
tmux send-keys -t "$tcpd" "clear; echo '>> Press Enter to start the packet capture (asks for sudo):'" C-m
tmux send-keys -t "$tcpd" "$tcpdump_cmd"

# IR sweep: just a prompt in the repo root.
tmux send-keys -t "$invs" "clear; echo 'IR sweep -- run the step 4 sweep here (ps / ss / /proc/PID)'" C-m

# Land on window 1, xmrig pane, so you just press Enter to start.
tmux select-window -t "$SESSION:run"
tmux select-pane -t "$xmr"
exec tmux attach -t "$SESSION"
