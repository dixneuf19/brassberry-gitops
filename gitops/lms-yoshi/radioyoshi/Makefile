HELM_RELEASE=lyrion-music-server

NAMESPACE=lms-yoshi

dependency:
	helm dependency update

template:
	helm template -n "${NAMESPACE}" "${HELM_RELEASE}" . -f values.yaml > manifests.yaml

deploy:
	kubectl create namespace "${NAMESPACE}" || echo "Namespace ${NAMESPACE} already exists"
	helm upgrade --install -n "${NAMESPACE}" "${HELM_RELEASE}" . -f values.yaml

passwd:
	htpasswd -c yoshi-basic-auth.htpasswd clauss

secret:
	kubectl -n "${NAMESPACE}" create secret generic yoshi-basic-auth --from-file=auth=yoshi-basic-auth.htpasswd
