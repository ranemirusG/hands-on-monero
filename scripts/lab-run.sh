#!/usr/bin/env bash
# lab-run.sh: open the stagenet lab's wallets, always the same way.
#
# Every wallet lives in $LAB/wallets/NAME/ and has NO password: this
# is stagenet, coins are worthless, and it keeps the exercises short. Never
# do this with a real (mainnet) wallet.
#
# CLI wallets start in $LAB/files/, so files they export or import
# (outputs, key images, unsigned and signed transactions, proofs) all land in
# one place: the lab's "USB stick" between wallets.
#
# Each command below is followed by what it really runs (for a wallet named
# alice), so you can type it yourself. First do what scripts/lab-run.sh does on start,
# from the repo folder:
#
#   LAB=$PWD/lab                         # the lab folder, inside this repo
#   source $LAB/settings.env             # sets $NODE
#   cd $LAB/files
#
# Logs: the CLI wallet commands also get
#   --log-file $LAB/logs/monero-wallet-cli.log
# (left out below to keep the lines short), and --log-level 4 (shown below).
# The lab logs at level 4, the most detailed (0 is the default): the log
# grows quickly (it rotates at about 100 MB) and records far more, which is
# the point for D1. Inside the wallet, set_log 0 lowers it live.
# On mainnet, don't run at 4.
# --log-file only says WHERE the wallet writes its log (what it did: node
# connection, refreshes, warnings, errors); --log-level 0-4 says how much
# (default 0, the quietest). Without it each program picks its own place:
# the CLI writes next to its binary, the GUI into ~/.bitmonero/, the node's
# folder. scripts/lab-run.sh sends both to $LAB/logs/ so everything the lab writes
# stays in $LAB. Logs can hold addresses, txids and node names
# (D1). Watch one live with: tail -f $LAB/logs/*.log
#
#   scripts/lab-run.sh new NAME         create a new CLI wallet (shows its seed)
# scripts/lab-run.sh new alice  runs:
#   mkdir -p $LAB/wallets/alice
#   $LAB/bin/monero/monero-wallet-cli --stagenet --password "" \
#     --shared-ringdb-dir $LAB/shared-ringdb --log-level 4 \
#     --generate-new-wallet $LAB/wallets/alice/alice \
#     --mnemonic-language English --create-address-file \
#     --daemon-address "$NODE" --untrusted-daemon
#
#   scripts/lab-run.sh open NAME        open a CLI wallet, connected to the public node
# scripts/lab-run.sh open alice  runs:
#   $LAB/bin/monero/monero-wallet-cli --stagenet --password "" \
#     --shared-ringdb-dir $LAB/shared-ringdb --log-level 4 \
#     --wallet-file $LAB/wallets/alice/alice \
#     --daemon-address "$NODE" --untrusted-daemon
#
#   scripts/lab-run.sh restore NAME     restore a wallet from a 25-word seed
# scripts/lab-run.sh restore alice-restored  runs:
#   mkdir -p $LAB/wallets/alice-restored
#   $LAB/bin/monero/monero-wallet-cli --stagenet --password "" \
#     --shared-ringdb-dir $LAB/shared-ringdb --log-level 4 \
#     --restore-deterministic-wallet \
#     --generate-new-wallet $LAB/wallets/alice-restored/alice-restored \
#     --daemon-address "$NODE" --untrusted-daemon
#
#   scripts/lab-run.sh restore NAME --offline
#                                       ...and never connect it (a cold wallet)
# scripts/lab-run.sh restore alice-cold --offline  runs:
#   mkdir -p $LAB/wallets/alice-cold
#   $LAB/bin/monero/monero-wallet-cli --stagenet --password "" \
#     --shared-ringdb-dir $LAB/shared-ringdb --log-level 4 \
#     --restore-deterministic-wallet \
#     --generate-new-wallet $LAB/wallets/alice-cold/alice-cold --offline
#
#   scripts/lab-run.sh cold NAME        open a wallet offline (a cold wallet)
# scripts/lab-run.sh cold alice-cold  runs:
#   $LAB/bin/monero/monero-wallet-cli --stagenet --password "" \
#     --shared-ringdb-dir $LAB/shared-ringdb --log-level 4 \
#     --wallet-file $LAB/wallets/alice-cold/alice-cold --offline
#
#   scripts/lab-run.sh view NAME        create a view-only CLI wallet (address + view key)
# scripts/lab-run.sh view alice-view-cli  runs:
#   mkdir -p $LAB/wallets/alice-view-cli
#   $LAB/bin/monero/monero-wallet-cli --stagenet --password "" \
#     --shared-ringdb-dir $LAB/shared-ringdb --log-level 4 \
#     --generate-from-view-key $LAB/wallets/alice-view-cli/alice-view-cli \
#     --daemon-address "$NODE" --untrusted-daemon
#
#   scripts/lab-run.sh gui              start the GUI wallet (portable mode: its settings
#                                       stay in $LAB/gui/monero-storage/settings.ini)
#                                       Unlike the CLI, the GUI has no option to open a
#                                       given wallet, so this command takes no NAME: you
#                                       create or pick the wallet (e.g. bob) in the GUI
#                                       itself, from $LAB/wallets. It remembers
#                                       the last one and offers it at the next start.
# scripts/lab-run.sh gui  runs:
#   mkdir -p $LAB/gui/monero-storage
#   touch $LAB/gui/monero-storage/settings.ini
#   cd $LAB/gui && setsid -f $LAB/bin/monero-gui/monero-wallet-gui \
#     --log-file $LAB/logs/monero-wallet-gui.log
#
#   scripts/lab-run.sh node             show the node the lab uses
# scripts/lab-run.sh node  runs:
#   curl -s "$NODE/json_rpc" -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}'
#
#   scripts/lab-run.sh list             list the lab's wallets
# scripts/lab-run.sh list  runs:
#   ls $LAB/wallets/*/*.keys
#
#   scripts/lab-run.sh reset            start a new lab: delete all wallets, exported
#                                       files, logs, the GUI's settings and the ring
#                                       database; keeps the
#                                       installed programs, so no download
# scripts/lab-run.sh reset  runs:
#   rm -rf $LAB/wallets/* $LAB/files/* \
#          $LAB/logs/* $LAB/gui $LAB/shared-ringdb
#
#   scripts/lab-run.sh reset --all      delete the whole lab except the verified
#                                       downloads, then run scripts/lab-setup.sh again (it reuses
#                                       and re-checks them instead of downloading)
# scripts/lab-run.sh reset --all  runs:
#   find $LAB -mindepth 1 -maxdepth 1 ! -name downloads -exec rm -rf {} +
#
#   Both refuse while a lab wallet (CLI or GUI) is running, and ask you to type
#   yes first. Seeds are deleted with the wallets: fine on stagenet.
#   To remove absolutely everything, downloads included:
#   rm -rf $LAB (or delete the whole repo folder).
set -euo pipefail

