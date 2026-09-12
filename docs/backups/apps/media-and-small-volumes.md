# Media and small volumes

Everything stateful that is not a database-backed app.

## Videos (netflix)

| Item | Value |
|---|---|
| Data | `/mnt/magadi_3T/Videos` on brassberry-27, NTFS USB disk (fuseblk), 1.9T used of 2.8T |
| Served by | `files` (miniserve, read-only) through the static PV `media-nfs` (`192.168.1.27`), and Jellyfin installed on the Pi by `ansible/playbooks/pi-jellyfin.yaml` |
| Class | C |
| Status | ⚪ accepted risk: downloaded media, re-downloadable. No backup wanted |
| Notes | the repo's `gitops/netflix/jellyfin/jellyfin-pv.yaml` says `192.168.1.26` while the live PV says `.27`, and that directory is not in `argocd/apps`, so a rebuild must apply it by hand. Jellyfin's own config on the Pi is unmanaged (class C, re-scan) |

## cd-lna files (default)

`cd-lna-files`, `nfs-client`, shared files served read-only by miniserve. Class B, ❌.
Fix: move the PVC to `nfs-jonbonas` so it lands in `/tank/data/default/cd-lna-files`
and gets NAS snapshots and the restic job for free. Old dir is retained on the NFS server.

## Slack OAuth installation files (dank-face-bot)

`dank-face-slack-oauth-credentials`, `nfs-client`, mounted at `/data` by
`dank-face-slack-bot`. Class B, ❌. Loss means re-installing the Slack app in each
workspace. Same fix as cd-lna: move to `nfs-jonbonas`. Alternatively store the
installation in Bitwarden once and load it via ESO.

## Rebuildable small volumes (♻️)

- `dank-face-bot-pics` (`/tmp/pics` scratch shared by the three bots)
- `librespeed-config`
- `karakeep-meilisearch` (see apps/karakeep.md)

## Leftover volumes

`nfs-client` is `Retain`, so decommissioned apps left directories under
`/mnt/tuyhoa_2T` on brassberry-25 (117G used, most of it orphans): mastodon (Postgres,
Redis, Elasticsearch, assets), superset, tekton, baj MySQL, eternal-jukebox MySQL and
data, vikunja Postgres, readeck, grist (final tarball also under
`/tank/data/backups/grist/`), transmission, deluge, rutorrent, `cluster-example-*`
(CNPG tests), old karakeep, old kps PVCs.

Decision needed per directory: keep a final tarball on `/tank/data/backups/<app>/` (as
done for grist and karakeep) or delete. None of it is backed up, and the disk is flaky,
so anything with value should be tarred to the NAS before the disk dies. Tracked in the
personal TODO (nfs-jonbonas migration).
