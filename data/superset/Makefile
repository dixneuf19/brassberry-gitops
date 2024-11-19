HELM_RELEASE=superset

NAMESPACE=data

dependency:
	helm dependency update

template:
	helm template -n "${NAMESPACE}" "${HELM_RELEASE}" . -f values.yaml > manifests.yaml

deploy:
	kubectl create namespace "${NAMESPACE}" || echo "Namespace ${NAMESPACE} already exists"
	helm upgrade --install -n "${NAMESPACE}" "${HELM_RELEASE}" . -f values.yaml

secret:
	kubectl -n "${NAMESPACE}" create secret generic superset-secret-key --from-literal=SUPERSET_SECRET_KEY=`openssl rand -base64 42`
