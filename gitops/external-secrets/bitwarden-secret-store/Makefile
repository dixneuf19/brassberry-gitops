NAMESPACE=external-secrets

# Bootstrap: create the BWS machine account token secret for ESO.
# Requires BWS_ACCESS_TOKEN env var (from your password manager).
# This is a one-time manual step before ArgoCD syncs the ClusterSecretStore.
secret:
	kubectl -n "${NAMESPACE}" create secret generic bws-machine-account-token \
		--from-literal=token=$${BWS_ACCESS_TOKEN} \
		--dry-run=client -o yaml | kubectl apply -f -

.PHONY: secret
