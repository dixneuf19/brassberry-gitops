# Lyrion Music Server (lms, lms-yoshi)

Two instances of the TrueCharts `lyrion-music-server` chart: `lms` (home) and
`lms-yoshi` (radioyoshi, Bogota time zone).

## Data

| Data | Where | Class | Backup |
|---|---|---|---|
| `/config`: server prefs, plugins, player settings, favourites, playlists, the library SQLite cache | `lyrion-music-server-config` (lms), `radioyoshi-lyrion-music-server-config` (lms-yoshi), both `nfs-client` RWX, 100Gi requested | B (hours to redo by hand) | **none** |
| Stale PVC `logitech-media-server-config` (old chart name) | `nfs-client` 100Gi | none | check content, then delete |

The music library itself is not mounted from git; it is streamed or lives elsewhere.

## Status: ❌

SQLite on NFS again (library cache, prefs.db). Corruption would cost a rescan and the
favourites and playlists.

## TODO

1. Move `/config` to `local-path` RWO with a node pin. The TrueCharts chart sets a
   `storageClass` per persistence entry; override `persistence.config.storageClass`.
   Real size is far below 100Gi, right-size when moving.
2. Weekly tar of `/config` minus `cache/` to an `<app>-backups` PVC on `nfs-backups` with
   the Karakeep CronJob pattern (Lyrion has no built-in backup). Stop-free tar of prefs is acceptable
   for class B; the SQLite cache is rebuildable by a rescan.
3. Delete the stale `logitech-media-server-config` PVC.

## Restore

Scale to 0, untar over `/config`, scale up, trigger a rescan.
