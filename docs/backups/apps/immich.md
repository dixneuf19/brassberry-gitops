# Immich

Namespace `immich`, chart `gitops/immich/immich`, Immich v3.2.0 (2026-09-12), users' photo
library. The most valuable data in the homelab.

## Data

| Data | Where | Size | Class | Backup |
|---|---|---|---|---|
| Postgres `immich` (assets metadata, albums, faces, embeddings) | CNPG `immich-1`, `local-path` 20Gi on `k8s-worker-1` | ~10G | A | physical: barman to S3 weekly + WAL, 30d. Logical: built-in dump daily to the NAS, 14 kept |
| `library/`, `upload/`, `profile/` (originals) | static PV `immich-library`, `jonbonas:/tank/media/immich` (RAIDZ1) | 32G | A | **none** |
| `backups/` (built-in SQL dumps) | same PV | 1.4G | A | none beyond RAIDZ1 |
| `thumbs/`, `encoded-video/` | same PV | 11.5G | C | none, regenerate from Jobs |
| Valkey queues | `immich-valkey`, `nfs-jonbonas` 1Gi | tiny | C | none |
| ML model cache | `immich-machine-learning`, `local-path` 10Gi | few G | C | none |

Secrets: S3 keys via ESO from Bitwarden. The DB role `immich-app` password is
CNPG-generated in cluster, see technos/kubernetes-state.md.

## Status: 🟡 DB, ❌ library

The database is well covered (both physical and logical, physical is offsite). The
photos are on a single RAIDZ1 array in the same rack as the cluster, with no snapshot and
no offsite copy. A double disk failure, a wrong `rm` over NFS (`no_root_squash`), or a
house event loses every original.

## TODO

1. restic of `library/`, `upload/`, `profile/`, `backups/` to Scaleway, nightly, from a
   ZFS snapshot ([../tools/restic-rclone.md](../tools/restic-rclone.md)). Priority 1 overall.
2. sanoid snapshots on `tank/media` ([../tools/zfs-snapshots-sanoid.md](../tools/zfs-snapshots-sanoid.md)).
3. Restore drill: CNPG recovery into `immich-restore`, point a throwaway Immich at it,
   confirm asset count. Then a single-photo restic restore.
4. Alert on `cnpg_collector_last_available_backup_timestamp` and on dump age.

## Restore

Order: files first, then DB, then start the server with the Immich version the DB was
dumped or backed up with.

1. Files: restic restore into `/tank/media/immich` (or `zfs rollback` if the loss is
   recent and the pool is fine).
2. DB, physical: [../tools/cnpg-barman-cloud.md](../tools/cnpg-barman-cloud.md) recovery
   section. DB, logical: [../tools/immich-database-dump.md](../tools/immich-database-dump.md).
3. Start `immich-server`, run Jobs: thumbnails, transcode, smart search if embeddings
   are stale.

Upstream reference: https://immich.app/docs/administration/backup-and-restore
