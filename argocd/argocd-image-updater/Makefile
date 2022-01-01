HELM_RELEASE=argocd-image-updater
HELM_REPOSITORY=argo
HELM_CHART=argocd-image-updater

NAMESPACE=argocd

get-latest-value:
	helm show values "${HELM_REPOSITORY}/${HELM_CHART}" > values.yaml

template:
	helm template -n "${NAMESPACE}" "${HELM_RELEASE}" . -f values.yaml

deploy:
	kubectl create namespace "${NAMESPACE}" || echo "Namespace ${NAMESPACE} already exists"
	helm upgrade --install -n "${NAMESPACE}" "${HELM_RELEASE}" . -f values.yaml
