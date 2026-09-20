FROM ghcr.io/padok-team/burrito:v0.14.0@sha256:d05ed41cbea6cb3b20d36ffb6df743ebe5103802fa7a10f94643d36d738a52e5

USER root
# Tools for the terraform/cloud local-exec scripts (tailnet-adopt.sh, public-check.sh).
# Keep this tag in sync with the chart version in gitops/burrito-system/burrito/Chart.yaml
# and the runner image tag in gitops/burrito-homelab/burrito-layers/templates/layer-cloud.yaml.
RUN apk add --update --no-cache curl jq netcat-openbsd
USER 65532:65532