# The repo folder: the parent of scripts/, wherever the script is run from.
REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
LAB_HOME=${LAB_HOME:-$REPO_DIR/lab}
ENV_FILE=$LAB_HOME/settings.env

die() { printf '\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }
usage() { sed -n '2,/^[^#]/{/^#/{s/^# \{0,1\}//;p}}' "$0"; }

case ${1:-help} in help|-h|--help) usage; exit 0 ;; esac

[[ -f $ENV_FILE ]] || die "The lab isn't installed yet. Run scripts/lab-setup.sh first."
# shellcheck source=/dev/null
source "$ENV_FILE"
: "${MONERO_BIN:?missing in settings.env}" "${NODE:?missing in settings.env}"

WALLETS=$LAB_HOME/wallets
FILES=$LAB_HOME/files
CLI=$MONERO_BIN/monero-wallet-cli

wallet_path() {
  [[ ${1:-} =~ ^[A-Za-z0-9_-]+$ ]] || die "Give a wallet name (letters, digits, - and _), e.g. alice"
  echo "$WALLETS/$1/$1"
}

exists() { [[ -f $(wallet_path "$1").keys ]]; }

# banner COLOUR TEXT: a coloured line, and the same text as the
# terminal window's title, so you always know which wallet a window holds.
banner() {
  printf '\033]0;%s\007' "$2"
  printf '\n\033[1;%sm  %s  \033[0m\n\n' "$1" "$2"
}

# Run the CLI wallet. --password "" means "no password" (the wallet still
# asks before some commands; just press Enter, or see exercise 00 to turn
# that off).
cli() {
  cd "$FILES"
  exec "$CLI" --stagenet --password "" \
    --shared-ringdb-dir "$LAB_HOME/shared-ringdb" \
    --log-file "$LAB_HOME/logs/monero-wallet-cli.log" --log-level 4 "$@"
}

# The node is someone else's computer: --untrusted-daemon makes the wallet
# double-check what it says and never let it see anything sensitive.
online=(--daemon-address "$NODE" --untrusted-daemon)

cmd=${1:-help}
shift || true

