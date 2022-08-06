# brassberry-gitops: The state of my kubernetes cluster

## GitOps with ArgoCD

This is the current state of my home kubernetes cluster, running on Raspberry Pis. It uses ArgoCD, Renovate and ArgoCD Image Updater for a simple and automatic update process!

## Bootstrap

### OS dependencies

Make sure to run the initial ansible playbook for the [`ubuntu-image-raspberry` repository.](https://github.com/dixneuf19/ubuntu-image-raspberry)

```bash
make all
```

Install Kubernetes with `k0sctl`, in the same repository.

```bash
k0sctl apply --config k0sctl.yaml
# Make sure you have a special kubeconfig for your project
# Otherwise you overwrite your other configs
k0sctl kubeconfig > $KUBECONFIG
```

You should now be able to list your nodes and `kube-system` pods.

```bash
kubectl get nodes
kubectl get -n kube-system pods
```

### CRD and ns

KPS CRD <https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack>

```bash
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.55.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagerconfigs.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.55.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.55.0/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.55.0/example/prometheus-operator-crd/monitoring.coreos.com_probes.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.55.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.55.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.55.0/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.55.0/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml
```

Create namespace monitoring for service monitor

```bash
kubectl create ns monitoring
```

### Create secrets

```bash
kubectl create ns ingress-nginx
kubectl create ns fip
kubectl create ns argocd
```

```bash
cd ~/codes/raspberry/brassberry-gitops/ingress-nginx/ingress-nginx
make secret
cd -
```

- Nginx basic auth
- Secrets applicatifs pour
  - Whats-on-fip
  - spotify-api
  - telegram-bot
  - slack-bot
- Dank face bot
- ArgoCD image updater

```bash
kubectl -n fip create secret generic radio-france-api-token --from-env-file ~/codes/python/whats-on-fip/.secret                                                                               
kubectl -n fip create secret generic spotify-api-access --from-env-file ~/codes/python/spotify-api/.secret
kubectl -n fip create secret generic fip-telegram-bot --from-env-file ~/codes/python/fip-telegram-bot/.secret
kubectl -n fip create secret generic fip-slack-bot --from-env-file ~/codes/python/fip-slack-bot/.secret
kubectl -n dank-face-bot create secret generic telegram-token --from-env-file ~/codes/python/dank-face-bot/.secret
```

### Deploy Argocd

```bash
cd /home/baloo/codes/raspberry/brassberry-gitops/argocd/argo-cd
helm upgrade --install -n "argocd" --create-namespace "argo-cd" . -f values.yaml
cd -
```

```bash
kubectl apply -f ~/codes/raspberry/argocd/apps/argocd-apps.yaml
```
