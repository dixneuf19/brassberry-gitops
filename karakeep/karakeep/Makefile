HELM_RELEASE=karakeep
NAMESPACE=karakeep

namespace:
	kubectl create namespace "${NAMESPACE}" || true

# karakeep.secret must contain: NEXTAUTH_SECRET, OPENAI_API_KEY (optional), MEILI_MASTER_KEY (for research)
# Generate MEILI_MASTER_KEY: openssl rand -base64 36 | tr -dc 'A-Za-z0-9'
secret: namespace
	kubectl -n "${NAMESPACE}" create secret generic karakeep-secrets \
		--from-env-file=karakeep.secret \
		--dry-run=client -o yaml | kubectl apply -f -

# Generate a Meilisearch master key (add MEILI_MASTER_KEY=<output> to karakeep.secret)
generate-meili-master-key:
	@echo "Add the following line to karakeep.secret:"
	@echo "MEILI_MASTER_KEY=$$(openssl rand -base64 36 | tr -dc 'A-Za-z0-9')"

template:
	helm template -n "${NAMESPACE}" "${HELM_RELEASE}" . -f values.yaml > manifests.yaml

deploy: secret
	helm upgrade --install -n "${NAMESPACE}" --create-namespace "${HELM_RELEASE}" . -f values.yaml

status:
	helm status -n "${NAMESPACE}" "${HELM_RELEASE}"

uninstall:
	helm uninstall -n "${NAMESPACE}" "${HELM_RELEASE}"

.PHONY: namespace secret template deploy status uninstall generate-meili-master-key
