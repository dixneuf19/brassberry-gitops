#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Restore drill for a CNPG cluster backed up with the barman-cloud plugin.

Creates a throwaway Cluster next to the source, bootstrapped by recovery from
the source's ObjectStore (latest base backup + archived WAL), compares exact
per-table row counts with the live source, then deletes the drill Cluster.

The drill Cluster declares no plugin, so it never archives WAL into the
source's backup path. Nothing on the source is modified: it only gets read
queries.

Usage: scripts/cnpg-restore-drill.py <namespace>/<cluster> [--keep] [--node NODE]
"""

import argparse
import datetime as dt
import json
import re
import subprocess
import sys
import time

PLUGIN = "barman-cloud.cloudnative-pg.io"
# set by the operator on every Cluster, never worth copying to the drill
CNPG_MANAGED_PARAMS = {
    "archive_mode",
    "archive_timeout",
    "dynamic_shared_memory_type",
    "full_page_writes",
    "log_destination",
    "log_directory",
    "log_filename",
    "log_rotation_age",
    "log_rotation_size",
    "log_truncate_on_rotation",
    "logging_collector",
    "max_parallel_workers",
    "max_replication_slots",
    "max_worker_processes",
    "shared_memory_type",
    "shared_preload_libraries",
    "ssl_max_protocol_version",
    "ssl_min_protocol_version",
    "wal_keep_size",
    "wal_level",
    "wal_log_hints",
    "wal_receiver_timeout",
    "wal_sender_timeout",
}
COUNT_SQL = """
SELECT format('SELECT %L AS t, count(*) AS n FROM %I.%I', n.nspname || '.' || c.relname, n.nspname, c.relname)
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'p') AND n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
ORDER BY 1
"""


def log(msg: str) -> None:
    print(f"[{dt.datetime.now():%H:%M:%S}] {msg}", flush=True)


def kubectl(*args: str, stdin: str | None = None, check: bool = True) -> str:
    res = subprocess.run(["kubectl", *args], input=stdin, capture_output=True, text=True)
    if check and res.returncode != 0:
        raise RuntimeError(f"kubectl {' '.join(args)}: {res.stderr.strip()}")
    return res.stdout


def get_json(*args: str) -> dict:
    return json.loads(kubectl("get", *args, "-o", "json"))


def psql(ns: str, pod: str, db: str, sql: str) -> str:
    return kubectl("exec", "-n", ns, pod, "-c", "postgres", "--", "psql", "-d", db, "-XtAq", "-F", "\t", "-c", sql)


def row_counts(ns: str, pod: str) -> dict[str, int]:
    """Exact row count of every table in every user database, keyed db/schema.table."""
    dbs = psql(ns, pod, "postgres", "SELECT datname FROM pg_database WHERE NOT datistemplate AND datname <> 'postgres'")
    counts = {}
    for db in dbs.split():
        queries = [q for q in psql(ns, pod, db, COUNT_SQL).splitlines() if q]
        if queries:
            out = psql(ns, pod, db, " UNION ALL ".join(queries))
            counts |= {f"{db}/{t}": int(n) for t, n in (line.split("\t") for line in out.splitlines() if line)}
    return counts


def drill_manifest(src: dict, name: str, node: str | None) -> dict:
    spec = src["spec"]
    archiver = next((p for p in spec.get("plugins", []) if p["name"] == PLUGIN), None)
    if archiver is None:
        sys.exit(f"source cluster has no {PLUGIN} plugin, nothing to restore from")
    pg = spec.get("postgresql", {})
    params = {k: v for k, v in pg.get("parameters", {}).items() if k not in CNPG_MANAGED_PARAMS}
    drill_spec = {
        "instances": 1,
        "enablePDB": False,
        "storage": {"size": spec["storage"]["size"], "storageClass": "local-path"},
        "resources": {"requests": {"cpu": "250m", "memory": "256Mi"}, "limits": {"memory": "1Gi"}},
        "postgresql": {"parameters": params, "shared_preload_libraries": pg.get("shared_preload_libraries", [])},
        "bootstrap": {"recovery": {"source": "origin"}},
        "externalClusters": [
            {
                "name": "origin",
                "plugin": {
                    "name": PLUGIN,
                    "parameters": {
                        "barmanObjectName": archiver["parameters"]["barmanObjectName"],
                        "serverName": archiver["parameters"].get("serverName", src["metadata"]["name"]),
                    },
                },
            }
        ],
    }
    for key in ("imageName", "imageCatalogRef"):
        if key in spec:
            drill_spec[key] = spec[key]
    selector = dict(spec.get("affinity", {}).get("nodeSelector", {}))
    if node:
        selector["kubernetes.io/hostname"] = node
    if selector:
        drill_spec["affinity"] = {"nodeSelector": selector}
    return {
        "apiVersion": "postgresql.cnpg.io/v1",
        "kind": "Cluster",
        "metadata": {
            "name": name,
            "namespace": src["metadata"]["namespace"],
            "labels": {"drill.dixneuf19.fr/source": src["metadata"]["name"]},
        },
        "spec": drill_spec,
    }


def wait_ready(ns: str, name: str, timeout: int) -> str | None:
    """Wait for the drill to be healthy, return the last replayed transaction time.

    That time is only printed by the full-recovery job, which CNPG removes once
    the instance starts, so its logs are scraped while waiting.
    """
    deadline = time.monotonic() + timeout
    last, replayed = "", None
    while time.monotonic() < deadline:
        status = get_json("cluster", "-n", ns, name).get("status", {})
        phase = status.get("phase", "")
        if phase != last:
            log(f"drill phase: {phase or '(none)'}")
            last = phase
        out = kubectl("logs", "-n", ns, f"job/{name}-1-full-recovery", "--all-containers", check=False)
        hits = re.findall(r"last completed transaction was at log time ([^\"\\]+)", out)
        replayed = hits[-1].strip() if hits else replayed
        if status.get("readyInstances") == 1 and phase == "Cluster in healthy state":
            return replayed
        time.sleep(5)
    raise TimeoutError(f"drill cluster not ready after {timeout}s (last phase: {last})")


def latest_backup(ns: str, cluster: str) -> str | None:
    items = get_json("backups.postgresql.cnpg.io", "-n", ns)["items"]
    done = [
        b["status"].get("stoppedAt")
        for b in items
        if b["spec"]["cluster"]["name"] == cluster and b.get("status", {}).get("phase") == "completed"
    ]
    return max((d for d in done if d), default=None)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("target", help="<namespace>/<cluster>, e.g. spliit/spliit")
    ap.add_argument("--keep", action="store_true", help="leave the drill Cluster running for inspection")
    ap.add_argument("--node", help="pin the drill instance to this node (default: the source's nodeSelector)")
    ap.add_argument("--timeout", type=int, default=1800, help="seconds to wait for the recovery")
    args = ap.parse_args()

    ns, cluster = args.target.split("/", 1)
    src = get_json("cluster", "-n", ns, cluster)
    primary = src["status"]["currentPrimary"]
    name = f"{cluster}-drill-{dt.datetime.now():%Y%m%d%H%M}"

    log(f"source {ns}/{cluster}, primary {primary}")
    log(f"latest completed base backup: {latest_backup(ns, cluster)}")
    archiver = psql(
        ns, primary, "postgres", "SELECT last_archived_wal, last_archived_time FROM pg_stat_archiver"
    ).strip()
    log(f"source archiver: {archiver}")

    started = time.monotonic()
    kubectl("apply", "-f", "-", stdin=json.dumps(drill_manifest(src, name, args.node)))
    log(f"created drill cluster {ns}/{name}")
    ok = False
    try:
        replayed = wait_ready(ns, name, args.timeout)
        log(f"recovered in {time.monotonic() - started:.0f}s, last replayed transaction at {replayed or 'not logged'}")

        src_counts = row_counts(ns, primary)
        drill_counts = row_counts(ns, f"{name}-1")
        diffs = {
            t: (src_counts.get(t), drill_counts.get(t))
            for t in src_counts.keys() | drill_counts.keys()
            if src_counts.get(t) != drill_counts.get(t)
        }
        log(
            f"{len(src_counts)} tables, {sum(src_counts.values())} rows in source, "
            f"{sum(drill_counts.values())} in drill"
        )
        for t, (s, d) in sorted(diffs.items()):
            log(f"  differs: {t} source={s} drill={d}")
        if not diffs:
            log("row counts match on every table")
        ok = bool(drill_counts) and set(src_counts) == set(drill_counts)
        log(
            f"RESULT: {'PASS' if ok else 'FAIL'} ({len(diffs)} table(s) differ, writes after the last archived WAL are expected)"
        )
    finally:
        if args.keep:
            log(f"--keep: delete later with: kubectl delete cluster -n {ns} {name}")
        else:
            kubectl("delete", "cluster", "-n", ns, name, "--wait=true", check=False)
            kubectl("delete", "pvc", "-n", ns, "-l", f"cnpg.io/cluster={name}", "--ignore-not-found", check=False)
            log(f"deleted drill cluster {name}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
