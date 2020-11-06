.PHONY: setup deploy delete

setup:
	kubectl create -f manifests/setup

deploy:
	kubectl create -f manifests/

delete:
	kubectl delete --ignore-not-found=true -f manifests/ -f manifests/setup
