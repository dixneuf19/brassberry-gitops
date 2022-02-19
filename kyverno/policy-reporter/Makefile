HELM_RELEASE=policy-reporter
NAMESPACE=kyverno

dependency:
	helm dependency update

template:
	helm template -n "${NAMESPACE}" "${HELM_RELEASE}" . -f values.yaml

deploy:
	helm upgrade --install --create-namespace -n "${NAMESPACE}" "${HELM_RELEASE}" . -f values.yaml
