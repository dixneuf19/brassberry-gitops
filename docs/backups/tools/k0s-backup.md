# k0s backup (reference only)

Status: **not planned**. Decision 2026-09-12: the cluster is rebuilt from git and PV data
outlives it, so etcd is not backed up ([../technos/kubernetes-state.md](../technos/kubernetes-state.md)).
This page stays as a reference for the one case where it is cheap and useful: a snapshot
right before a risky `make upgrade` or `make k0sctl`, for a fast rollback.

## What it captures

`k0s backup` produces a tarball with the etcd snapshot, the controller certificates
(`/var/lib/k0s/pki`), the k0s config and the manifests stack. `k0s restore` brings a
fresh controller back with the same cluster identity, so workers rejoin and every
in-cluster generated Secret survives (see technos/kubernetes-state.md for the list).

## If ever wanted

From the laptop before `make k0sctl` / `make upgrade`:
`k0sctl backup --config cluster/k0sctl.yaml` writes `k0s_backup_<stamp>.tar.gz` locally
(already gitignored). It could be a Makefile prerequisite of those two targets. No
scheduled job, no offsite copy.

## Restore

```bash
k0sctl reset --config cluster/k0sctl.yaml      # only the controller if the workers are fine
k0sctl apply --config cluster/k0sctl.yaml --restore-from k0s_backup_<stamp>.tar.gz
```

Then check `kubectl get nodes`, ArgoCD reconciles the rest. Drill: never run.
