all: ping kernel-modules mounts nfs-server

.DEFAULT:
	ansible-playbook -i hosts.yaml playbooks/$@.yaml

kubeconfig:
	k0sctl kubeconfig >> $KUBECONFIG
