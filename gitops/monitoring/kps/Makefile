HELM_RELEASE=kps
NAMESPACE=monitoring

template:
	helm template -n "${NAMESPACE}" "${HELM_RELEASE}" . -f values.yaml > manifests.yaml

dependency:
	helm dependency update

deploy:
	helm upgrade --install -n "${NAMESPACE}" --create-namespace "${HELM_RELEASE}" . -f values.yaml
