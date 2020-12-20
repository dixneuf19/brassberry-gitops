NAMESPACE?=kube-system

.PHONY: get-latest-source
get-latest-source:
	wget https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml -O components.yaml

.PHONY: kustomize
kustomize:
	kubectl kustomize . > components-patched.yaml

.PHONY: deploy
deploy:
	kubectl -n "${NAMESPACE}" apply -f components-patched.yaml


