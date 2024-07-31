HELM_RELEASE=kubechecks
NAMESPACE=kubechecks


secret:
	kubectl -n "${NAMESPACE}" create secret generic kubechecks --from-env-file=kubechecks.secret

template:
	helm template -n "${NAMESPACE}" "${HELM_RELEASE}" . -f values.yaml > manifests.yaml

dependency:
	helm dependency update

deploy:
	helm upgrade --install -n "${NAMESPACE}" --create-namespace "${HELM_RELEASE}" . -f values.yaml
