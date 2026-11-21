# Monitoring (kube-prometheus-stack)

Namespace `monitoring`, chart `gitops/monitoring/kps`.

| Data | Where | Class | Decision |
|---|---|---|---|
| Grafana SQLite | `kps-grafana`, `nfs-client` 10Gi | C | ♻️ everything is GitOps: dashboards (`homelab-temperatures.json` and the chart defaults), datasources and the admin password (ESO) come from the repo. Anything created in the UI is out of policy and may be lost |
| Prometheus TSDB, 30d | `local-path` on brassberry-27, `/mnt/magadi_3T/local-path-provisioner` (NTFS USB disk) | C | ⚪ accepted: history cannot be rebuilt, but retention deletes it after 30 days anyway, so a backup would outlive the data it protects |
| Loki logs | `local-path` on brassberry-25 (deployed outside GitOps) | C | ⚪ same reasoning |
| Alertmanager | disabled | | |

## Enforce it: run Grafana stateless

Decision (2026-09-12): Grafana should not have a persistent disk at all. With
`grafana.persistence.enabled: false` in `gitops/monitoring/kps/values.yaml` the pod uses an
emptyDir, every restart proves the git provisioning is complete, and SQLite-on-NFS stops
being a concern. Steps:

1. Check the live DB for anything not in git: dashboards not tagged as provisioned,
   extra users, API keys / service accounts, alert rules. Export what matters into the
   chart's `dashboards:` or `additionalDataSources:`.
2. Set `persistence.enabled: false`, merge, let ArgoCD roll the pod.
3. Delete the `kps-grafana` PVC (and the older `kube-prometheus-stack-grafana` and
   duplicate `kps-grafana` `Retain` PVs on brassberry-25).

Stale item: the `SpliitPostgres` datasource still points at the bitnami service
`spliit-postgresql` and a Secret that no longer exists. Fix or remove it in the same PR.
