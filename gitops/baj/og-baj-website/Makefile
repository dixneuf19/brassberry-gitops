HELM_RELEASE=og-baj-website

NAMESPACE=baj

dependency:
	helm dependency update

template:
	helm template -n "${NAMESPACE}" "${HELM_RELEASE}" . -f values.yaml > manifests.yaml

deploy:
	kubectl create namespace "${NAMESPACE}" || echo "Namespace ${NAMESPACE} already exists"
	helm upgrade --install -n "${NAMESPACE}" "${HELM_RELEASE}" . -f values.yaml

connect-db:
	@# Extract the MySQL password from the Kubernetes secret
	$(eval DB_PASSWORD=$(shell kubectl -n "${NAMESPACE}" get secret mysql-passwords -o jsonpath='{.data.mysql-password}' | base64 --decode))
	@# Execute MySQL connection with the extracted password
	@kubectl -n "${NAMESPACE}" exec -it og-baj-website-mysql-0 -- mysql -u joe -p${DB_PASSWORD} bandajoe
