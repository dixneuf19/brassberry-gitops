NAMESPACE=grist

namespace:
	kubectl create namespace "${NAMESPACE}" || echo "Namespace ${NAMESPACE} already exists"

deploy: namespace
	kubectl apply -n "${NAMESPACE}" -f .
