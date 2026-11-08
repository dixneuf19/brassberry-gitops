# scripts

## cnpg-restore-drill

Restore drill for the CNPG clusters backed up by the barman-cloud plugin (immich, spliit).

Small Go module, stdlib only, shelling out to `kubectl`. Flags go before the target.

```bash
go -C scripts/cnpg-restore-drill run . --node k8s-worker-1 spliit/spliit
go -C scripts/cnpg-restore-drill run . immich/immich
```

It reads the source `Cluster`, creates `<cluster>-drill-<timestamp>` in the same namespace
bootstrapped by `recovery` from the source `ObjectStore` (latest base backup + archived WAL),
waits until it is healthy, then compares exact row counts of every table in every user
database with the live source. The drill Cluster is deleted at the end, even on failure.

- The drill declares no plugin, so it never archives WAL into the source backup path.
  The source only receives read queries
- Storage is `local-path`. The source `nodeSelector` is reused (immich needs k8s-worker-1);
  pass `--node` for spliit, otherwise it may land on brassberry-25 and its USB disk
- `--keep` leaves the drill running for manual checks, `--timeout` (a Go duration, default `30m`) bounds the recovery wait
- ArgoCD does not track the drill Cluster, so it neither prunes it nor reports drift
- A row count mismatch only means writes happened after the last archived WAL
  (`archive_timeout` is 5min); the script exits 1 only when a database or table is missing

### Drill log

| Date | Cluster | Base backup | Recovery | Tables / rows | Result |
|---|---|---|---|---|---|
| 2026-10-11 | spliit/spliit | 2026-10-11 04:19Z | 82s, replayed to 2026-10-11 04:44Z | 9 / 7840 | PASS, all counts match |
| 2026-10-11 | immich/immich | 2026-10-11 03:19Z | 67s | 71 / 480666 | PASS, all counts match |
| 2026-10-11 | spliit/spliit | 2026-10-11 04:19Z | 61s, replayed to 2026-10-11 04:44Z | 9 / 7840 | PASS, all counts match (Go rewrite) |
| 2026-10-11 | immich/immich | 2026-10-11 03:19Z | 67s | 71 / 480666 | PASS, all counts match (Go rewrite) |
