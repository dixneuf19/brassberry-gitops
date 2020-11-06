.PHONY: get-stable-source
get-stable-source:
	wget -O source/install.yaml https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

.PHONY: kustomize
kustomize:
	echo "doesn't work"
	# kubectl kustomize . > install-patched.yaml
	# echo "You can also remove the \"argocd-dex-server\" deployment if you don't use auth"

.PHONY: deploy
deploy:
	kubectl apply -f install-patched.yaml --namespace argocd


