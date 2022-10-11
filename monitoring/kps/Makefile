HELM_RELEASE=kps
NAMESPACE=monitoring


secret:
	kubectl -n "${NAMESPACE}" create secret generic grafana-admin --from-env-file=grafana-admin.secret

template:
	helm template -n "${NAMESPACE}" "${HELM_RELEASE}" . -f values.yaml > manifests.yaml

dependency:
	helm dependency update

deploy:
	helm upgrade --install -n "${NAMESPACE}" --create-namespace "${HELM_RELEASE}" . -f values.yaml
