#!/usr/bin/env python3
# fakepool.py: a throwaway, local-only "mining pool" for the lab.
#
# It speaks just enough of the Stratum protocol (the JSON-over-TCP language
# real pools use) to make a miner connect, log in, receive a job, and send
# back "shares". It also pushes a fresh job every so often (--job-interval),
# the way a real pool rotates work. It does NOT mine anything, pay anyone, or talk to any
# network: it listens on 127.0.0.1 and nothing leaves your machine. Its only
# purpose is to give the cryptojacking exercise (D2) something for XMRig to talk to, so you can
# watch what a miner does and what it leaves behind.
#
# Every message it receives is printed, and the miner's login (which carries
# the payout address) is highlighted: that line is the whole point of the
# forensic part of the exercise.
#
# Usage:
#   python3 scripts/fakepool.py                 # listen on 127.0.0.1:3333
#   python3 scripts/fakepool.py --port 4444
#   python3 scripts/fakepool.py --log lab/logs/fakepool.log
#   python3 scripts/fakepool.py --job-interval 15   # push a new job every 15 s
#
# Stop it with Ctrl-C. It is a teaching stub, not a real pool: do not expose
# it to a network and do not use it for anything but this lab.

import argparse
import json
import secrets
import socket
import sys
import threading
import time
from datetime import datetime, timezone

# A fixed, meaningless job. A real pool fills these from a block template it
# got from its own node; here they are constants, just so the miner has
# something well-formed to chew on. No real block is ever built.
FAKE_JOB = {
    "blob": "0" * 152,          # a Monero hashing blob is 76 bytes = 152 hex
    "job_id": "lab-job-1",
    "target": "0cbb0200",       # ~diff 24000: roughly a share every ~10 s at a
                                # typical lab hashrate (it scales with the CPU:
                                # faster box = more often). XMRig reads this as a
                                # little-endian uint32 T and uses diff =
                                # 0xffffffff / T, so a SMALLER target = higher
                                # difficulty = fewer, more realistic shares.
    "seed_hash": "0" * 64,      # RandomX seed; fixed for the lab
    "height": 3000000,
    "algo": "rx/0",             # Monero's RandomX
}


def now():
    return datetime.now(timezone.utc).strftime("%H:%M:%S")


