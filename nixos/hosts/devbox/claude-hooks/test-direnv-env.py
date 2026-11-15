#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Sandbox test for direnv-env.py: throwaway repo + worktrees, private direnv allow store.

Usage: test-direnv-env.py [hook command...]   (defaults to the sibling direnv-env.py)
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HOOK = sys.argv[1:] or [str(Path(__file__).with_name("direnv-env.py"))]
root = Path(tempfile.mkdtemp(prefix="direnv-sandbox-")).resolve()
env = {**os.environ, "XDG_DATA_HOME": str(root / "xdg"), "GIT_CONFIG_GLOBAL": "/dev/null"}
for k in list(env):
    if k.startswith("DIRENV_") and k != "DIRENV_CONFIG":
        del env[k]


def sh(*cmd, cwd):
    subprocess.run(cmd, cwd=cwd, env=env, check=True, capture_output=True)


top = root / "top"
repo = top / "repo"
sub_rc = repo / "tf"
(repo / "gitops").mkdir(parents=True)
sub_rc.mkdir()
(top / ".envrc").write_text("export KUBECONFIG=/sandbox/kubeconfig\nexport TOP_ONLY=1\n")
(repo / ".envrc").write_text("source_up\nexport REPO_VAR=repo\n")
(sub_rc / ".envrc").write_text("source_up\nexport TF_ONLY=1\n")
(root / "elsewhere").mkdir()
(root / "other").mkdir()
(root / "other" / ".envrc").write_text("export OTHER_VAR=1\n")
sh("git", "init", "-q", "-b", "main", cwd=repo)
sh("git", "add", ".envrc", "tf/.envrc", cwd=repo)
sh("git", "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "init", cwd=repo)
wt = repo / ".claude" / "worktrees" / "slug"
sh("git", "worktree", "add", "-q", str(wt), "-b", "wt", cwd=repo)
wt2 = repo / ".claude" / "worktrees" / "edited"
sh("git", "worktree", "add", "-q", str(wt2), "-b", "wt2", cwd=repo)
(wt2 / ".envrc").write_text("source_up\nexport REPO_VAR=tampered\n")
for rc in (top, repo, root / "other"):
    sh("direnv", "allow", str(rc / ".envrc"), cwd=rc)

NAMES = ["KUBECONFIG", "TOP_ONLY", "REPO_VAR", "TF_ONLY", "OTHER_VAR"]
session = root / "session-env"
session.mkdir()
FILES = ["sessionstart-hook-1.sh", "cwdchanged-hook-0.sh", "filechanged-hook-0.sh"]


def hook(event, cwd):
    kind = {"SessionStart": 0, "CwdChanged": 1, "FileChanged": 2}[event]
    if kind >= 1:  # Claude clears these two on every cwd change
        for f in FILES[1:]:
            (session / f).write_text("")
    payload = {"hook_event_name": event, "cwd": str(cwd)}
    if event == "CwdChanged":
        payload["new_cwd"] = str(cwd)
    res = subprocess.run(HOOK, input=json.dumps(payload), text=True, capture_output=True,
                         env={**env, "CLAUDE_ENV_FILE": str(session / FILES[kind])}, cwd=root)
    return res.stdout.strip()


def effective():
    src = "; ".join(f'[ -f "{session / f}" ] && . "{session / f}"' for f in FILES)
    out = subprocess.run(["bash", "-c", f'{src}; for n in "$@"; do echo "$n=${{!n-}}"; done', "_", *NAMES],
                         env=env, capture_output=True, text=True, cwd=root).stdout
    return {k: v for k, v in (line.split("=", 1) for line in out.splitlines()) if v}


def case(name, steps, expected):
    for f in FILES:
        (session / f).unlink(missing_ok=True)
    msgs = [hook(event, cwd) for event, cwd in steps]
    got = effective()
    ok = got == expected
    print(f"{'PASS' if ok else 'FAIL'}  {name}")
    if not ok:
        print(f"      expected {expected}\n      got      {got}")
    if msgs[-1]:
        print(f"      hook said: {msgs[-1][:230].replace(str(root), '<sb>')}")
    return ok


K = {"KUBECONFIG": "/sandbox/kubeconfig", "TOP_ONLY": "1"}
REPO = {**K, "REPO_VAR": "repo"}
results = [
    case("start in repo root", [("SessionStart", repo)], REPO),
    case("start in repo subfolder", [("SessionStart", repo / "gitops")], REPO),
    case("start in fresh worktree (.claude/worktrees/slug)", [("SessionStart", wt)], REPO),
    case("start in worktree subfolder", [("SessionStart", wt / "tf" / "..")], REPO),
    case("start in worktree with EDITED .envrc stays blocked", [("SessionStart", wt2)], {}),
    case("start in repo, cd to blocked tf/.envrc: nothing loaded", [("SessionStart", repo), ("CwdChanged", sub_rc)], {}),
    case("... then cd back to repo", [("SessionStart", repo), ("CwdChanged", sub_rc), ("CwdChanged", repo)], REPO),
    case("start in repo, cd to other project: repo vars unloaded",
         [("SessionStart", repo), ("CwdChanged", root / "other")], {"OTHER_VAR": "1"}),
    case("start in repo, cd out of every .envrc", [("SessionStart", repo), ("CwdChanged", root / "elsewhere")], {}),
    case("start elsewhere, cd into repo, then subfolder",
         [("SessionStart", root / "elsewhere"), ("CwdChanged", repo), ("CwdChanged", repo / "gitops")], REPO),
    case("start elsewhere, cd into worktree",
         [("SessionStart", root / "elsewhere"), ("CwdChanged", wt)], REPO),
]
shutil.rmtree(root)
print(f"{sum(results)}/{len(results)} passed")
sys.exit(0 if all(results) else 1)
