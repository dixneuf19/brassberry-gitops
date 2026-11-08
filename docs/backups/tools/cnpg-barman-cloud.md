# CNPG + plugin-barman-cloud

Physical Postgres backups: weekly base backup plus continuous WAL archiving to Scaleway
Object Storage, with point-in-time recovery inside a 30-day window.

## Versions

| Component | Version | Where |
|---|---|---|
| CloudNativePG operator | 1.30.0 (chart 0.29.0) | `gitops/cnpg-system/cloudnative-pg/Chart.yaml` |
| plugin-barman-cloud | v0.15.0 (chart 0.8.0) | same chart, dependency |
| Image catalogs | `cloudnative-pg/artifacts` tracked by the `cnpg-image-catalogs` Application | `gitops/argocd/apps/values.yaml` |

The in-tree `spec.backup.barmanObjectStore` is deprecated in 1.30, so the plugin path is
the only supported one.

## How it is wired (per cluster)

```
ExternalSecret <cluster>-backup-s3  (Bitwarden: cnpg-backup-access-key-id / -secret-access-key)
        │
ObjectStore <cluster>-backup        destinationPath s3://dixneuf19-cnpg-backups/physical/<cluster>
        │                           endpoint https://s3.fr-par.scw.cloud, wal.compression zstd, retentionPolicy 30d
Cluster <cluster>                   plugins: barman-cloud.cloudnative-pg.io, isWALArchiver: true, barmanObjectName
        │
ScheduledBackup <cluster>-weekly    method: plugin, immediate: true, schedule "0 19 3 * * 0" (6 fields, seconds first)
```

Files: `gitops/immich/immich/templates/{objectstore,scheduled-backup,external-secret-backup,postgres-cluster}.yaml`
and the same names under `gitops/spliit/spliit/templates/`.

Scaleway quirks baked into `instanceSidecarConfiguration.env`: `AWS_DEFAULT_REGION=fr-par`
(cloudnative-pg#9724) and `AWS_REQUEST_CHECKSUM_CALCULATION` /
`AWS_RESPONSE_CHECKSUM_VALIDATION=when_required` (Scaleway rejects the newer SDK
checksums).

Schedules are offset to `:19` so both clusters and Karakeep do not start at the same
minute (commit `5a4b1bc1`). Immich Sunday 03:19, Spliit Sunday 04:19, operator time
zone (UTC).

## Retention

`retentionPolicy: 30d`: barman keeps every base backup needed to restore any point in
the last 30 days, and deletes older WAL. The bucket has no lifecycle rule on `physical/`,
barman is the only pruner. The bucket is **not versioned** and the IAM key has
`ObjectsDelete`, so a bug or a compromised key can erase the history.

## Check it

```bash
kubectl get scheduledbackup,backup,objectstore -A
kubectl get cluster -n immich immich -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.message}{"\n"}{end}'
kubectl get objectstore -n immich immich-backup -o jsonpath='{.status.serverRecoveryWindow}'
kubectl cnpg status -n immich immich          # needs the kubectl-cnpg plugin
```

Healthy output: `ContinuousArchiving=True`, `LastBackupSucceeded=True`, a
`firstRecoverabilityPoint` about 30 days back, `lastSuccessfulBackupTime` under 8 days.

Manual backup before a risky migration (done on 2026-09-11 for Immich):

```bash
kubectl cnpg backup immich -n immich --method plugin --plugin-name barman-cloud.cloudnative-pg.io
```

## Restore

Recovery creates a **new** Cluster from the object store; CNPG never restores in place.

1. Pause ArgoCD auto-sync on the app (`argocd app set immich --sync-policy none`), scale
   the app Deployments to 0.
2. Rename the source in the ObjectStore or use a new cluster name, so the recovered
   cluster does not archive WAL over the source's `serverName`.
3. Apply a Cluster with:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: immich-restore
  namespace: immich
spec:
  instances: 1
  imageName: ghcr.io/tensorchord/cloudnative-vectorchord:17.9-1.1.1   # same as source
  storage: { size: 20Gi, storageClass: local-path }
  postgresql:
    shared_preload_libraries: ["vchord.so"]
  bootstrap:
    recovery:
      source: immich-backup
      # recoveryTarget: { targetTime: "2026-09-10 12:00:00+00" }     # PITR, optional
  externalClusters:
    - name: immich-backup
      plugin:
        name: barman-cloud.cloudnative-pg.io
        parameters:
          barmanObjectName: immich-backup
          serverName: immich
  plugins:                       # re-enable archiving on the new cluster, to a NEW serverName
    - name: barman-cloud.cloudnative-pg.io
      isWALArchiver: true
      parameters: { barmanObjectName: immich-backup, serverName: immich-restore }
```

4. Wait for `Cluster in healthy state`, check row counts, then point the app at
   `immich-restore-rw` (or swap names in git and let ArgoCD converge).
5. The `immich-app` role password inside the restored data is the old one. CNPG creates a
   new `immich-restore-app` Secret; align with `ALTER ROLE "immich-app" PASSWORD '...'`
   or reference the old Secret via `bootstrap.recovery.secret`.

Drill status: never run. Not blocking for ✅ (see strategy.md principle 4); the Spliit
storage-class move will be the first real run.

## Known limits

- Same major version and same extensions required on the target image. vectorchord
  data cannot be restored into a plain `postgresql` image.
- Single instance clusters: restore is the only recovery path, there is no replica.
- The S3 key expires **2027-05-20**. Rotate before, WAL archiving fails silently after.
