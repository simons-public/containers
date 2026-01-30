#!/usr/bin/env python3
"""
Entrypoint script for Emby container with SQLite DB maintenance.

Runs VACUUM, ANALYZE, and REINDEX on all .db files in DB_PATH,
then execs EmbyServer to replace this process.
"""

import os
import sys
import threading
from pathlib import Path
import subprocess
import sqlite3

EMBY_DATA = "/var/lib/emby"
DB_PATH = os.path.join(EMBY_DATA, 'data')
EMBY_CMD = [
 '/usr/lib/emby-server/EmbyServer',
 '-ffdetect', '/usr/bin/ffdetect-emby',
 '-ffmpeg', '/usr/bin/ffmpeg-emby',
 '-ffprobe', '/usr/bin/ffprobe-emby',
 '-programdata', EMBY_DATA,
 '-noautorunwebapp']

def logger(msg):
    """Log messages to systemd journal."""
    print(f"[entrypoint.py] {msg}", flush=True)

def vacuum_analyze_reindex(db_file):
    try:
        logger(f"running sqlite3 {db_file} VACUUM")
        with sqlite3.connect(db_file) as conn:
            conn.execute("VACUUM;")
        logger(f"running sqlite3 {db_file} ANALYZE")
        with sqlite3.connect(db_file) as conn:
            conn.execute("ANALYZE;")
        logger(f"running sqlite3 {db_file} REINDEX")
        with sqlite3.connect(db_file) as conn:
            conn.execute("REINDEX;")
    except sqlite3.Error as e:
        logger(f"SQLite error processing {db_file}: {e}")

def run_maintenance():
    logger("starting sqlite3 database maintenance")
    threads = []

    for db_file in Path(DB_PATH).glob("*.db"):
        t = threading.Thread(target=vacuum_analyze_reindex, args=(str(db_file),))
        t.start()
        threads.append(t)

    for t in threads:
        t.join()

    logger("finished sqlite3 database maintenance")

def set_gpu_perms():
    for root, _, files in os.walk("/dev"):
        for name in files:
            path = os.path.join(root, name)

            if (
                path.startswith("/dev/nvi") or
                path.startswith("/dev/dri/card") or
                path.startswith("/dev/dri/render")
            ):
                try:
                    os.chmod(path, 0o666)
                    print(f"chmod 666 {path}")
                except Exception as e:
                    print(f"failed: {path}: {e}")

if __name__ == "__main__":
    run_maintenance()
    set_gpu_perms()
    logger("starting emby server")
    os.execv(EMBY_CMD[0], EMBY_CMD)  # replaces this process with EmbyServer
