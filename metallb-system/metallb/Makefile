NAMESPACE?=metallb-system
VERSION=v0.14.8


.PHONY: get-latest-source
get-latest-source:
	wget https://raw.githubusercontent.com/metallb/metallb/${VERSION}/config/manifests/metallb-native.yaml -O manifests/metallb.yaml

.PHONY: deploy
deploy:
	kubectl -n "${NAMESPACE}" apply -f manifests/


