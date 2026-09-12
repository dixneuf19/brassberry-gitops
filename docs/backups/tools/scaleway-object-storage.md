# Scaleway Object Storage

The only offsite location. Region `fr-par`, endpoint `https://s3.fr-par.scw.cloud`,
managed in `terraform/scaleway/`.

| Bucket | Project | Versioning | Lifecycle | Content | IAM key |
|---|---|---|---|---|---|
| `dixneuf19-tfstates` | default | **yes** | none | Terraform state, 5 roots | operator's `scw` profile, plus `burrito-runner` |
| `dixneuf19-cnpg-backups` | `cnpg-backups` | no | `logical/` prefix: Glacier at 90d, delete at 365d. `physical/` untouched, barman prunes | `physical/immich`, `physical/spliit` | `cnpg-backups` app, project-scoped, Read/Write/Delete objects, **expires 2027-05-20** |
| `dixneuf19-burrito-datastore` | `burrito-datastore` | no | delete at 90d | plans, logs, git bundles | `burrito-datastore` app, expires 2027-08-15 |

Permission sets are project-scoped, never bucket-scoped, hence one project per purpose.
The `burrito-runner` key has org-wide `ObjectStorageFullAccess` and `IAMManager` and can
delete every bucket above.

## Rules for a new backup bucket

- Own Scaleway project, own IAM application, key limited to that project.
- `expires_at` is mandated by org policy: put the date in this doc and in a calendar,
  the code comment says it breaks silently.
- Versioning or object lock for anything a key with `Delete` writes to. The CNPG bucket
  has neither: TODO, either enable versioning with a lifecycle on non-current versions,
  or drop `ObjectStorageObjectsDelete` and let a separate lifecycle rule prune.
- Glacier only for data written once and read on disaster (dumps). Not for restic
  repositories, which read random blobs during `check` and `prune`.

## Key rotation (before 2027-05-20)

1. Bump `expires_at` in `terraform/scaleway/cnpg_backups.tf` (a new key is created).
2. `terraform apply` in `terraform/scaleway`, then in `terraform/bitwarden` (reads the
   key from remote state and updates the two Bitwarden secrets).
3. ESO refreshes `immich-backup-s3` and `spliit-backup-s3` within 1h; restart the CNPG
   pods or wait for the next WAL to confirm `ContinuousArchiving=True`.

## Cost

Standard `fr-par` is billed per GB-month with a free tier; the CNPG prefixes are a few GB.
The Immich library offsite will be the first bucket where cost matters (30 to 100 GB).
