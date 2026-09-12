# Strategy

## Principles

1. **Redundancy is not backup.** RAIDZ1 on `tank` survives one dead disk. It does nothing
   against `rm -rf`, a bad migration, ransomware, a buggy Ansible run with `force: true`,
   or the house burning. Every row in the recap marked "RAIDZ1 only" is unprotected.
2. **3-2-1, adapted.** Three copies, two media, one offsite. For this homelab: the live
   data, a copy on `tank`, a copy on Scaleway Object Storage. Offsite means another
   building, so the NAS in the same rack as the cluster does not count.
3. **Prefer logical for portability, physical for point-in-time.** Keep both when the
   data is irreplaceable and the engine supports it (Postgres). See the next section.
4. **Every ✅ row needs a written restore procedure.** The enterprise rule "a backup is not
   a backup until restored" is relaxed here on purpose: this is a homelab, the tools in use
   (CNPG barman-cloud, `sqlite3 .backup`) restore reliably, and the risk is low. Drills
   are still worth running for class A data once, and after a tool change, but they do
   not gate the status.
5. **Boring beats clever.** A CronJob running the engine's own backup command into a PVC
   is preferred over an operator with CRDs, unless the operator is already there (CNPG).
6. **Monitor the backup, not the job.** Alert on "last successful backup older than X",
   not on "job failed", because a job that never runs never fails.

## Physical vs logical

| | Physical | Logical |
|---|---|---|
| What it copies | Bytes as the engine writes them: data files, WAL, ZFS blocks, disk image | An export the engine re-imports: SQL text, `sqlite3 .backup`, tar of files |
| Consistency | Needs engine cooperation (WAL, `.backup` API) or a filesystem snapshot | Consistent by construction, taken through the engine |
| Point in time recovery | Yes with WAL archiving (Postgres), yes with frequent snapshots (ZFS) | No, you get the moment of the dump |
| Portability | Same engine, same major version, often same architecture | Across versions, sometimes across engines |
| Speed to restore | Fast for large data (no re-import) | Slow: replays every row, rebuilds indexes |
| Detects corruption | No, faithfully copies corrupted pages | Often yes, a dump fails on a broken table |
| Examples here | CNPG barman base backup + WAL, ZFS snapshot of `tank`, vzdump of the VM | Immich `pg_dumpall`, Karakeep `sqlite3 .backup` + tar, pg_dump |

Rule: **irreplaceable database = physical + logical**. Physical gives PITR and fast
restore, logical gives a version-independent escape hatch and catches silent corruption.
Immich follows this rule today (barman + built-in dump). Spliit has physical only.

## Failure domains of this homelab

| Domain | What dies with it |
|---|---|
| One disk of `tank` | nothing (RAIDZ1) |
| Two disks of `tank` | Immich library, Karakeep tarballs, Immich dumps, every `nfs-jonbonas` PVC |
| `fastpool` NVMe | `k8s-worker-1` and every `local-path` PVC on it: Immich DB (recoverable from S3), Karakeep data (recoverable from NAS tarball, up to 24h loss) |
| `brassberry-25` USB disk | every `nfs-client` PVC: Spliit DB (recoverable from S3), SoundHoard music, Lyrion configs, Slack OAuth tokens, cd-lna (all lost), Grafana (rebuilt from git) |
| `brassberry-27` USB disk | Videos, Prometheus (both accepted) |
| `brassberry-24` SSD | etcd: cluster rebuild from git, in-cluster generated secrets lost |
| The house | everything except the two Postgres databases and Terraform state |
| Scaleway account | offsite copies and Terraform state (buckets are in separate projects, the CNPG bucket is not versioned) |

## Data classes and targets

Targets, not current state. The recap table says what is met.

| Class | Examples | RPO | RTO | Copies | Restore drill |
|---|---|---|---|---|---|
| A: irreplaceable personal data | Immich library + DB, Spliit DB, Karakeep DB + assets, SoundHoard music files | 24h | 1 day | 3-2-1, offsite mandatory | once, then after tool changes |
| B: valuable config, painful to redo | Lyrion configs, Slack OAuth tokens, cd-lna, in-cluster generated secrets | 7d | 1 week | 2 copies, NAS is enough | when the tool changes |
| C: derived or re-downloadable | thumbs, ML models, Meilisearch, Prometheus, Valkey, Videos, Navidrome play history, Grafana (everything is provisioned from git) | none | rebuild | live copy only | none |
| P: platform state | etcd, Bitwarden SM, Terraform state | 24h | 1 day | offsite | once |

## Storage placement rules

These come from incidents, see the memory and git history.

