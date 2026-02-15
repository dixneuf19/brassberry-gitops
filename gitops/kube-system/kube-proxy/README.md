# Kube-Proxy Prometheus hack

To be correctly scrapped by Prometheus, the metrics endpoint
of the kube-proxy component needs to respond to Prometheus requests.
However, as explained in [this issue](https://github.com/prometheus-community/helm-charts/issues/977), the default configuration of kube-proxy bind only on localhost.
Therefore, you need to modify the `kube-proxy` configmap to configure
`metricsBindAddress` to `0.0.0.0:10249` and restart the `kube-proxy` pods.

```bash
kubectl edit cm kube-proxy
kubeclt rollout restart daemonset kube-proxy
```

Note that you expose yourself to a security risk by doing this,
since you are exposing an HTTP only metrics endpoint to the whole network.
That's why [PR to fix this issue](https://github.com/kubernetes/kubernetes/pull/74300) have been rejected.
