NAMESPACE=default


passwd:
	htpasswd -c cd-lna-auth.htpasswd LNA

secret:
	kubectl -n "${NAMESPACE}" create secret generic cd-lna-auth --from-file=auth=cd-lna-auth.htpasswd

deploy:
	kubectl create namespace "${NAMESPACE}" || echo "Namespace ${NAMESPACE} already exists"
	kubectl apply -n "${NAMESPACE}" -f ./manifests/
