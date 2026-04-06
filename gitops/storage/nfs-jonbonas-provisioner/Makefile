HELM_RELEASE=nfs-jonbonas-provisioner
NAMESPACE=storage

template:
	helm -n "${NAMESPACE}" template "${HELM_RELEASE}" . -f values.yaml

deploy:
	helm -n "${NAMESPACE}" upgrade -i "${HELM_RELEASE}" . -f values.yaml
