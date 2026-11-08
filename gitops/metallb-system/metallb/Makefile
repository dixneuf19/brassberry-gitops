NAMESPACE?=metallb-system
VERSION=v0.14.8


.PHONY: get-latest-source
get-latest-source:
	wget https://raw.githubusercontent.com/metallb/metallb/${VERSION}/config/manifests/metallb-native.yaml -O manifests/metallb.yaml
	# Upstream probes /metrics with a 1s timeout, which a loaded Pi misses and then restart-loops
	sed -i.bak 's/^          timeoutSeconds: 1$$/          timeoutSeconds: 5/' manifests/metallb.yaml && rm manifests/metallb.yaml.bak

.PHONY: deploy
deploy:
	kubectl -n "${NAMESPACE}" apply -f manifests/


