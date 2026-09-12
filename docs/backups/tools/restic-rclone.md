# restic or rclone to Scaleway (candidate)

Status: **not deployed**. Nothing file-level leaves the house today.

## restic vs rclone

| | restic | rclone sync |
|---|---|---|
| Model | encrypted, deduplicated repository with snapshots | plain mirror of the directory tree |
| Deleted or overwritten files | kept for `--keep-*` retention | gone on next sync unless `--backup-dir` or bucket versioning |
| Ransomware on the source | history survives | mirror is overwritten, versioning is the only protection |
| Restore | `restic restore`, `restic mount` | browse the bucket, `rclone copy` |
| Glacier | no (random reads on `check`/`prune`) | yes for write-once data |
| Fit | Immich originals, Karakeep tarballs, dumps | pushing already-versioned artifacts (dumps) to a cold prefix |

Pick restic. It is the standard answer for "files, offsite, keep history, encrypted".

## Proposed job (on `jonbonas`, systemd timer, after the sanoid daily snapshot)

- Repository: `s3:s3.fr-par.scw.cloud/dixneuf19-restic`, own Scaleway project and key
  (pattern in `terraform/scaleway/cnpg_backups.tf`), Standard storage class, no Glacier.
- Repo password: generated in `terraform/bitwarden`, also printed once and kept offline
  (losing it loses the backups).
- Sources, read from the newest daily snapshot so files are consistent:
  `/tank/media/.zfs/snapshot/<latest>/immich/{library,upload,profile,backups}`,
  `/tank/data/.zfs/snapshot/<latest>/karakeep/karakeep-backups`,
  `/tank/data/.zfs/snapshot/<latest>/backups`.
- Retention: `restic forget --keep-daily 14 --keep-weekly 8 --keep-monthly 12 --prune`.
- Weekly `restic check --read-data-subset=5%`.
- Alert: age of the last snapshot, exported as a textfile metric to node-exporter (already
  installed by `proxmox-node-exporter.yaml`).

Ansible playbook `ansible/playbooks/proxmox-restic.yaml`; the repo init is a one-time
step documented in `proxmox/README.md`, not a script.

## Size and cost

Immich originals 32G today, thumbs and encoded video excluded. Karakeep tarballs
dedupe well (same assets every night). Expect under 60G in year one.

## Restore

```bash
restic snapshots
restic restore latest --target /tmp/r --include /tank/media/immich/library/<user-id>/<path>
restic restore <id> --target /tank/media/immich          # full, with Immich stopped
```

Drill: restore one photo and one Karakeep tarball, compare checksums. Not run yet.
