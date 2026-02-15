all: ping kernel-modules mounts nfs-server

# Tailscale binary from PATH (works on macOS Homebrew, Linux, etc.)
TS_BINARY := $(shell which tailscale)

# tailscale-hostmap: source is upstream main; pull to update, review in git, then run locally
# Source: https://github.com/mxbi/tailscale-hostmap (branch: main)
TS_HOSTMAP_SOURCE := https://raw.githubusercontent.com/mxbi/tailscale-hostmap/refs/heads/main/tailscale-hostmap.py

TS_HOSTMAP_SCRIPT := scripts/tailscale-hostmap.py

tailscale-hostmap-pull:
	curl -sSL $(TS_HOSTMAP_SOURCE) | (head -1; echo '# Source: https://github.com/mxbi/tailscale-hostmap (main)'; tail -n +2) > $(TS_HOSTMAP_SCRIPT)

tailscale-hosts:
	sudo uv run $(TS_HOSTMAP_SCRIPT) --ts-binary $(TS_BINARY) --include-shared

.DEFAULT:
	ansible-playbook -i hosts.yaml playbooks/$@.yaml

kubeconfig:
	k0sctl kubeconfig >> ${KUBECONFIG}

k0sctl:
	k0sctl apply --config k0sctl.yaml
