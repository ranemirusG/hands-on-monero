#!/usr/bin/env bash
# get-xmrig.sh: install the official XMRig miner for the cryptojacking exercise (D2), verified.
#
# It does the same thing scripts/lab-setup.sh does for Monero, for XMRig:
#   1. downloads the official XMRig release for Linux (x86_64, static build)
#      from the project's GitHub releases;
#   2. verifies it: the SHA256SUMS file must carry a valid signature from the
#      XMRig signing key, and the download must match its hash in that file;
#   3. unpacks it into the lab folder (no sudo, nothing system-wide).
#
# It installs the official binary, unmodified. It does NOT run the miner and
# does NOT change its donation setting. The cryptojacking exercise (D2) explains how to run it
# against a local fake pool. Nothing here touches any network
# except to download from GitHub and fetch the signing key.
#
# Usage:
#   ./scripts/get-xmrig.sh                  # install the pinned version
#   ./scripts/get-xmrig.sh --version 6.26.0 # a specific version
#   ./scripts/get-xmrig.sh --from DIR       # reuse an archive already in DIR
#                                           # (verified all the same)
#
# Run it again any time: a finished download is reused and re-checked. The lab
# folder is <repo>/lab unless LAB_HOME says otherwise.
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
LAB_HOME=${LAB_HOME:-$REPO_DIR/lab}

# The XMRig signing key, and the fingerprint it must have. The fingerprint is
# the trust anchor: cross-check it against the "GPG key" link on xmrig.com and
# the key id (446A53638BE94409) shown on the GitHub release page. As long as
# that matches, the key file itself can come from anywhere.
XMRIG_FP=9AC4CEA8E66E35A5C7CDDC1B446A53638BE94409
KEY_URL="https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${XMRIG_FP}"
RELEASES=https://github.com/xmrig/xmrig/releases/download

XMRIG_VERSION=${XMRIG_VERSION:-6.26.0}
from_dir=

die()  { printf '\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }
step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[32mOK\033[0m %s\n' "$*"; }

usage() { sed -n '2,/^[^#]/{/^#/{s/^# \{0,1\}//;p}}' "$0"; }

while (($#)); do
  case $1 in
    --version) [[ $# -ge 2 ]] || die "--version needs a number, e.g. --version 6.26.0"
               XMRIG_VERSION=$2; shift ;;
    --from)    [[ $# -ge 2 && -d ${2:-} ]] || die "--from needs a folder that holds the .tar.gz archive"
               from_dir=$2; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1 (see ./scripts/get-xmrig.sh --help)" ;;
  esac
  shift
done

V=$XMRIG_VERSION
file=xmrig-$V-linux-static-x64.tar.gz
dl=$LAB_HOME/downloads
top=xmrig-$V

# --- 0. Checks -------------------------------------------------------------

step "Checking this machine"
[[ $(uname -s) == Linux ]] || die "This installer is for Linux."
[[ $(uname -m) == x86_64 ]] || die "The static x86_64 build is for x86_64 (this machine is $(uname -m))."
missing=()
for cmd in curl gpg tar sha256sum; do
  command -v "$cmd" >/dev/null || missing+=("$cmd")
done
((${#missing[@]})) && die "Missing programs: ${missing[*]}"
mkdir -p "$dl" "$LAB_HOME/bin"
ok "Linux x86_64, required programs present"

# --- 1. Verify SHA256SUMS --------------------------------------------------

step "Verifying XMRig's signed checksums (version $V)"

# A throwaway keyring, so nothing is added to your own GnuPG setup.
GNUPGHOME=$(mktemp -d); export GNUPGHOME
trap 'rm -rf "$GNUPGHOME"' EXIT

curl -fsSL "$KEY_URL" -o "$GNUPGHOME/xmrig.asc"
grep -q "BEGIN PGP PUBLIC KEY" "$GNUPGHOME/xmrig.asc" \
  || die "Could not fetch the XMRig signing key. Check your connection, or import it by hand from xmrig.com."
gpg --batch --quiet --import "$GNUPGHOME/xmrig.asc" 2>/dev/null
gpg --batch --with-colons --fingerprint | grep -q "^fpr:*$XMRIG_FP:" \
  || die "The downloaded key doesn't have XMRig's fingerprint. Stop and investigate."
ok "XMRig's key has the expected fingerprint $XMRIG_FP"

curl -fsSL "$RELEASES/v$V/SHA256SUMS"     -o "$dl/xmrig-$V-SHA256SUMS"
curl -fsSL "$RELEASES/v$V/SHA256SUMS.sig" -o "$dl/xmrig-$V-SHA256SUMS.sig"
gpg --batch --status-fd 3 --verify \
    "$dl/xmrig-$V-SHA256SUMS.sig" "$dl/xmrig-$V-SHA256SUMS" 3>"$GNUPGHOME/status" 2>/dev/null || true
grep -q "^\[GNUPG:\] VALIDSIG .*$XMRIG_FP" "$GNUPGHOME/status" \
  || die "SHA256SUMS is NOT validly signed by XMRig. Do not use this download."
ok "SHA256SUMS is signed by XMRig"

# --- 2. Download, check and unpack -----------------------------------------

step "Installing $file"
path=$dl/$file
if [[ ! -f $path && -n $from_dir && -f $from_dir/$file ]]; then
  cp "$from_dir/$file" "$path"
  ok "Copied from $from_dir (checked below like a download)"
fi
if [[ ! -f $path ]]; then
  curl -fL --progress-bar "$RELEASES/v$V/$file" -o "$path.part"
  mv "$path.part" "$path"
fi

# Check the archive against the signed SHA256SUMS, by its own name.
( cd "$dl" && cp "xmrig-$V-SHA256SUMS" SHA256SUMS.$$ \
  && sha256sum --ignore-missing -c SHA256SUMS.$$ 2>/dev/null | grep -q "^$file: OK" \
  && rm -f SHA256SUMS.$$ ) \
  || { rm -f "$path" "$dl/SHA256SUMS.$$"; die "$file does NOT match its signed hash (deleted it). Run again; if it repeats, stop and investigate."; }
ok "SHA-256 matches the signed list"

if [[ ! -d $LAB_HOME/bin/$top ]]; then
  tar xzf "$path" -C "$LAB_HOME/bin"
fi
[[ -x $LAB_HOME/bin/$top/xmrig ]] || die "Unpacked, but $LAB_HOME/bin/$top/xmrig is missing."
ln -sfn "$top" "$LAB_HOME/bin/xmrig"
ok "Unpacked to $LAB_HOME/bin/$top (linked as bin/xmrig)"

step "Done"
cat << EOF

  XMRig:  $LAB_HOME/bin/xmrig/xmrig   (version $V)

  Next: exercises/2-dfir/D2-cryptojacking.md. Run it against the local fake
  pool (scripts/fakepool.py). The lab never points it at a real pool or node —
  its only outbound traffic is XMRig's own developer donation.

EOF
"$LAB_HOME/bin/xmrig/xmrig" --version | sed 's/^/    /' || true
