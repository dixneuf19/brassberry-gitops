NAMESPACE?=metallb-system


.PHONY: get-latest-source
get-latest-source:
	wget https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/namespace.yaml -O manifests/namespace.yaml
	wget https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/metallb.yaml -O manifests/metallb.yaml

.PHONY: deploy
deploy:
	kubectl -n "${NAMESPACE}" apply -f manifests/


