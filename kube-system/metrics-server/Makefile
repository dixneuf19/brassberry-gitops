.PHONY: get-stable-source
get-stable-source:
	wget https://github.com/kubernetes-sigs/metrics-server/releases/stable/download/components.yaml

.PHONY: kustomize
kustomize:
	kubectl kustomize . > components-patched.yaml

.PHONY: deploy
deploy:
	kubectl apply -f components-patched.yaml


