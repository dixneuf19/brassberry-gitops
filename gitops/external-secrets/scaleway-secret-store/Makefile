NAMESPACE=external-secrets

# Bootstrap: create the Scaleway API credentials secret for ESO.
# Requires SCW_ACCESS_KEY and SCW_SECRET_KEY env vars (set by direnv).
# This is a one-time manual step before ArgoCD syncs the ClusterSecretStore.
secret:
	kubectl -n "${NAMESPACE}" create secret generic scaleway-api-credentials \
		--from-literal=access-key=$${SCW_ACCESS_KEY} \
		--from-literal=secret-key=$${SCW_SECRET_KEY} \
		--dry-run=client -o yaml | kubectl apply -f -

.PHONY: secret
