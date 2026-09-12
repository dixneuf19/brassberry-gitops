# PostgreSQL

All Postgres here runs under CloudNativePG (CNPG) 1.30, single instance per cluster.
Clusters: `immich/immich` (PG 17 + vectorchord image) and `spliit/spliit` (PG 18 from the
`postgresql-minimal-trixie` image catalog).

## Physical vs logical for Postgres

| | Physical: base backup + WAL | Logical: `pg_dump` / `pg_dumpall` |
|---|---|---|
| Tool here | `plugin-barman-cloud` (CNPG-I plugin), `ObjectStore` + `ScheduledBackup` CRDs | Immich built-in dump (`pg_dumpall \| gzip`), pg_dump CronJob (not yet) |
| Granularity | whole instance | per database, per table possible |
| PITR | yes, any second between first recoverability point and now | no |
| Restore target | CNPG Cluster with `bootstrap.recovery`, same major version, same extensions available in the image | any Postgres of same or newer major, `psql < dump` |
| Size | data dir + WAL stream, zstd compressed | text, gzip, typically 3 to 10x smaller |
| Extensions | binary, so vectorchord data comes along and the target image must ship `vchord.so` | dump contains `CREATE EXTENSION`, target must have it installed |
| Failure it catches | none, copies pages as-is | table-level corruption makes the dump fail |

Rule: class A databases get both. Physical for RPO and speed, logical for the
"CNPG or the image is gone" scenario and for major-version jumps.

## Current state

| Cluster | Storage | Physical | Logical | First recoverability point |
|---|---|---|---|---|
| immich | `local-path` 20Gi on `k8s-worker-1` | weekly base Sun 03:19 + continuous WAL, `s3://dixneuf19-cnpg-backups/physical/immich`, 30d | Immich built-in, daily 02:00, 14 kept, on the NAS in the library folder | 2026-08-14 |
| spliit | default class, so `nfs-client` on brassberry-25 (bad) | weekly base Sun 04:19 + continuous WAL, `s3://dixneuf19-cnpg-backups/physical/spliit`, 30d | none | 2026-08-14 |

Both clusters report `ContinuousArchiving=True` and `LastBackupSucceeded=True` (checked
2026-09-12). Details and commands in [../tools/cnpg-barman-cloud.md](../tools/cnpg-barman-cloud.md).

## Gaps

- No logical dump for Spliit. Immich has one (built-in), but it sits in the library
  folder on the NAS, not offsite.
- Spliit data directory is on NFS. Move to `local-path` with a node pin, see
  [../apps/spliit.md](../apps/spliit.md).
- No restore has been tested (accepted, not blocking). No `bootstrap.recovery` manifest
  exists in the repo; the tool page has the template.
- No alert on backup age or WAL archive failures.
- `instances: 1` everywhere: a restore is a full RTO, there is no replica to promote.

## Planned: pg_dump CronJob into the landing zone

One CronJob per cluster, weekly, using the CNPG-generated app secret
([../tools/backup-landing-zone.md](../tools/backup-landing-zone.md)):

- image: the same Postgres image as the cluster (so `pg_dump` matches the server major)
- command: `pg_dump -Fc -d "$DB" -f /backup/<cluster>-<date>.dump.tmp && mv` to the final
  name, `/backup` being the `<cluster>-backups` PVC on `nfs-backups`
- `-Fc` custom format restores selectively with `pg_restore`, and stays readable by any
  newer `pg_restore`
- keep 8, `find -mtime +56 -delete`; the landing zone ships it offsite and keeps 90 days
  of versions
- Immich already produces a plain-SQL dump nightly, so its pg_dump job is optional; the
  Spliit one is not
- the `logical/` lifecycle rule in `terraform/scaleway/cnpg_backups.tf` becomes unused

## Restore, short version

Physical, into a new cluster (PITR possible):

```yaml
bootstrap:
  recovery:
    source: immich-backup
    recoveryTarget:
      targetTime: "2026-09-10 12:00:00+00"   # optional
externalClusters:
  - name: immich-backup
    plugin:
      name: barman-cloud.cloudnative-pg.io
      parameters:
        barmanObjectName: immich-backup
        serverName: immich
```

Logical, from an Immich dump:

```bash
gunzip -c immich-db-backup-<stamp>.sql.gz | kubectl exec -i -n immich immich-1 -- psql -U postgres
```

Full procedures in the tool pages.
