# Karakeep

Namespace `karakeep`, chart `gitops/karakeep/karakeep`. Bookmarks, archived pages,
highlights; ~1600 bookmarks.

## Data

| Data | Where | Class | Backup |
|---|---|---|---|
| SQLite `/data/db.db` + `/data/assets` | `karakeep-data`, `local-path` 10Gi on `k8s-worker-1`, `Prune=false` | A | nightly CronJob 03:30: `sqlite3 .backup` + integrity check + tar of assets, to `karakeep-backups` (`nfs-jonbonas` 20Gi, `/tank/data/karakeep/karakeep-backups/`), 14d, ~400M each |
| Meilisearch index | `karakeep-meilisearch`, `nfs-client` 1Gi | C | none, reindex from admin UI |
| Next.js cache | emptyDir | C | none |

Secrets: `NEXTAUTH_SECRET`, `MEILI_MASTER_KEY`, `OPENAI_API_KEY` in Bitwarden via ESO.
Ad-hoc copies from the 2026-08-14 migration: `/tank/data/backups/karakeep/*.tar.gz` and the
old `Retain` NFS PV `pvc-4a3ec79b` on brassberry-25 (deletable after soak).

## Status: 🟡

Automated, consistent, verified, on a different machine than the source. Not offsite, no
alert, never restored.

## TODO

1. Include `/tank/data/karakeep/karakeep-backups` in the NAS restic job.
2. Alert when the CronJob's last success is older than 2 days.
3. Restore drill into a scratch PVC, open the DB with `sqlite3`, count bookmarks.
4. Consider a weekly copy kept 8 weeks in addition to 14 dailies.
5. Meilisearch PVC is on the flaky `nfs-client` disk; move to `nfs-jonbonas` or
   `local-path`, it is rebuildable so no backup needed.

## Restore

See [../tools/sqlite-backup-cronjob.md](../tools/sqlite-backup-cronjob.md). Then Admin
Settings > Background Jobs > Reindex.
