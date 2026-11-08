#!/usr/bin/env bash
# lab-setup.sh: install the Hands-on Monero lab.
#
#   1. downloads the official Monero CLI and GUI for Linux (x86_64);
#   2. verifies them: the list of hashes must carry a valid signature from
#      binaryFate (the Monero release maintainer), and each download must
#      match its hash in that list;
#   3. unpacks them into the lab folder (no sudo, nothing system-wide);
#   4. picks a public stagenet node that answers and is synced;
#   5. writes the lab's settings to lab/settings.env, which scripts/lab-run.sh reads.
#
# Usage:
#   scripts/lab-setup.sh                  # everything
#   scripts/lab-setup.sh --no-gui         # CLI only (e.g. a server without a desktop)
#   scripts/lab-setup.sh --node URL       # use this node instead of probing the list
#   scripts/lab-setup.sh --from DIR       # reuse release archives already in DIR (e.g.
#                                      # ~/Downloads); they're verified all the same
#
# Run it again at any time: finished steps are skipped, and it re-checks the
# node. The lab folder is lab/ inside this repo, unless LAB_HOME says otherwise.
#
# It only writes inside lab/. An existing Monero install, node
# (~/.bitmonero) or wallets (~/Monero) are left alone.
set -euo pipefail

# The repo folder: the parent of scripts/, wherever the script is run from.
REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
LAB_HOME=${LAB_HOME:-$REPO_DIR/lab}

# binaryFate's key, and the fingerprint it must have. The fingerprint is the
# trust anchor: it's published on getmonero.org and in the Monero repository,
# so the key file itself can come from anywhere.
BINARYFATE_FP=81AC591FE9C4B65C5806AFC3F0AF4D462A0BDF92
KEY_URL=https://raw.githubusercontent.com/monero-project/monero/master/utils/gpg_keys/binaryfate.asc
HASHES_URL=https://www.getmonero.org/downloads/hashes.txt
DOWNLOADS_URL=https://downloads.getmonero.org

# Public stagenet nodes, tried in order. Public nodes come and go: if none
# answers, find a current one on https://monero.fail/?nettype=stagenet and
# run scripts/lab-setup.sh --node URL.
NODES=(
  https://stagenet.xmr.kernal.eu:38089
  http://node.monerodevs.org:38089
  http://node2.monerodevs.org:38089
  http://node3.monerodevs.org:38089
)

with_gui=1
from_dir=
node=${NODE:-}

