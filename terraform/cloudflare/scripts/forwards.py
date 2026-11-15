#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Edit the mangococo.fr forwarding map stored in Bitwarden (secret mangococo-email-forwards).

The map is JSON: {"src@mangococo.fr": ["dest", ...]}. Needs `bws` and BWS_ACCESS_TOKEN.
"""

import argparse
import json
import subprocess
import sys

SECRET_KEY = "mangococo-email-forwards"
DOMAIN = "@mangococo.fr"


def bws(*args: str) -> str:
    return subprocess.run(["bws", *args], check=True, capture_output=True, text=True).stdout


def find_secret_id() -> str:
    for secret in json.loads(bws("secret", "list", "--output", "json")):
        if secret["key"] == SECRET_KEY:
            return secret["id"]
    sys.exit(f"Bitwarden secret {SECRET_KEY} not found")


def load(secret_id: str) -> dict[str, list[str]]:
    return json.loads(json.loads(bws("secret", "get", secret_id, "--output", "json"))["value"])


def save(secret_id: str, forwards: dict[str, list[str]]) -> None:
    bws("secret", "edit", secret_id, "--value", json.dumps(forwards, sort_keys=True))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("list", help="show the map")
    set_cmd = sub.add_parser("set", help="set the destinations of a source address")
    set_cmd.add_argument("source")
    set_cmd.add_argument("destinations", nargs="+")
    rm_cmd = sub.add_parser("rm", help="remove a source address")
    rm_cmd.add_argument("source")
    args = parser.parse_args()

    secret_id = find_secret_id()
    forwards = load(secret_id)

    if args.command == "list":
        print(json.dumps(forwards, indent=2, sort_keys=True))
        return

    source = args.source.lower()
    if args.command == "set":
        if not source.endswith(DOMAIN):
            sys.exit(f"{source} is not on {DOMAIN[1:]}")
        forwards[source] = sorted({d.lower() for d in args.destinations})
    elif source in forwards:
        del forwards[source]
    else:
        sys.exit(f"{source} is not in the map")

    save(secret_id, forwards)
    print(json.dumps(forwards, indent=2, sort_keys=True))
    print(
        "Saved. Apply now with `direnv reload && terraform apply` in terraform/cloudflare, "
        "or wait for Burrito (up to ~1h).",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