case $cmd in
  new)
    name=${1:-}; path=$(wallet_path "$name")
    exists "$name" && die "Wallet $name already exists. Open it with: scripts/lab-run.sh open $name"
    mkdir -p "$(dirname "$path")"
    banner 32 "$name (new wallet, online)"
    echo "Write down the 25-word seed it shows, and the restore height (exercise 00)."
    cli --generate-new-wallet "$path" --mnemonic-language English \
        --create-address-file "${online[@]}"
    ;;

  open)
    name=${1:-}; path=$(wallet_path "$name")
    exists "$name" || die "No wallet named $name. Create it with: scripts/lab-run.sh new $name"
    banner 32 "$name (online, node $NODE)"
    cli --wallet-file "$path" "${online[@]}"
    ;;

  restore)
    name=${1:-}; path=$(wallet_path "$name")
    exists "$name" && die "Wallet $name already exists. Pick another name, e.g. $name-restored"
    mkdir -p "$(dirname "$path")"
    if [[ ${2:-} == --offline ]]; then
      banner 41 "$name (COLD: restored OFFLINE, never connects)"
      cli --restore-deterministic-wallet --generate-new-wallet "$path" --offline
    else
      [[ -z ${2:-} ]] || die "Unknown option: $2 (only --offline)"
      banner 32 "$name (restoring, online)"
      cli --restore-deterministic-wallet --generate-new-wallet "$path" "${online[@]}"
    fi
    ;;

  cold)
    name=${1:-}; path=$(wallet_path "$name")
    exists "$name" || die "No wallet named $name. Make one with: scripts/lab-run.sh restore $name --offline"
    banner 41 "$name (COLD: OFFLINE)"
    cli --wallet-file "$path" --offline
    ;;

  view)
    name=${1:-}; path=$(wallet_path "$name")
    exists "$name" && die "Wallet $name already exists."
    mkdir -p "$(dirname "$path")"
    banner 34 "$name (VIEW-ONLY, online)"
    echo "It will ask for the standard address, the secret view key and the restore height."
    cli --generate-from-view-key "$path" "${online[@]}"
    ;;

  gui)
    [[ -x ${GUI_BIN:-}/monero-wallet-gui ]] || die "The GUI isn't installed (scripts/lab-setup.sh --no-gui?)."
    if pgrep -f "$GUI_BIN/monero-wallet-gui" >/dev/null; then
      echo "The GUI wallet is already running."
      exit 0
    fi
    # Portable mode: the GUI keeps its settings in monero-storage/ under the
    # folder it starts in, instead of ~/.config/monero-project/. So the lab's
    # GUI (stagenet, the public node) never changes the settings of a GUI you
    # already use for something else.
    gui_home=$LAB_HOME/gui
    echo "Wallets folder (type this full path in the GUI): $WALLETS"
    mkdir -p "$gui_home/monero-storage"
    touch "$gui_home/monero-storage/settings.ini"
    (cd "$gui_home" && setsid -f "$GUI_BIN/monero-wallet-gui" \
       --log-file "$LAB_HOME/logs/monero-wallet-gui.log" &>/dev/null)
    cat << EOF
GUI wallet started. If it asks (first time, see exercise 00):
  mode:         Advanced
  network:      Stagenet
  wallet folder $WALLETS
  node:         Settings > Node > Remote node, address and port of
                $NODE
EOF
    ;;

  node)
    python3 "$REPO_DIR/scripts/rpc.py" info
    ;;

  list)
    shopt -s nullglob
    for keys in "$WALLETS"/*/*.keys; do
      w=$(basename "$keys" .keys)
      addr=$(cat "${keys%.keys}.address.txt" 2>/dev/null || echo "?")
      printf '%-16s %s\n' "$w" "${addr:0:12}..."
    done
    ;;

  reset)
    all=0
    case ${1:-} in
      "") ;;
      --all) all=1 ;;
      *) die "Unknown option: $1 (only --all)" ;;
    esac
    # A wallet that's still open would write its files back after we delete
    # them, so everything the lab runs must be closed first.
    if pgrep -f "$LAB_HOME/bin/monero" >/dev/null; then
      pgrep -a -f "$LAB_HOME/bin/monero" >&2
      die "Close every lab wallet first (exit in each CLI, close the GUI), then run this again."
    fi
    if ((all)); then
      echo "This deletes everything in $LAB_HOME except downloads/:"
      echo "programs, wallets (and their seeds), files, logs, GUI settings, settings.env."
      echo "Afterwards run scripts/lab-setup.sh (it reuses the downloads, no new download)."
    else
      echo "This deletes all lab wallets (and their seeds), exported files,"
      echo "logs, the GUI's settings and the ring database. The programs stay."
      echo "Wallets:"
      shopt -s nullglob
      for keys in "$WALLETS"/*/*.keys; do echo "  $(basename "$keys" .keys)"; done
    fi
    read -r -p "Type yes to continue: " answer
    [[ $answer == yes ]] || die "Nothing deleted."
    if ((all)); then
      find "$LAB_HOME" -mindepth 1 -maxdepth 1 ! -name downloads -exec rm -rf {} +
      echo "Done. Now run: scripts/lab-setup.sh"
    else
      rm -rf "${WALLETS:?}"/* "${FILES:?}"/* "$LAB_HOME"/logs/* "$LAB_HOME/gui" "$LAB_HOME/shared-ringdb"
      echo "Done. Start again with exercise 00: scripts/lab-run.sh new alice"
    fi
    ;;

  help|-h|--help)
    usage
    ;;

  *)
    die "Unknown command: $cmd (see scripts/lab-run.sh help)"
    ;;
esac
