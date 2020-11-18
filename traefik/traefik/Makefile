USERNAME?="baloo"

.PHONY: passwd secret

passwd:
	htpasswd -c basic-auth.htpasswd ${USERNAME}

secret:
	kubectl -n traefik create secret generic basic-auth --from-file=basic-auth.htpasswd

helm-update:
	helm dependency update

helm-traefik:
	helm -n traefik upgrade -i traefik . -f values.yaml