class Pool:
    def __init__(self, host, port, logpath, job_interval):
        self.host = host
        self.port = port
        self.logfile = open(logpath, "a") if logpath else None
        self.lock = threading.Lock()
        self.send_lock = threading.Lock()   # serialize writes across threads
        self.shares = 0
        self.jobs = 0
        self.job_interval = job_interval

    def log(self, line):
        with self.lock:
            print(line, flush=True)
            if self.logfile:
                self.logfile.write(line + "\n")
                self.logfile.flush()

    def send(self, conn, obj):
        # Both the reader thread (login/submit replies) and the job-pusher
        # thread write to the same socket, so serialize to avoid interleaving.
        data = (json.dumps(obj) + "\n").encode()
        with self.send_lock:
            conn.sendall(data)

    def new_job(self):
        # A fresh job, like a real pool rotating work: a new job_id and a new
        # blob (so the miner restarts its nonce search). Difficulty (target)
        # stays fixed for the lab.
        with self.lock:
            self.jobs += 1
            n = self.jobs
        job = dict(FAKE_JOB)
        job["job_id"] = "lab-job-%d" % n
        job["blob"] = secrets.token_hex(76)   # 76 bytes = 152 hex, like a real blob
        return job

    def push_jobs(self, conn, peer):
        # A real pool pushes unsolicited "job" notifications (new block on the
        # network, or just rotating work). Here we do it on a timer so the
        # pool->miner job traffic shows up in a capture.
        while True:
            time.sleep(self.job_interval)
            job = self.new_job()
            try:
                self.send(conn, {"jsonrpc": "2.0", "method": "job",
                                 "params": job})
            except (ConnectionError, OSError):
                break
            self.log("[%s] %s <- JOB %s (pushed)" % (now(), peer, job["job_id"]))

    def handle(self, conn, addr):
        peer = "%s:%s" % addr
        self.log("[%s] connection from %s" % (now(), peer))
        buf = b""
        try:
            while True:
                chunk = conn.recv(4096)
                if not chunk:
                    break
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    line = line.strip()
                    if line:
                        self.dispatch(conn, peer, line)
        except (ConnectionError, OSError):
            pass
        finally:
            self.log("[%s] %s disconnected" % (now(), peer))
            conn.close()

    def dispatch(self, conn, peer, raw):
        try:
            msg = json.loads(raw)
        except ValueError:
            self.log("[%s] %s sent non-JSON: %r" % (now(), peer, raw[:120]))
            return

        method = msg.get("method", "")
        mid = msg.get("id", 1)
        params = msg.get("params", {}) or {}

        if method == "login":
            # This is the interesting one for forensics: the miner tells the
            # pool which ADDRESS to pay. On a compromised machine, this line
            # (in a pcap, or here) is what ties the miner to a wallet.
            login = params.get("login", "")
            agent = params.get("agent", "")
            self.log("[%s] %s LOGIN  address=%s  agent=%s"
                     % (now(), peer, login, agent))
            self.send(conn, {
                "id": mid, "jsonrpc": "2.0", "error": None,
                "result": {
                    "id": "lab-session-1",
                    "job": self.new_job(),
                    "status": "OK",
                },
            })
            # Start pushing fresh jobs to this miner, like a real pool
            # (unless disabled with --job-interval 0).
            if self.job_interval > 0:
                threading.Thread(target=self.push_jobs, args=(conn, peer),
                                 daemon=True).start()
        elif method == "submit":
            with self.lock:
                self.shares += 1
                n = self.shares
            self.log("[%s] %s SHARE #%d  job=%s"
                     % (now(), peer, n, params.get("job_id", "?")))
            self.send(conn, {
                "id": mid, "jsonrpc": "2.0", "error": None,
                "result": {"status": "OK"},
            })
        elif method == "keepalived":
            self.send(conn, {
                "id": mid, "jsonrpc": "2.0", "error": None,
                "result": {"status": "KEEPALIVED"},
            })
        else:
            self.log("[%s] %s method=%s (ignored)" % (now(), peer, method))
            self.send(conn, {
                "id": mid, "jsonrpc": "2.0", "error": None,
                "result": {"status": "OK"},
            })

    def serve(self):
        srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            srv.bind((self.host, self.port))
        except OSError as e:
            sys.exit("Cannot bind %s:%d (%s). Is something already using it?"
                     % (self.host, self.port, e))
        srv.listen(8)
        self.log("fake pool listening on %s:%d  (Ctrl-C to stop)"
                 % (self.host, self.port))
        self.log("nothing is mined and nothing leaves this machine.")
        try:
            while True:
                conn, addr = srv.accept()
                t = threading.Thread(target=self.handle, args=(conn, addr),
                                     daemon=True)
                t.start()
        except KeyboardInterrupt:
            self.log("\n[%s] stopping, %d shares seen" % (now(), self.shares))
        finally:
            srv.close()
            if self.logfile:
                self.logfile.close()


def main():
    ap = argparse.ArgumentParser(description="A local-only fake Stratum pool "
                                 "for the Monero lab (exercise D2).")
    ap.add_argument("--host", default="127.0.0.1",
                    help="address to listen on (default 127.0.0.1; "
                         "keep it local)")
    ap.add_argument("--port", type=int, default=3333,
                    help="port to listen on (default 3333)")
    ap.add_argument("--log", default="",
                    help="also append the transcript to this file")
    ap.add_argument("--job-interval", type=float, default=30.0,
                    help="seconds between pushed job updates (default 30; "
                         "0 disables pushing)")
    args = ap.parse_args()

    if args.host not in ("127.0.0.1", "localhost", "::1"):
        print("Refusing to listen on %s: this stub is for 127.0.0.1 only."
              % args.host, file=sys.stderr)
        sys.exit(2)

    Pool(args.host, args.port, args.log, args.job_interval).serve()


if __name__ == "__main__":
    main()
