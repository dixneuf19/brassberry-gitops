HELM_RELEASE=karakeep
NAMESPACE=karakeep

template:
	helm template -n "${NAMESPACE}" "${HELM_RELEASE}" . -f values.yaml > manifests.yaml

deploy:
	helm upgrade --install -n "${NAMESPACE}" --create-namespace "${HELM_RELEASE}" . -f values.yaml

status:
	helm status -n "${NAMESPACE}" "${HELM_RELEASE}"

uninstall:
	helm uninstall -n "${NAMESPACE}" "${HELM_RELEASE}"

.PHONY: template deploy status uninstall
