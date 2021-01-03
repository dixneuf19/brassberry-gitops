NAMESPACE=netflix


passwd:
	htpasswd -c files-auth.htpasswd netflix

secret:
	kubectl -n "${NAMESPACE}" create secret generic files-auth --from-file=auth=files-auth.htpasswd

deploy:
	kubectl create namespace "${NAMESPACE}" || echo "Namespace ${NAMESPACE} already exists"
	kubectl apply -n "${NAMESPACE}" -f files.yaml
