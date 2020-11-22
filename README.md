# fix-ssh-on-pi

## Scripts

### fix-ssh-on-pi (to rename)

Configuration: `fix-ssh-on-pi.ini`

Then run `sudo fix-ssh-on-pi.bash`, it creates an image that you can burn on the SD card (with _balenaEtcher_ for example).

## Playbooks

Configuration: `pie_hosts.yaml`

You can run the playbooks in this order:

- `ping-example-playbook.yaml` to check host connectivity
- `upgrade-playbook.yaml` to update the hosts
- `docker-playbook.yaml` to install docker
- `kubeadm-playbook.yaml` to install kubeadm
- `kubeadm-master-playbook.yaml` for the master of kubernetes
- `kubeadm-workers-playbook.yaml` for the master of kubernetes
- `mounts.yaml` for the disks
- `nfs-server-playbook.yaml` to install nfs
- `jellyfin.yaml`
