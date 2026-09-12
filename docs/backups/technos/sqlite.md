# SQLite

Apps: Karakeep (`/data/db.db`), Navidrome (`/data/navidrome.db`), Lyrion (two servers,
several DB files under `/config`), Grafana (`grafana.db`).

## Physical vs logical for SQLite

| | Physical: copy the file | Logical: `sqlite3 .backup`, `VACUUM INTO`, `.dump` |
|---|---|---|
| Consistency | only with the app stopped, or via a filesystem snapshot that captures `db`, `db-wal` and `db-shm` together | consistent while the app runs, uses the online backup API |
| Tool here | ZFS snapshot (future), manual `tar` after scale to 0 | Karakeep CronJob `sqlite3 db.db ".backup out.db"` + `PRAGMA integrity_check` |
| Portability | same SQLite, any platform | `.backup` gives a binary file (any SQLite), `.dump` gives SQL text |
| PITR | no | no |

Rule: use `sqlite3 .backup` from a CronJob co-located with the app and mounting the same
PVC read-only. It is the only way to get a consistent copy without downtime. Copying the
file while the app writes, or taking an NFS-side tar, produces a corrupt copy some of
the time. Verify every copy with `PRAGMA integrity_check`.

## Placement rule

SQLite on NFS corrupts. WAL mode needs an mmap'd `-shm` file and reliable POSIX locks;
NFS gives neither. Navidrome hit `database disk image is malformed` on 2026-07-27 and
lost per-track play counts. Karakeep was moved to `local-path` on 2026-08-15 (PR #1673).

SQLite data goes on `local-path`, ReadWriteOnce, node pinned, PVC annotated
`argocd.argoproj.io/sync-options: Prune=false` because `local-path` reclaim is `Delete`.

## Current state

| App | Placement | Backup | Status |
|---|---|---|---|
| Karakeep | `local-path` on `k8s-worker-1` | nightly `.backup` + tar of assets to `nfs-jonbonas`, 14d | 🟡 no offsite |
| Navidrome | `nfs-client` (at risk) | none | ❌ |
| Lyrion (lms, lms-yoshi) | `nfs-client` (at risk) | none | ❌ |
| Grafana | `nfs-client` (at risk) | none | ⚪ dashboards in git are enough |

## Reuse

Copy `gitops/karakeep/karakeep/templates/backup-cronjob.yaml` and `files/backup.sh`.
The pattern is documented in [../tools/sqlite-backup-cronjob.md](../tools/sqlite-backup-cronjob.md).
Navidrome also ships its own scheduler (`ND_BACKUP_SCHEDULE`, `ND_BACKUP_PATH`,
`ND_BACKUP_COUNT`) which does the same `.backup` call, see [../apps/navidrome.md](../apps/navidrome.md).

## Restore

Scale the app to 0 (pause ArgoCD auto-sync first, see the memory on self-heal), copy the
backup `db.db` over the live one, delete stale `db.db-wal` and `db.db-shm`, scale up.
Assets are plain files, untar over the assets directory.
