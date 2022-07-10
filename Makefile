all: ping kernel-modules mounts nfs-server

.DEFAULT:
	ansible-playbook -i hosts.yaml playbooks/$@.yaml
