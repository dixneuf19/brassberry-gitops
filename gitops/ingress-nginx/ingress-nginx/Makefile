HELM_RELEASE=ingress-nginx
HELM_REPOSITORY=ingress-nginx
HELM_CHART=ingress-nginx

NAMESPACE=ingress-nginx

get-latest-value:
	helm show values "${HELM_REPOSITORY}/${HELM_CHART}" > values.yaml

dependency:
	helm dependency update

template:
	helm template -n "${NAMESPACE}" "${HELM_RELEASE}" . -f values.yaml > manifests.yaml

deploy:
	kubectl create namespace "${NAMESPACE}" || echo "Namespace ${NAMESPACE} already exists"
	helm upgrade --install -n "${NAMESPACE}" "${HELM_RELEASE}" . -f values.yaml
