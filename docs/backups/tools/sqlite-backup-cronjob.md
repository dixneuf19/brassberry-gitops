# CronJob: `sqlite3 .backup` + tar

Reference implementation: Karakeep. Files `gitops/karakeep/karakeep/templates/backup-cronjob.yaml`
and `gitops/karakeep/karakeep/files/backup.sh`, values under `backup:` in `values.yaml`.

## How it works

1. Nightly (`30 3 * * *`), an `alpine` pod is scheduled on the same node as the app
   (nodeSelector, because `local-path` is node-bound) and mounts the data PVC read-only
   and a backup PVC (`karakeep-backups`, `nfs-jonbonas` 20Gi, so it lands in
   `/tank/data/karakeep/karakeep-backups/`).
2. `sqlite3 "$DATA_DIR/db.db" ".backup work/db.db"` takes a consistent online copy.
3. `PRAGMA integrity_check` on the copy, the job fails otherwise.
4. `tar czf karakeep-<date>.tar.gz db.db assets` (assets are write-once files, plain tar
   is safe).
5. `find -mtime +14 -delete` prunes.

Script has `set -euo pipefail`, a `trap` cleaning the work dir, and both PVCs carry
`argocd.argoproj.io/sync-options: Prune=false`.

## Reuse for another app

Copy the CronJob template and script, then change: the DB filename, the asset directory
list, the nodeSelector, the backup PVC name (`<app>-backups`, `nfs-jonbonas`), and the
schedule (keep a unique minute, avoid the top of the hour and 03:19/04:19 used by CNPG).
Install `sqlite` at runtime as Karakeep does, or bake an image if the `apk add` becomes a
problem (a network blip fails the night's job silently).

Candidates: Navidrome (`/data/navidrome.db`), Lyrion (`/config/cache/*.db` and prefs),
Grafana (`grafana.db`) if someone decides UI dashboards matter.

## Check it

```bash
kubectl get cronjob -n karakeep karakeep-backup
kubectl get jobs -n karakeep --sort-by=.status.startTime | tail -3
ssh root@192.168.1.30 ls -la /tank/data/karakeep/karakeep-backups/
```

Wanted alert: `kube_cronjob_status_last_successful_time` older than 2 days.

## Restore

```bash
argocd app set karakeep --sync-policy none
kubectl scale deploy -n karakeep karakeep --replicas=0
# in a debug pod mounting karakeep-data at /data and karakeep-backups at /backup:
tar xzf /backup/karakeep-<stamp>.tar.gz -C /tmp/r
cp /tmp/r/db.db /data/db.db && rm -f /data/db.db-wal /data/db.db-shm
rsync -a /tmp/r/assets/ /data/assets/
kubectl scale deploy -n karakeep karakeep --replicas=1
argocd app set karakeep --sync-policy automated
```

Then reindex Meilisearch from the admin UI. Drill status: never run.

## Gaps

- Copies stay in the house. Offsite via the NAS restic job.
- 14 days is short if corruption goes unnoticed; a weekly copy kept 8 weeks would help.
- No alert.
