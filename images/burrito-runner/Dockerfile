FROM ghcr.io/padok-team/burrito:v0.15.0@sha256:124e57acd29aefe4d5d727be79cda7bcb5efc70de9702d1c1d7827b64202ceb9

USER root
# Tools for the terraform/cloud local-exec scripts (tailnet-adopt.sh, public-check.sh).
# Keep this tag in sync with the chart version in gitops/burrito-system/burrito/Chart.yaml
# and the runner image tag in gitops/burrito-homelab/burrito-layers/templates/layer-cloud.yaml.
RUN apk add --update --no-cache curl jq netcat-openbsd
USER 65532:65532