- **SQLite never on NFS.** WAL mode needs mmap and POSIX locks that NFS does not give.
  Navidrome corrupted on 2026-07-27, Karakeep was moved to `local-path` (PR #1673).
  Navidrome and Lyrion are still on `nfs-client`; Grafana too, until its PVC is dropped.
- **Rebuildable apps get no PVC.** If everything an app holds comes from git (Grafana),
  run it without persistence so state cannot silently accumulate outside GitOps.
- **Postgres data on `local-path`**, never NFS. Spliit currently falls to the default
  class `nfs-client` because its Cluster has no `storageClass`.
- **`local-path` reclaim policy is `Delete`**: pruning the PVC runs `rm -rf`. Guard PVCs
  with `argocd.argoproj.io/sync-options: Prune=false` (Karakeep does) and never put data
  there without a backup landing elsewhere.
- **NAS is for data at rest** (backups, media), `nfs-jonbonas` for RWX volumes that are
  not databases. Both NFS classes are `Retain` + `archiveOnDelete`, which is the only
  "oops" protection they have.
- `nfs-client` (brassberry-25) is the cluster default and sits on a flaky USB disk. New
  PVCs must set `storageClassName` explicitly until the default is flipped.

## Retention

| Copy | Retention | Why |
|---|---|---|
| CNPG physical (S3 `physical/`) | 30d, barman-managed | Enough to notice a bad migration, cheap |
| Postgres logical (S3 `logical/`, not yet produced) | Glacier at 90d, delete at 365d (bucket lifecycle) | Yearly escape hatch, version-independent |
| Immich built-in dumps (NAS) | last 14 | Immich default |
| Karakeep tarballs (NAS) | 14d | Assets are write-once, 14 nightly copies is plenty |
| Terraform state | all versions | Tiny, and rollback matters |
| ZFS snapshots (planned) | hourly 24, daily 14, monthly 3 | sanoid default-ish, see tools page |

## Monitoring (target)

Nothing alerts on backup age today. Wanted:

- PrometheusRule on `cnpg_collector_last_available_backup_timestamp` older than 8 days
  and on `cnpg_collector_pg_wal_archive_status` failures (CNPG exports both).
- `kube_cronjob_status_last_successful_time` for `karakeep/karakeep-backup` older than 2 days.
- A file-age check for `/tank/media/immich/backups` and, once it exists, for offsite
  restic snapshots.
- Calendar reminder: the CNPG S3 key expires **2027-05-20**, WAL archiving then breaks
  silently ([tools/scaleway-object-storage.md](tools/scaleway-object-storage.md)).

## Priorities (2026-09)

Ordered by blast radius divided by effort.

1. **Offsite copy of the Immich library** (32G originals, growing). restic or rclone to a
   Scaleway bucket, nightly. This is the single largest irreplaceable dataset with zero
   backup. [technos/files.md](technos/files.md)
2. **ZFS snapshots on `tank`** with sanoid. Cheap, instant, protects every NAS dataset
   against deletion and bad writes. [tools/zfs-snapshots-sanoid.md](tools/zfs-snapshots-sanoid.md)
3. **SoundHoard music files** off the flaky `nfs-client` disk onto `nfs-jonbonas`, so
   they land on `tank` and ride the snapshot + restic jobs. **Lyrion**: move to
   `local-path`, add the Karakeep-style CronJob. [apps/navidrome.md](apps/navidrome.md), [apps/lyrion.md](apps/lyrion.md)
4. **Karakeep tarballs offsite**: sync `/tank/data/karakeep/karakeep-backups` to S3 in the
   same restic job as item 1.
5. **Spliit off `nfs-client`** onto `local-path`, plus a logical dump. [apps/spliit.md](apps/spliit.md)
6. **`k0s backup` on a schedule** to the NAS. [tools/k0s-backup.md](tools/k0s-backup.md)
7. **Bitwarden export** procedure, and export the in-cluster generated secrets once.
8. **Backup-age alerts** as listed above.
9. Restore drill for Immich (CNPG recovery into a throwaway cluster) and Karakeep, nice
   to have. Spliit's move off `nfs-client` (item 5) doubles as the CNPG drill.

## Decision guide for a new stateful app

1. What is the data? Classify it A, B, C or P (table above). Class C: stop here, write
   the ♻️ row in the README.
2. Which techno? Open the matching `technos/` page. It says what physical and logical
   mean for that engine and which tool to reuse.
3. Placement: database on `local-path` (RWO, pinned node, `Prune=false`), files on
   `nfs-jonbonas`, never SQLite or Postgres on NFS.
4. Backup: reuse an existing tool. Postgres: CNPG + barman ObjectStore + ScheduledBackup.
   SQLite or files: copy the Karakeep CronJob. Bulk files on the NAS: add the dataset to
   the (future) restic job.
5. Offsite for class A: the copy must reach Scaleway.
6. Write `apps/<app>.md` with: what, where, how, retention, restore steps, gaps. Add the
   README row. A written restore procedure is enough for ✅; a drill is a bonus.

## Restore drill log

| Date | What | Method | Result | Notes |
|---|---|---|---|---|
| none yet | | | | Immich CNPG recovery and Karakeep tarball restore are the first two to run |
