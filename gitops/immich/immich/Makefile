HELM_RELEASE=immich
NAMESPACE=immich

template:
	helm -n "${NAMESPACE}" template "${HELM_RELEASE}" . -f values.yaml

deploy:
	helm -n "${NAMESPACE}" upgrade -i --create-namespace "${HELM_RELEASE}" . -f values.yaml

status:
	helm -n "${NAMESPACE}" status "${HELM_RELEASE}"

uninstall:
	helm -n "${NAMESPACE}" uninstall "${HELM_RELEASE}"
