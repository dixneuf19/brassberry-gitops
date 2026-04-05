#!/usr/bin/env bash
# Test script for PR 1: Traefik installed alongside ingress-nginx
# Run after ArgoCD has synced the traefik app
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS++)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL++)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; ((WARN++)); }

echo "=== PR 1: Traefik Installation Verification ==="
echo ""

# 1. Traefik pods running
echo "--- Traefik Pods ---"
TRAEFIK_READY=$(kubectl get pods -n traefik -l app.kubernetes.io/name=traefik --no-headers 2>/dev/null | grep -c "Running" || true)
if [ "$TRAEFIK_READY" -ge 2 ]; then
  pass "Traefik has $TRAEFIK_READY running pods (expected >= 2)"
else
  fail "Traefik has $TRAEFIK_READY running pods (expected >= 2)"
fi

# 2. Traefik service with correct NodePorts
echo ""
echo "--- Traefik Service ---"
TRAEFIK_SVC=$(kubectl get svc -n traefik traefik -o jsonpath='{.spec.ports[*].nodePort}' 2>/dev/null || echo "")
if echo "$TRAEFIK_SVC" | grep -q "32081"; then
  pass "Traefik web NodePort is 32081 (temporary)"
else
  fail "Traefik web NodePort not found on 32081. Got: $TRAEFIK_SVC"
fi
if echo "$TRAEFIK_SVC" | grep -q "32444"; then
  pass "Traefik websecure NodePort is 32444 (temporary)"
else
  fail "Traefik websecure NodePort not found on 32444. Got: $TRAEFIK_SVC"
fi

# 3. ingress-nginx still running
echo ""
echo "--- ingress-nginx Still Running ---"
NGINX_READY=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --no-headers 2>/dev/null | grep -c "Running" || true)
if [ "$NGINX_READY" -ge 1 ]; then
  pass "ingress-nginx still has $NGINX_READY running pods (expected: still alive)"
else
  fail "ingress-nginx pods not found (should still be running)"
fi

NGINX_PORTS=$(kubectl get svc -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].spec.ports[*].nodePort}' 2>/dev/null || echo "")
if echo "$NGINX_PORTS" | grep -q "32080"; then
  pass "ingress-nginx still on NodePort 32080"
else
  warn "ingress-nginx NodePort 32080 not found. Got: $NGINX_PORTS"
fi

# 4. Middleware CRDs created
echo ""
echo "--- Traefik Middlewares ---"
for MW in basic-auth body-size-50m; do
  if kubectl get middleware -n traefik "$MW" &>/dev/null; then
    pass "Middleware '$MW' exists in traefik namespace"
  else
    fail "Middleware '$MW' NOT found in traefik namespace"
  fi
done

# 5. Basic-auth secret in traefik namespace
echo ""
echo "--- Basic Auth Secret ---"
if kubectl get secret -n traefik basic-auth &>/dev/null; then
  # Check it has the 'users' key (Traefik format)
  KEYS=$(kubectl get secret -n traefik basic-auth -o jsonpath='{.data}' | grep -o '"[^"]*":' | tr -d '":')
  if echo "$KEYS" | grep -q "users"; then
    pass "Secret 'basic-auth' in traefik namespace has 'users' key"
  else
    fail "Secret 'basic-auth' exists but missing 'users' key. Keys: $KEYS"
  fi
else
  fail "Secret 'basic-auth' NOT found in traefik namespace"
fi

# 6. Traefik responds on temp ports
echo ""
echo "--- Traefik Connectivity ---"
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null | awk '{print $1}')
if [ -z "$NODE_IP" ]; then
  warn "Could not determine node IP. Skipping connectivity tests."
else
  # HTTP
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://${NODE_IP}:32081" 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" != "000" ]; then
    pass "Traefik responds on HTTP :32081 (status: $HTTP_CODE)"
  else
    fail "Traefik not reachable on HTTP :32081"
  fi

  # HTTPS
  HTTPS_CODE=$(curl -sk -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://${NODE_IP}:32444" 2>/dev/null || echo "000")
  if [ "$HTTPS_CODE" != "000" ]; then
    pass "Traefik responds on HTTPS :32444 (status: $HTTPS_CODE)"
  else
    fail "Traefik not reachable on HTTPS :32444"
  fi
fi

# 7. Existing apps still work through ingress-nginx
echo ""
echo "--- Existing Apps via ingress-nginx (smoke test) ---"
SMOKE_HOSTS=("echo.dixneuf19.fr" "whoami.dixneuf19.fr")
for HOST in "${SMOKE_HOSTS[@]}"; do
  if [ -n "$NODE_IP" ]; then
    CODE=$(curl -sk -o /dev/null -w "%{http_code}" --connect-timeout 5 -H "Host: ${HOST}" "https://${NODE_IP}:32443" 2>/dev/null || echo "000")
    if [ "$CODE" = "200" ] || [ "$CODE" = "401" ] || [ "$CODE" = "308" ]; then
      pass "$HOST still works via ingress-nginx :32443 (status: $CODE)"
    else
      warn "$HOST via ingress-nginx :32443 returned $CODE"
    fi
  fi
done

# Summary
echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS: $PASS${NC} | ${RED}FAIL: $FAIL${NC} | ${YELLOW}WARN: $WARN${NC}"
if [ "$FAIL" -gt 0 ]; then
  echo -e "${RED}Some checks failed. Review before proceeding to PR 2.${NC}"
  exit 1
else
  echo -e "${GREEN}All critical checks passed. Safe to proceed to PR 2.${NC}"
fi
