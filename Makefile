all: ping kernel-modules mounts nfs-server

# Tailscale binary from PATH (works on macOS Homebrew, Linux, etc.)
TS_BINARY := $(shell which tailscale)

# tailscale-hostmap: source is upstream main; pull to update, review in git, then run locally
# Source: https://github.com/mxbi/tailscale-hostmap (branch: main)
TS_HOSTMAP_SOURCE := https://raw.githubusercontent.com/mxbi/tailscale-hostmap/refs/heads/main/tailscale-hostmap.py

TS_HOSTMAP_SCRIPT := scripts/tailscale-hostmap.py

tailscale-hostmap-pull:
	curl -sSL $(TS_HOSTMAP_SOURCE) | awk 'NR==1{print; print "# Source: https://github.com/mxbi/tailscale-hostmap (main)"; next} {print}' > $(TS_HOSTMAP_SCRIPT)

tailscale-hosts:
	@sudo uv run $(TS_HOSTMAP_SCRIPT) --ts-binary $(TS_BINARY) --include-shared

.DEFAULT:
	ansible-playbook -i hosts.yaml playbooks/$@.yaml

kubeconfig:
	k0sctl kubeconfig >> ${KUBECONFIG}

k0sctl:
	k0sctl apply --config k0sctl.yaml

# Proxmox targets
# Step 1: Run community post-install script (interactive, via SSH)
# Handles: repos, subscription nag, HA disable, update
# Source: https://community-scripts.github.io/ProxmoxVE/
proxmox-post-install:
	TERM=xterm-256color ssh -t root@192.168.1.30 "bash -c \"\$$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pve-install.sh)\""

# Step 2: Ansible bootstrap (uses local IP, Tailscale not yet set up)
# Handles: ZFS rpool tuning, packages, Tailscale, Terraform API token
# After this: run 'ssh root@192.168.1.30 tailscale up' then 'make tailscale-hosts'
proxmox-bootstrap:
	ansible-playbook -i hosts.yaml playbooks/proxmox-bootstrap.yaml -e "ansible_host=192.168.1.30"

# Step 3+: Use Tailscale address (run 'make tailscale-hosts' first after joining tailnet)
proxmox-zfs:
	ansible-playbook -i hosts.yaml playbooks/proxmox-zfs.yaml
