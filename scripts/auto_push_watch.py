#!/usr/bin/env python3
"""Watches ~/dotfiles/.claude/CLAUDE.md and auto-commits/pushes changes to origin."""

import os
import socket
import subprocess
import threading
import time
from pathlib import Path

import pyinotify

REPO_DIR = Path.home() / "dotfiles"
WATCH_FILE_NAME = "CLAUDE.md"
WATCH_DIR = REPO_DIR / ".claude"
LOG_DIR = Path.home() / ".local" / "state" / "dotfiles-sync"
LOG_FILE = LOG_DIR / "watcher.log"
DEBOUNCE_SECONDS = 3
BRANCH = "master"

LOG_DIR.mkdir(parents=True, exist_ok=True)


def log(msg: str) -> None:
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_FILE, "a") as f:
        f.write(f"{ts} {msg}\n")


def run(cmd: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=REPO_DIR, capture_output=True, text=True)


def sync_repo() -> None:
    status = run(["git", "status", "--porcelain", "--", ".claude/CLAUDE.md"])
    if not status.stdout.strip():
        return

    run(["git", "add", ".claude/CLAUDE.md"])
    host = socket.gethostname()
    commit = run(["git", "commit", "-m", f"auto-sync: CLAUDE.md updated on {host}", "--quiet"])
    if commit.returncode != 0:
        log(f"INFO: nothing to commit ({commit.stderr.strip() or commit.stdout.strip()})")
        return

    pull = run(["git", "pull", "--rebase", "--quiet", "origin", BRANCH])
    if pull.returncode != 0:
        log(f"ERROR: git pull --rebase failed after local commit. Resolve manually in {REPO_DIR} (local commit is intact, unpushed). {pull.stderr.strip()}")
        return

    push = run(["git", "push", "--quiet", "origin", BRANCH])
    if push.returncode == 0:
        log(f"OK: pushed CLAUDE.md change from {host}")
    else:
        log(f"ERROR: git push failed (possible conflict). Resolve manually in {REPO_DIR}. {push.stderr.strip()}")


class DebouncedHandler(pyinotify.ProcessEvent):
    def my_init(self):
        self._timer = None
        self._lock = threading.Lock()

    def _trigger(self, event):
        if os.path.basename(event.pathname) != WATCH_FILE_NAME:
            return
        with self._lock:
            if self._timer:
                self._timer.cancel()
            self._timer = threading.Timer(DEBOUNCE_SECONDS, sync_repo)
            self._timer.daemon = True
            self._timer.start()

    def process_IN_CLOSE_WRITE(self, event):
        self._trigger(event)

    def process_IN_MOVED_TO(self, event):
        self._trigger(event)


def main() -> None:
    log(f"watcher started, watching {WATCH_DIR / WATCH_FILE_NAME}")
    wm = pyinotify.WatchManager()
    notifier = pyinotify.Notifier(wm, DebouncedHandler())
    mask = pyinotify.IN_CLOSE_WRITE | pyinotify.IN_MOVED_TO
    wm.add_watch(str(WATCH_DIR), mask, rec=False)
    notifier.loop()


if __name__ == "__main__":
    main()
