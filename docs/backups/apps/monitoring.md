# Monitoring (kube-prometheus-stack)

Namespace `monitoring`, chart `gitops/monitoring/kps`.

| Data | Where | Class | Decision |
|---|---|---|---|
| Grafana SQLite (users, API keys, dashboards made in the UI, annotations) | `kps-grafana`, `nfs-client` 10Gi | B | ⚪ accepted: provisioned dashboards live in git (`homelab-temperatures.json`), admin password in Bitwarden. Anything drawn in the UI is disposable. Revisit if UI dashboards accumulate |
| Prometheus TSDB, 30d | `local-path` on brassberry-27, `/mnt/magadi_3T/local-path-provisioner` (NTFS USB disk) | C | ♻️ metrics history is not worth a backup |
| Loki logs | `local-path` on brassberry-25 (deployed outside GitOps) | C | ♻️ |
| Alertmanager | disabled | | |

Grafana on `nfs-client` is SQLite on NFS. It has not corrupted yet; if it does, the fix
is to drop the PVC and let provisioning recreate everything from git.

Stale item: the `SpliitPostgres` datasource still points at the bitnami service
`spliit-postgresql` and a Secret that no longer exists. Fix or remove it.