die()  { printf '\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }
step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[32mOK\033[0m %s\n' "$*"; }

usage() { sed -n '2,/^[^#]/{/^#/{s/^# \{0,1\}//;p}}' "$0"; }

while (($#)); do
  case $1 in
    --no-gui) with_gui=0 ;;
    --node)   [[ $# -ge 2 ]] || die "--node needs a URL, e.g. --node http://node.example.org:38089"
              node=$2; shift ;;
    --from)   [[ $# -ge 2 && -d ${2:-} ]] || die "--from needs a folder that holds the .tar.bz2 archives"
              from_dir=$2; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1 (see scripts/lab-setup.sh --help)" ;;
  esac
  shift
done

# --- 0. Checks -------------------------------------------------------------

step "Checking this machine"

[[ $(uname -s) == Linux ]] || die "This lab is for Linux."
[[ $(uname -m) == x86_64 ]] || die "The official Monero GUI is built for x86_64 only (this machine is $(uname -m))."

missing=()
for cmd in curl gpg tar bzip2 sha256sum python3 tcpdump; do
  command -v "$cmd" >/dev/null || missing+=("$cmd")
done
if ((${#missing[@]})); then
  echo "Missing programs: ${missing[*]}" >&2
  echo "On Debian/Ubuntu:  sudo apt install curl gnupg bzip2 coreutils python3 tcpdump" >&2
  echo "On Fedora:         sudo dnf install curl gnupg2 bzip2 coreutils python3 tcpdump" >&2
  exit 1
fi
ok "Linux x86_64, all required programs present"

mkdir -p "$LAB_HOME"/{downloads,bin,files,logs,wallets}
chmod 700 "$LAB_HOME/wallets"
ok "Lab folder: $LAB_HOME"

# --- 1. Verify the list of hashes ------------------------------------------

step "Verifying the signed list of hashes"

# A throwaway keyring, so nothing is added to your own GnuPG setup.
GNUPGHOME=$(mktemp -d)
export GNUPGHOME
trap 'rm -rf "$GNUPGHOME"' EXIT

curl -fsSL "$KEY_URL" -o "$GNUPGHOME/binaryfate.asc"
gpg --batch --quiet --import "$GNUPGHOME/binaryfate.asc" 2>/dev/null
gpg --batch --with-colons --fingerprint | grep -q "^fpr:*$BINARYFATE_FP:" \
  || die "The downloaded key doesn't have binaryFate's fingerprint. Stop and investigate."
ok "binaryFate's key has the expected fingerprint $BINARYFATE_FP"

curl -fsSL "$HASHES_URL" -o "$LAB_HOME/downloads/hashes.txt"
# --decrypt writes out only the part that is really signed, so nothing
# appended to the file outside the signature can sneak into the hash check.
rm -f "$LAB_HOME/downloads/hashes.verified.txt"
gpg --batch --status-file "$GNUPGHOME/status" \
    --output "$LAB_HOME/downloads/hashes.verified.txt" \
    --decrypt "$LAB_HOME/downloads/hashes.txt" 2>/dev/null || true
grep -q "^\[GNUPG:\] VALIDSIG .*$BINARYFATE_FP" "$GNUPGHOME/status" \
  || die "hashes.txt is NOT validly signed by binaryFate. Do not use these downloads."
ok "hashes.txt is signed by binaryFate"

HASHES=$LAB_HOME/downloads/hashes.verified.txt
if [[ -z ${MONERO_VERSION:-} ]]; then
  MONERO_VERSION=$(grep -oE 'monero-linux-x64-v[0-9.]+[0-9]\.tar\.bz2' "$HASHES" \
                   | sed -E 's/^monero-linux-x64-v(.*)\.tar\.bz2$/\1/' | sort -V | tail -n 1)
fi
[[ -n $MONERO_VERSION ]] || die "Couldn't find the current version in hashes.txt."
ok "Current version: $MONERO_VERSION"

# --- 2. Download, check and unpack -----------------------------------------

# install_release FILE URL LINK: FILE from URL, linked as bin/LINK
install_release() {
  local file=$1 url=$2 link=$3
  local path=$LAB_HOME/downloads/$file

  step "Installing $file"
  if [[ ! -f $path && -n $from_dir && -f $from_dir/$file ]]; then
    cp "$from_dir/$file" "$path"
    ok "Copied from $from_dir (checked below like a download)"
  fi
  if [[ ! -f $path ]]; then
    curl -fL --progress-bar "$url" -o "$path.part"
    mv "$path.part" "$path"
  fi

  local expected actual
  expected=$(awk -v f="$file" '$2 == f {print $1}' "$HASHES")
  [[ -n $expected ]] || die "$file is not listed in hashes.txt."
  actual=$(sha256sum "$path" | cut -d' ' -f1)
  if [[ $actual != "$expected" ]]; then
    rm -f "$path"
    die "$file does NOT match its signed hash (deleted it). Run scripts/lab-setup.sh again; if it repeats, stop and investigate."
  fi
  ok "SHA-256 matches the signed list"

  # The archive's top folder, e.g. monero-x86_64-linux-gnu-v0.18.4.3.
  local top
  top=$(tar tjf "$path" | sed -n '1s|/.*||p')
  if [[ ! -d $LAB_HOME/bin/$top ]]; then
    tar xjf "$path" -C "$LAB_HOME/bin"
  fi
  ln -sfn "$top" "$LAB_HOME/bin/$link"
  ok "Unpacked to $LAB_HOME/bin/$top (linked as bin/$link)"
}

install_release "monero-linux-x64-v$MONERO_VERSION.tar.bz2" \
  "$DOWNLOADS_URL/cli/monero-linux-x64-v$MONERO_VERSION.tar.bz2" monero
"$LAB_HOME/bin/monero/monero-wallet-cli" --version | sed 's/^/    /'

if ((with_gui)); then
  install_release "monero-gui-linux-x64-v$MONERO_VERSION.tar.bz2" \
    "$DOWNLOADS_URL/gui/monero-gui-linux-x64-v$MONERO_VERSION.tar.bz2" monero-gui
fi

# --- 3. Pick a public stagenet node ----------------------------------------

step "Looking for a public stagenet node"

RPC=$REPO_DIR/scripts/rpc.py
if [[ -n $node ]]; then
  candidates=("$node")
else
  candidates=("${NODES[@]}")
fi

chosen=
for n in "${candidates[@]}"; do
  if result=$(python3 "$RPC" --node "$n" check 2>&1); then
    ok "$n  ($result)"
    chosen=$n
    break
  else
    echo "    --  $n  ($result)"
  fi
done

if [[ -z $chosen ]]; then
  chosen=${candidates[0]}
  echo
  echo "No node answered. settings.env will use $chosen for now." >&2
  echo "Find a working one on https://monero.fail/?nettype=stagenet and run:" >&2
  echo "  scripts/lab-setup.sh --node URL" >&2
fi

# --- 4. Settings ------------------------------------------------------------

cat > "$LAB_HOME/settings.env" << EOF
# Written by scripts/lab-setup.sh on $(date -u +%Y-%m-%d). Read by scripts/lab-run.sh and scripts/rpc.py.
MONERO_VERSION=$MONERO_VERSION
MONERO_BIN=$LAB_HOME/bin/monero
GUI_BIN=$LAB_HOME/bin/monero-gui
NODE=$chosen
EOF

step "Done"
cat << EOF

  Lab folder:  $LAB_HOME
  Node:        $chosen

  Next: open exercises/1-fundamentals/00-wallets.md and create your first wallet with

    scripts/lab-run.sh new alice

EOF
