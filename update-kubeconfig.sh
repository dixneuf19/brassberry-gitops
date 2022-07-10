#!/bin/bash
set -euo pipefail

k0sctl kubeconfig | sed 's/my-k0s-cluster/brassberry/g' >> $KUBECONFIG
