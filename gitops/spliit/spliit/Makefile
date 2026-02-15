HELM_RELEASE=spliit
NAMESPACE=spliit

namespace:
	kubectl create namespace "${NAMESPACE}" || true 

secret: namespace
	kubectl -n "${NAMESPACE}" create secret generic postgresql-passwords \
		--from-literal=postgres-password=$$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32) \
		--from-literal=password=$$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32) \
		--from-literal=replication-password=$$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)

template:
	helm template -n "${NAMESPACE}" "${HELM_RELEASE}" . -f values.yaml > manifests.yaml

dependency:
	helm dependency update

deploy:
	helm upgrade --install -n "${NAMESPACE}" --create-namespace "${HELM_RELEASE}" . -f values.yaml
