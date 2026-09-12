# Files and blobs

Photos, videos, music, archived web pages, config directories. Anything where the unit is
a file and the app does not need a consistent multi-file snapshot.

## Physical vs logical for files

| | Physical: block or filesystem level | Logical: file level |
|---|---|---|
| Tools | ZFS snapshot, `zfs send`, vzdump of a VM disk | `tar` in a CronJob, `rsync`, restic, rclone |
| Consistency | atomic for the whole dataset | per file; a file written during the copy may be torn (fine for write-once media, not for databases) |
| Restore granularity | whole dataset (or browse `.zfs/snapshot`) | single file |
| Offsite | needs a ZFS receiver or a stream-to-object tool | any S3 bucket |
| Dedup / encryption | ZFS native compression, encryption per dataset | restic: content-defined dedup + encryption; rclone: plain mirror, optional crypt remote |

Rule: **snapshot then copy**. Take a ZFS snapshot (physical, instant), run the file-level
offsite tool from the snapshot path (logical, browsable, cheap). For data not on ZFS
(`nfs-client`, `local-path` on the Pis), a `tar` CronJob into an `nfs-jonbonas` PVC is the
minimum, then the NAS job carries it offsite.

## What counts as irreplaceable

| Dataset | Where | Size | Class | Notes |
|---|---|---|---|---|
| Immich originals `library/`, `upload/`, `profile/` | `tank/media/immich` | 32G + | A | Immich docs: back up these three plus the DB; `thumbs/` and `encoded-video/` regenerate |
| Karakeep `assets/` | `local-path` on `k8s-worker-1`, tarred nightly to `tank/data/karakeep/karakeep-backups` | ~400M per tarball | A | write-once archives and screenshots |
| cd-lna files | `nfs-client` | small | B | shared files, no other copy |
| Slack OAuth installation files (dank-face-slack-bot) | `nfs-client` | tiny | B | re-installing the Slack app regenerates them, annoying |
| Lyrion `/config` (also holds SQLite, see sqlite.md) | `nfs-client` | unknown, 100Gi requested | B | |
| SoundHoard music (mp3) | `nfs-client` | unknown | A | the owner wants these kept; the Navidrome DB around them is disposable |
| Videos | `brassberry-27:/mnt/magadi_3T/Videos` | 1.9T | C | re-downloadable, accepted |

## Current state

Nothing file-level goes offsite. Karakeep is the only file dataset with an automated
second copy, and it stays in the house.

## Planned

One restic repository on Scaleway (`fr-par`, own project like the CNPG bucket), fed by a
systemd timer on `jonbonas` after the sanoid snapshot:

- `tank/media/immich/{library,upload,profile,backups}` (originals + Immich SQL dumps)
- `tank/data/karakeep/karakeep-backups` (already consistent tarballs)
- `tank/data/backups` (ad-hoc dumps)
- `tank/data/soundhoard/soundhoard-music` once the PVC has moved to `nfs-jonbonas`

Retention `--keep-daily 14 --keep-weekly 8 --keep-monthly 12`, `restic check --read-data-subset`
monthly. Bucket lifecycle to Glacier is not compatible with restic's random reads, keep
it on Standard or One Zone IA. Details in [../tools/restic-rclone.md](../tools/restic-rclone.md).

For the small `nfs-client` volumes (cd-lna, Slack OAuth), the cheapest fix is moving them
to `nfs-jonbonas` so they land under `/tank/data` and get snapshots for free.

## Restore

- Single file: `restic restore latest --target /tmp/r --include /tank/media/immich/library/<path>`
- Everything: `restic restore latest --target /tank/media/immich` with Immich scaled to 0, then
  restore the DB (physical or logical), then start Immich and let it re-generate thumbs.
