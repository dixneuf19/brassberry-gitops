# Spliit

Namespace `spliit`, chart `gitops/spliit/spliit`. Shared expenses with friends, class A
(other people's money).

## Data

| Data | Where | Class | Backup |
|---|---|---|---|
| Postgres `spliit` | CNPG `spliit-1`, 10Gi, **no storageClass so it falls to the default `nfs-client`** on brassberry-25's flaky USB disk | A | physical: barman to `s3://dixneuf19-cnpg-backups/physical/spliit`, weekly Sun 04:19 + WAL, 30d. Logical: none |
| Leftover PVC `data-spliit-postgresql-0` (pre-CNPG bitnami) | `nfs-client` 8Gi | none | stale, delete after confirming CNPG has everything |

App pods are stateless (2 replicas). DB role `spliit-app` is CNPG-generated.

## Status: ✅ backup, placement still wrong

Offsite physical backup with PITR works (`ContinuousArchiving=True`, first recoverability
point 2026-08-14). Two weaknesses: the live data sits on the least reliable disk in the
homelab, and there is no logical dump, so a Postgres 18 image problem would leave only
barman's binary format.

## TODO

1. Move the Cluster to `local-path` on `k8s-worker-1` (add `storageClass` + node affinity
   like Immich). CNPG cannot change storage class in place: bootstrap a new cluster with
   `recovery` from the ObjectStore, or `pg_basebackup` from the live one, then swap names.
   Good opportunity for the restore drill.
2. Weekly `pg_dump -Fc` CronJob to `s3://dixneuf19-cnpg-backups/logical/spliit/`
   ([../technos/postgres.md](../technos/postgres.md)).
3. Delete `data-spliit-postgresql-0` and fix the stale Grafana datasource that still
   points at the bitnami service.

## Restore

[../tools/cnpg-barman-cloud.md](../tools/cnpg-barman-cloud.md), replace `immich` with
`spliit`, image from the `postgresql-minimal-trixie` catalog major 18.
