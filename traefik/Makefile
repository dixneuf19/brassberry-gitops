USERNAME?="baloo"

.PHONY: passwd secret

passwd:
	htpasswd -c basic-auth.htpasswd ${USERNAME}

secret:
	kubectl -n traefik create secret generic basic-auth --from-file=basic-auth.htpasswd
