# Backup landing zone (`tank/backups`, storage class `nfs-backups`)

Status: **design, not deployed** (2026-09-12). This is the pattern every small backup
should converge on.

## Idea

One ZFS dataset on the NAS receives every app-level backup: SQL dumps, `sqlite3 .backup`
tarballs, config archives, Immich's built-in dumps. Apps only need to know "write my
backup into my `<app>-backups` PVC". One job snapshots that dataset and ships the whole
thing offsite. Adding a backup for a new app is then a PVC and a schedule, never a new
S3 bucket, key, or sync job.

Limited to **small** backups: dumps and tarballs, tens of GB total. Bulk data (Immich
originals, videos, music) is not duplicated here; the originals have their own row in
the recap and their own offsite path where it exists.

```
 app A ─┐ CronJob / in-app backup        ┌─ sanoid daily snapshots (undo)
 app B ─┼──> PVC <app>-backups ──> tank/backups ─┤
 app C ─┘   (nfs-backups SC)      /tank/backups/<ns>/<pvc>/   └─ rclone sync from the latest snapshot ──> Scaleway bucket (versioned)
```

## Pieces

| Piece | Where | Detail |
|---|---|---|
| Dataset | `jonbonas` `tank/backups` | already exists (recordsize 1M, zstd), empty. Add `quota=200G` so "small" is enforced by ZFS, not by discipline |
| NFS export | `ansible/playbooks/proxmox-nfs.yaml` | add `/tank/backups` to `nfs_exports` |
| StorageClass `nfs-backups` | new chart `gitops/storage/nfs-backups-provisioner` | copy of `nfs-jonbonas-provisioner` with `path: /tank/backups`, `pathPattern: "${.PVC.namespace}/${.PVC.name}"`, `Retain`, `archiveOnDelete: true`, RWX. Third nfs-subdir provisioner, same image |
| PVC convention | each app chart | `<app>-backups`, `storageClassName: nfs-backups`, annotation `argocd.argoproj.io/sync-options: Prune=false`, mounted at `/backup` |
| Snapshots | sanoid on `jonbonas` | `tank/backups`: daily 14, monthly 3. Hourly is pointless for nightly writers |
| Offsite | systemd timer on `jonbonas`, daily 06:00 | `rclone sync /tank/backups/.zfs/snapshot/<latest daily>/ scw:dixneuf19-backups/` with `--exclude dump/**` (vzdump output, too big). Bucket in its own Scaleway project, versioning on, lifecycle expiring non-current versions after 90 days |
| Alert | node-exporter textfile on `jonbonas` | `backup_landing_rclone_last_success_timestamp`, alert if older than 2 days |

Why rclone and not restic here: the files are already self-contained, compressed and
consistent (dumps, tarballs), so restic's dedup and snapshotting add little, and a lost
restic password would lose everything. `rclone sync` plus bucket versioning gives
history for 90 days, restore is browsing the bucket, and the only secret is the S3 key.
restic stays the pick for the Immich originals where per-file history matters
([restic-rclone.md](restic-rclone.md)).

## Producers to plug in

| App | Today | With the landing zone |
|---|---|---|
| Karakeep | CronJob writes to `karakeep-backups` on `nfs-jonbonas` (`/tank/data/karakeep/karakeep-backups`) | same CronJob, PVC recreated on `nfs-backups`. Data is backups, so delete + recreate is low risk |
| Immich built-in dump | writes to `<library>/backups` on `/tank/media/immich/backups` | mount an `immich-backups` PVC at `/usr/src/app/upload/backups` (Immich allows the `backups/` subfolder to be its own mount). Dumps then leave the library folder and get shipped |
| Immich and Spliit Postgres, logical | none (only barman physical to S3) | weekly CronJob per cluster: `pg_dump -Fc` into `<cluster>-backups`, keep 8. Uses the CNPG-generated app Secret, cluster image, no S3 creds. The `logical/` lifecycle rule in `terraform/scaleway/cnpg_backups.tf` becomes unused and can go |
| Lyrion (lms, lms-yoshi) | none | weekly tar of `/config` minus `cache/` into `<app>-backups`, keep 8 |
| Navidrome | none, DB is accepted risk | optional `ND_BACKUP_PATH=/backup` if ever wanted, one PVC |
| Ad-hoc dumps (`/tank/data/backups/<app>/`) | on `tank/data`, not shipped | move to `/tank/backups/adhoc/<app>/` |
| k0s pre-upgrade snapshot | laptop | copy into `/tank/backups/adhoc/k0s/` when taken |

## Rules

- A producer must leave **only finished files**: write to a temp name, rename at the end
  (Karakeep's script does `work/` then `tar` directly to the final name; the rclone job
  runs from a snapshot, so a half-written file is never shipped anyway).
- Each producer prunes its own directory (`find -mtime +N -delete`). rclone mirrors the
  deletion; the bucket keeps the old version 90 more days.
- Nothing bulky. If a producer would exceed a few GB per copy, it does not belong here.
- Do not point vzdump at `tank-backups` unless `dump/` stays excluded from the sync.

## Restore

- Recent mistake: `ls /tank/backups/.zfs/snapshot/`, copy the file back.
- NAS lost: `rclone copy scw:dixneuf19-backups/<ns>/<pvc>/ /tmp/r/` (or a specific
  version via `--s3-version-at`), then the app's own restore steps in its `apps/` page.

## Rollout order

1. Ansible: quota, export, sanoid config for `tank/backups`.
2. Terraform (`terraform/scaleway`): bucket + project + key, versioning, lifecycle; key
   into Bitwarden via `terraform/bitwarden`.
3. `nfs-backups-provisioner` chart + ArgoCD app.
4. rclone timer on `jonbonas` (Ansible), verify with an empty sync.
5. Move Karakeep's PVC, then Immich's `backups/` mount, then add the pg_dump CronJobs.
6. Flip the README rows: Karakeep to ✅, Immich dumps offsite yes, Spliit logical yes.
