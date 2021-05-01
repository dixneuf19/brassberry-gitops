HELM_RELEASE=nfs-client-provisioner
HELM_REPOSITORY_URL=https://charts.helm.sh/stable
HELM_REPOSITORY_NAME=stable
HELM_CHART=nfs-client-provisioner
NAMESPACE=default

dependency:
	helm repo add "${HELM_REPOSITORY_NAME}" "${HELM_REPOSITORY_URL}"

template:
	helm -n "${NAMESPACE}"  template "${HELM_RELEASE}" "${HELM_REPOSITORY_NAME}/${HELM_CHART}" -f values.yaml

deploy:
	helm -n "${NAMESPACE}" upgrade -i "${HELM_RELEASE}" "${HELM_REPOSITORY_NAME}/${HELM_CHART}" -f values.yaml
