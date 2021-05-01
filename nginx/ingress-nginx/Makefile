HELM_RELEASE=ingress-nginx
HELM_REPOSITORY=ingress-nginx
HELM_CHART=ingress-nginx

NAMESPACE=nginx

get-latest-value:
	helm show values "${HELM_REPOSITORY}/${HELM_CHART}" > values.yaml

passwd:
	htpasswd -c basic-auth.htpasswd ${USERNAME}

secret:
	kubectl -n "${NAMESPACE}" create secret generic basic-auth --from-file=auth=basic-auth.htpasswd

dependency:
	helm dependency update

template:
	helm template -n "${NAMESPACE}" "${HELM_RELEASE}" . -f values.yaml > manifests.yaml

deploy:
	kubectl create namespace "${NAMESPACE}" || echo "Namespace ${NAMESPACE} already exists"
	helm upgrade --install -n "${NAMESPACE}" "${HELM_RELEASE}" . -f values.yaml
