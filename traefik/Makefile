USERNAME?="baloo"

.PHONY: passwd secret

passwd:
	htpasswd -c basic-auth.htpasswd ${USERNAME}

secret:
	kubectl -n traefik create secret generic basic-auth --from-file=basic-auth.htpasswd

helm-traefik:
	helm -n traefik upgrade -i traefik traefik/traefik -f values.yaml

dashboard:
	kubectl -n traefik apply -f traefik-dashboard.yaml
