#!/usr/bin/env python3
"""Periodically fetches origin and fast-forwards ~/dotfiles if it's behind.

Deliberately fast-forward-only: never rebases or merges local work. If the
local branch has unpushed commits, this is a no-op and the push watcher
(auto_push_watch.py) is responsible for reconciling that side.
"""

import subprocess
import time
from pathlib import Path

REPO_DIR = Path.home() / "dotfiles"
LOG_DIR = Path.home() / ".local" / "state" / "dotfiles-sync"
LOG_FILE = LOG_DIR / "watcher.log"
BRANCH = "master"

LOG_DIR.mkdir(parents=True, exist_ok=True)


def log(msg: str) -> None:
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_FILE, "a") as f:
        f.write(f"{ts} {msg}\n")


def run(cmd: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=REPO_DIR, capture_output=True, text=True)


def main() -> None:
    before = run(["git", "rev-parse", "HEAD"]).stdout.strip()

    fetch = run(["git", "fetch", "--quiet", "origin", BRANCH])
    if fetch.returncode != 0:
        log(f"ERROR: auto-pull fetch failed. {fetch.stderr.strip()}")
        return

    merge = run(["git", "merge", "--ff-only", "--quiet", f"origin/{BRANCH}"])
    if merge.returncode != 0:
        # Local is ahead or diverged (unpushed local commits) -- leave it to
        # the push watcher, this is expected and not an error condition.
        return

    after = run(["git", "rev-parse", "HEAD"]).stdout.strip()
    if before != after:
        log(f"OK: auto-pull fast-forwarded {before[:7]} -> {after[:7]}")


if __name__ == "__main__":
    main()
