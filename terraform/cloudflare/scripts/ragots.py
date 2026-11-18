#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Edit the members of ragots@mangococo.fr stored in Bitwarden (secret ragots-members).

The value is a JSON list of addresses. Needs `bws` and BWS_ACCESS_TOKEN.
"""

import argparse
import json
import subprocess
import sys

SECRET_KEY = "ragots-members"


def bws(*args: str) -> str:
    return subprocess.run(["bws", *args], check=True, capture_output=True, text=True).stdout


def find_secret_id() -> str:
    for secret in json.loads(bws("secret", "list", "--output", "json")):
        if secret["key"] == SECRET_KEY:
            return secret["id"]
    sys.exit(f"Bitwarden secret {SECRET_KEY} not found")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("list", help="show the members")
    add_cmd = sub.add_parser("add", help="add members")
    add_cmd.add_argument("addresses", nargs="+")
    rm_cmd = sub.add_parser("rm", help="remove members")
    rm_cmd.add_argument("addresses", nargs="+")
    args = parser.parse_args()

    secret_id = find_secret_id()
    members = set(json.loads(json.loads(bws("secret", "get", secret_id, "--output", "json"))["value"]))

    if args.command != "list":
        addresses = {a.lower() for a in args.addresses}
        if args.command == "add":
            members |= addresses
        else:
            if missing := addresses - members:
                sys.exit(f"Not members: {', '.join(sorted(missing))}")
            members -= addresses
        bws("secret", "edit", secret_id, "--value", json.dumps(sorted(members)))
        print(
            "Saved. Apply now with `direnv reload && terraform apply` in terraform/cloudflare, "
            "or wait for Burrito (up to ~1h).",
            file=sys.stderr,
        )

    print(json.dumps(sorted(members), indent=2))


if __name__ == "__main__":
    main()
