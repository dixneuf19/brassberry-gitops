HELM_RELEASE=karakeep
NAMESPACE=karakeep

namespace:
	kubectl create namespace "${NAMESPACE}" || true

secret: namespace
	kubectl -n "${NAMESPACE}" create secret generic karakeep-secrets \
		--from-env-file=karakeep.secret

template:
	helm template -n "${NAMESPACE}" "${HELM_RELEASE}" . -f values.yaml > manifests.yaml

deploy: secret
	helm upgrade --install -n "${NAMESPACE}" --create-namespace "${HELM_RELEASE}" . -f values.yaml

status:
	helm status -n "${NAMESPACE}" "${HELM_RELEASE}"

uninstall:
	helm uninstall -n "${NAMESPACE}" "${HELM_RELEASE}"

.PHONY: namespace secret template deploy status uninstall
