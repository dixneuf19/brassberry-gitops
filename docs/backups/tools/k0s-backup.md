# k0s backup (candidate)

Status: **not deployed**. Single controller `brassberry-24`, etcd 441M, no snapshot.
`.gitignore` contains `**/k0s_backup*`, so it was run by hand at least once.

## What it captures

`k0s backup` produces a tarball with the etcd snapshot, the controller certificates
(`/var/lib/k0s/pki`), the k0s config and the manifests stack. `k0s restore` brings a
fresh controller back with the same cluster identity, so workers rejoin and every
in-cluster generated Secret survives (see technos/kubernetes-state.md for the list).

## Proposed

- On `brassberry-24`, a systemd timer, nightly:
  `k0s backup --save-path /mnt/nas/backups/k0s/` with `/mnt/nas` an NFS mount of
  `192.168.1.30:/tank/data`, keep 7 with `find -mtime +7 -delete`.
- Or from the laptop before every `make k0sctl` / `make upgrade`:
  `k0sctl backup --config cluster/k0sctl.yaml` (writes `k0s_backup_<stamp>.tar.gz` locally,
  already gitignored). Add it as a Makefile prerequisite of `k0sctl` and `upgrade`.
- Once on the NAS, the restic job carries it offsite.

Ansible: `ansible/playbooks/cluster-k0s-backup.yaml`.

## Restore

```bash
k0sctl reset --config cluster/k0sctl.yaml      # only the controller if the workers are fine
k0sctl apply --config cluster/k0sctl.yaml --restore-from k0s_backup_<stamp>.tar.gz
```

Then check `kubectl get nodes`, ArgoCD reconciles the rest. Drill: never run.
