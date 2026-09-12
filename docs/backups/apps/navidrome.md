# Navidrome and SoundHoard

Namespace `soundhoard`. Navidrome (music server) and the SoundHoard bot that downloads
into the shared music volume.

## Data

| Data | Where | Class | Backup |
|---|---|---|---|
| Music files (mp3) | `soundhoard-music`, `nfs-client` RWX on brassberry-25's flaky USB disk, shared by Navidrome (read-only) and the bot (`/music/SoundHoard`) | A, the thing to keep | **none** |
| Navidrome SQLite (users, play counts, ratings, playlists, scan state) | `navidrome-config`, `nfs-client` RWX | C | none, by decision |

Secret `ND_PASSWORDENCRYPTIONKEY` is in Bitwarden via ESO.

## Status: ❌ music, ⚪ DB

Decision (2026-09-12): the play history and library metadata are not worth protecting;
a rescan rebuilds the library and users are recreated by hand. The music files are the
irreplaceable part, and they sit on the least reliable disk in the homelab with no copy.

The DB corrupted on 2026-07-27 (SQLite on NFS). Accepted: if it happens again, delete
`navidrome-config`, let the PVC recreate, rescan. Moving it to `local-path` is still
good hygiene but not a backup task.

## TODO

1. Move `soundhoard-music` to `nfs-jonbonas`: rsync the directory to
   `/tank/data/soundhoard/soundhoard-music/`, pause ArgoCD auto-sync, scale Navidrome and
   the bot to 0, switch `storageClassName`, delete and recreate the PVC (old dir retained
   on brassberry-25). Runbook in the personal TODO `nfs-jonbonas-migration.md`.
2. Once on `tank`: covered by sanoid snapshots and the restic job
   ([../tools/restic-rclone.md](../tools/restic-rclone.md)), no app-specific work.
3. Optional: keep a plain copy on the laptop or a phone, mp3s are small.

## Restore

Restic (or `.zfs/snapshot`) restore into `/tank/data/soundhoard/soundhoard-music/`,
then trigger a Navidrome rescan.
