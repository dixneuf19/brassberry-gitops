#!/bin/bash

HELM_REPOSITORY_CONFIG_PATH="hacks/repositories.yaml"

set -o errexit    # Used to exit upon error, avoiding cascading errors
set -o nounset    # Exposes unset variables

echo "⚙ List all Chart.lock files modified from $GITHUB_BASE_REF to $GITHUB_HEAD_REF"

CHART_PATHS=$(git diff origin/$GITHUB_BASE_REF...origin/$GITHUB_HEAD_REF --name-only -- '**/Chart.lock' | xargs -I {} dirname {})

echo "✅ Found $(echo $CHART_PATHS | wc -w) charts modified"

for CHART_PATH in $CHART_PATHS; do
    CHART_NAME=$(basename "$CHART_PATH")
    echo "⚙ Build helm dependencies for $CHART_NAME"
    helm dependency build "$CHART_PATH" --repository-config "$HELM_REPOSITORY_CONFIG_PATH"
    echo "✅ Successfully updated $CHART_NAME"
done

echo "✅ Done"
