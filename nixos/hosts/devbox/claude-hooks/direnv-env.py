#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Claude Code hook (SessionStart, CwdChanged, FileChanged): load the direnv
environment of the session's current directory into later Bash tool commands.

Claude sources the session env files before each Bash command, in the order
setup, sessionstart, cwdchanged, filechanged. This hook replays the files that
come before (and including) its own, so `direnv export` computes its diff
against what Bash commands really have, then appends that diff to its own file.

A blocked .envrc is reported instead of being silently skipped. The only case
allowed automatically is a linked git worktree whose .envrc is byte-identical
to the already allowed .envrc at the same path in the main checkout.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ORDER = {"setup": 0, "sessionstart": 1, "cwdchanged": 2, "filechanged": 3}
ENV_FILE_RE = re.compile(r"^(setup|sessionstart|cwdchanged|filechanged)-hook-(\d+)\.sh$")
ALLOWED, NOT_ALLOWED = 0, 1


def run(cmd, cwd, env=None):
    return subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True, check=False)


def baseline_files(env_file):
    """Env files Claude sources up to and including ours, in sourcing order."""
    own = ENV_FILE_RE.match(env_file.name)
    if not own:
        return []
    found = []
    for path in env_file.parent.iterdir():
        m = ENV_FILE_RE.match(path.name)
        if m and ORDER[m[1]] <= ORDER[own[1]] and path.stat().st_size > 0:
            found.append((ORDER[m[1]], int(m[2]), path))
    return [path for _, _, path in sorted(found)]


def found_rc(cwd):
    res = run(["direnv", "status", "--json"], cwd)
    try:
        rc = json.loads(res.stdout)["state"]["foundRC"]
    except (ValueError, KeyError, TypeError):
        return None
    return rc or None


def git_path(cwd, *args):
    res = run(["git", "rev-parse", "--path-format=absolute", *args], cwd)
    return Path(res.stdout.strip()) if res.returncode == 0 and res.stdout.strip() else None


def allow_if_worktree_copy(rc_path):
    """Allow rc_path when it is an unmodified worktree copy of an allowed .envrc.

    Returns the main checkout's .envrc path when the allow happened.
    """
    top = git_path(rc_path.parent, "--show-toplevel")
    common = git_path(rc_path.parent, "--git-common-dir")
    if not top or not common or common.name != ".git":
        return None
    main = common.parent
    if main == top or top not in rc_path.parents:
        return None
    main_rc = main / rc_path.relative_to(top)
    try:
        if main_rc.read_bytes() != rc_path.read_bytes():
            return None
    except OSError:
        return None
    main_state = found_rc(main_rc.parent)
    if not main_state or Path(main_state["path"]) != main_rc or main_state["allowed"] != ALLOWED:
        return None
    if run(["direnv", "allow", str(rc_path)], rc_path.parent).returncode != 0:
        return None
    return main_rc


def main():
    env_file = os.environ.get("CLAUDE_ENV_FILE")
    if not env_file:
        return
    env_file = Path(env_file)
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        payload = {}
    cwd = payload.get("new_cwd") or payload.get("cwd") or os.getcwd()
    if not os.path.isdir(cwd):
        return

    notes = []
    rc = found_rc(cwd)
    if rc and rc["allowed"] == NOT_ALLOWED:
        main_rc = allow_if_worktree_copy(Path(rc["path"]))
        if main_rc:
            notes.append(f"direnv: allowed {rc['path']} (identical to the allowed {main_rc}).")
        rc = found_rc(cwd)
    if rc and rc["allowed"] != ALLOWED:
        notes.append(
            f"direnv: {rc['path']} is blocked, so NO direnv environment (kubeconfig, secrets) "
            f"is loaded in {cwd}. Tell the user and ask them to review it and run "
            f"`direnv allow {rc['path']}`. Do not allow it yourself."
        )

    script = 'for f in "$@"; do . "$f" >/dev/null 2>&1 || true; done; exec direnv export bash'
    res = run(["bash", "-c", script, "_", *map(str, baseline_files(env_file))], cwd)
    if res.returncode != 0:
        errors = [line for line in res.stderr.splitlines() if "error" in line.lower()]
        notes.append("direnv export failed: " + " | ".join(errors[-3:]))
    with env_file.open("a") as out:
        out.write(res.stdout + "\ntrue\n")

    if notes:
        message = "\n".join(notes)
        output = {"systemMessage": message}
        event = payload.get("hook_event_name")
        if event == "SessionStart":
            output["hookSpecificOutput"] = {"hookEventName": event, "additionalContext": message}
        print(json.dumps(output))


if __name__ == "__main__":
    main()
