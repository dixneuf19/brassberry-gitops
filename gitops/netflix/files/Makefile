NAMESPACE=netflix

deploy:
	kubectl create namespace "${NAMESPACE}" || echo "Namespace ${NAMESPACE} already exists"
	kubectl apply -n "${NAMESPACE}" -f files.yaml
