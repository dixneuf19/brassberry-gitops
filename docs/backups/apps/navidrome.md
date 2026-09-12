# Navidrome and SoundHoard

Namespace `soundhoard`. Navidrome (music server) and the SoundHoard bot that downloads
into the shared music volume.

## Data

| Data | Where | Class | Backup |
|---|---|---|---|
| Navidrome SQLite (users, play counts, ratings, playlists, scan state) | `navidrome-config`, `nfs-client` RWX | A (listening history) | **none** |
| Music files | `soundhoard-music`, `nfs-client` RWX, shared with the bot | C | none, re-rippable |

Secret `ND_PASSWORDENCRYPTIONKEY` in Bitwarden via ESO: required to read existing user
passwords after a restore.

## Status: ❌ DB, ⚪ music

The DB corrupted on 2026-07-27 (SQLite on NFS, see the memory and technos/sqlite.md) and
14 per-track annotations were lost for good. It is still on NFS and still unbacked.

## TODO

1. Move `navidrome-config` to `local-path` RWO on a pinned node (Karakeep pattern,
   PR #1673), `Prune=false`. Delete + recreate the PVC, old NFS dir is retained.
2. Backup, pick one:
   - Navidrome built-in: `ND_BACKUP_SCHEDULE="0 3 * * *"`, `ND_BACKUP_PATH=/backup`,
     `ND_BACKUP_COUNT=14`, with `/backup` an `nfs-jonbonas` PVC. Same online `.backup`
     call, zero extra manifests. Preferred.
   - Or the Karakeep CronJob copied.
3. Include the backup dir in the NAS restic job.

## Restore

Scale to 0, copy the backup `navidrome.db` over `/data/navidrome.db`, remove `-wal` and
`-shm`, scale up, let the scanner run. Music is re-downloaded by the bot or from the
laptop.
