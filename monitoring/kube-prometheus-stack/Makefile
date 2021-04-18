HELM_RELEASE=kube-prometheus-stack
HELM_REPOSITORY=prometheus-community
HELM_CHART=kube-prometheus-stack
CHART_VERSION=13.13.1

NAMESPACE=monitoring

get-latest-value:
	helm show values "${HELM_REPOSITORY}/${HELM_CHART}" > values.yaml

secret:
	kubectl -n "${NAMESPACE}" create secret generic grafana-admin --from-env-file=grafana-admin.secret

template:
	helm template -n "${NAMESPACE}" "${HELM_RELEASE}" "${HELM_REPOSITORY}/${HELM_CHART}" -f values.yaml > manifests.yaml

deploy:
	kubectl create namespace "${NAMESPACE}" || echo "Namespace ${NAMESPACE} already exists"
	helm upgrade --install --version "${CHART_VERSION}" -n "${NAMESPACE}" "${HELM_RELEASE}" "${HELM_REPOSITORY}/${HELM_CHART}" -f values.yaml
