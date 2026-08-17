FROM ghcr.io/padok-team/burrito:v0.13.0

USER root
# Tools for the terraform/cloud local-exec scripts (tailnet-adopt.sh, public-check.sh).
# Keep this tag in sync with the chart version in gitops/burrito-system/burrito/Chart.yaml
# and the runner image tag in gitops/burrito-homelab/burrito-layers/templates/layer-cloud.yaml.
RUN apk add --update --no-cache curl jq netcat-openbsd
USER 65532:65532
