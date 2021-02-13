NAMESPACE=argocd

.PHONY: get-stable-source
get-stable-source:
	wget -O source/install.yaml https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

.PHONY: kustomize
kustomize:
	kubectl kustomize source/ > ./manifests/install-patched.yaml
	# You can also remove the "argocd-dex-server" deployment if you don't use auth
	# You'll need to do so manually since kustomize doesn't support removal
	# https://kubectl.docs.kubernetes.io/faq/kustomize/eschewedfeatures/#removal-directives

.PHONY: deploy
deploy:
	kubectl create namespace "${NAMESPACE}" || echo "Namespace ${NAMESPACE} already exists"
	kubectl -n "${NAMESPACE}" apply -f ./manifests/


