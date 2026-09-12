# Immich built-in database backup

Immich runs its own `pg_dumpall` on a schedule and writes gzipped SQL into the library
folder. It is on by default and is active here. This is the logical counterpart of the
CNPG physical backup, and the format Immich's own restore documentation expects.

## Facts (checked 2026-09-12 on the NAS)

| Item | Value |
|---|---|
| Path | `/tank/media/immich/backups/` (NFS PV `immich-library`, mounted at `/usr/src/app/upload`) |
| Schedule | daily 02:00 UTC (Immich default `0 2 * * *`) |
| Kept | 14 (Immich default), ~100M each gzip |
| Naming | `immich-db-backup-<stamp>-v<immich version>-pg<pg version>.sql.gz` |
| Config | Admin > Settings > Backup settings. Not set in `gitops/immich/immich/values.yaml`, so defaults apply |

## Why keep it alongside barman

- Version-independent: `psql` can load it into any PG 17 or newer.
- Catches corruption: a broken table makes the dump fail, which barman would copy silently.
- Immich's upgrade path across Postgres majors is "dump, upgrade, restore".
- Stays on the NAS, so it is not offsite: the restic job must include this folder.

## Restore (from Immich docs, adapted to CNPG)

1. Scale `immich-server` and `immich-machine-learning` to 0, pause ArgoCD auto-sync.
2. Recreate an empty database or a fresh CNPG cluster with the same image.
3. Load:

```bash
gunzip -c immich-db-backup-<stamp>.sql.gz \
  | sed 's/SELECT pg_catalog.set_config(.search_path., .., false);/SELECT pg_catalog.set_config('"'"'search_path'"'"', '"'"'public, pg_catalog'"'"', true);/' \
  | kubectl exec -i -n immich immich-1 -- psql -U postgres
```

(The `sed` is the one Immich's docs use for dumps from some versions; skip if the plain
load works.)

4. Start the server with the same Immich version the dump was taken with, then upgrade.

## Gap

Not offsite, not monitored. Deleting `/tank/media/immich` removes the library and its
dumps together, which is the argument for the restic job reading from a snapshot.
