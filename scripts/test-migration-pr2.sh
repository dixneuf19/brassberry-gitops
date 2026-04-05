#!/usr/bin/env bash
# Test script for PR 2: All apps switched from nginx to traefik ingressClass
# Run after ArgoCD has synced all apps
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

NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null | awk '{print $1}')
TRAEFIK_PORT=32444  # Temporary HTTPS port

echo "=== PR 2: App Migration Verification ==="
echo "Using node IP: ${NODE_IP:-unknown}"
echo "Using Traefik HTTPS port: $TRAEFIK_PORT"
echo ""

# -------------------------------------------------------
# 1. Check all Ingress resources now use traefik class
# -------------------------------------------------------
echo "--- Ingress Class Check ---"
NGINX_INGRESSES=$(kubectl get ingress -A -o jsonpath='{range .items[?(@.spec.ingressClassName=="nginx")]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
if [ -z "$NGINX_INGRESSES" ]; then
  pass "No Ingress resources with ingressClassName=nginx remain"
else
  fail "Ingress resources still using nginx class:"
  echo "$NGINX_INGRESSES" | while read -r ing; do
    echo "  - $ing"
  done
fi

TRAEFIK_INGRESSES=$(kubectl get ingress -A -o jsonpath='{range .items[?(@.spec.ingressClassName=="traefik")]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
TRAEFIK_COUNT=$(echo "$TRAEFIK_INGRESSES" | grep -c . || true)
if [ "$TRAEFIK_COUNT" -ge 10 ]; then
  pass "$TRAEFIK_COUNT Ingress resources using traefik class"
else
  warn "Only $TRAEFIK_COUNT Ingress resources with traefik class (expected >= 10)"
fi

# -------------------------------------------------------
# 2. cert-manager ClusterIssuer updated
# -------------------------------------------------------
echo ""
echo "--- cert-manager ClusterIssuer ---"
ISSUER_CLASS=$(kubectl get clusterissuer letsencrypt -o jsonpath='{.spec.acme.solvers[0].http01.ingress.class}' 2>/dev/null || echo "unknown")
if [ "$ISSUER_CLASS" = "traefik" ]; then
  pass "ClusterIssuer 'letsencrypt' uses class: traefik"
else
  fail "ClusterIssuer 'letsencrypt' uses class: $ISSUER_CLASS (expected: traefik)"
fi

# -------------------------------------------------------
# 3. Test each app through Traefik (temp port)
# -------------------------------------------------------
echo ""
echo "--- App Reachability via Traefik :$TRAEFIK_PORT ---"

# Apps without auth (expect 200)
declare -A NO_AUTH_APPS=(
  ["echo.dixneuf19.fr"]="200"
  ["navidrome.dixneuf19.fr"]="200,302"
  ["fip-slack-bot.dixneuf19.fr"]="200,404,405"
  ["fip-telegram-bot.dixneuf19.fr"]="200,404,405"
  ["dank-face-slack-bot.dixneuf19.fr"]="200,404,405"
  ["spliit.dixneuf19.fr"]="200,302"
  ["tricount.dixneuf19.fr"]="200,302"
  ["baloocount.dixneuf19.fr"]="200,302"
  ["readeck.dixneuf19.fr"]="200,302"
  ["karakeep.dixneuf19.fr"]="200,302"
  ["speedtest.dixneuf19.fr"]="200,302"
)

for HOST in "${!NO_AUTH_APPS[@]}"; do
  EXPECTED="${NO_AUTH_APPS[$HOST]}"
  if [ -n "$NODE_IP" ]; then
    CODE=$(curl -sk -o /dev/null -w "%{http_code}" --connect-timeout 5 -H "Host: ${HOST}" "https://${NODE_IP}:${TRAEFIK_PORT}" 2>/dev/null || echo "000")
    if echo ",$EXPECTED," | grep -q ",$CODE,"; then
      pass "$HOST -> $CODE"
    elif [ "$CODE" = "000" ]; then
      fail "$HOST -> unreachable"
    else
      warn "$HOST -> $CODE (expected one of: $EXPECTED)"
    fi
  fi
done

# Apps with basic auth (expect 401 without credentials)
echo ""
echo "--- Apps with Basic Auth (expect 401 without credentials) ---"
AUTH_APPS=(
  "whoami.dixneuf19.fr"
  "karma.dixneuf19.fr"
  "cd-lna.dixneuf19.fr"
  "lms.dixneuf19.fr"
  "radioyoshi.dixneuf19.fr"
  "argocd.dixneuf19.fr"
  "grafana.dixneuf19.fr"
  "prometheus.dixneuf19.fr"
)

for HOST in "${AUTH_APPS[@]}"; do
  if [ -n "$NODE_IP" ]; then
    CODE=$(curl -sk -o /dev/null -w "%{http_code}" --connect-timeout 5 -H "Host: ${HOST}" "https://${NODE_IP}:${TRAEFIK_PORT}" 2>/dev/null || echo "000")
    if [ "$CODE" = "401" ]; then
      pass "$HOST -> 401 (auth required, as expected)"
    elif [ "$CODE" = "000" ]; then
      fail "$HOST -> unreachable"
    else
      warn "$HOST -> $CODE (expected 401 for unauthenticated request)"
    fi
  fi
done

# -------------------------------------------------------
# 4. Test basic auth actually works with credentials
# -------------------------------------------------------
echo ""
echo "--- Basic Auth with Credentials (smoke test) ---"
echo "Enter basic auth credentials to test (or press Enter to skip):"
read -rp "Username: " BA_USER
if [ -n "$BA_USER" ]; then
  read -rsp "Password: " BA_PASS
  echo ""
  for HOST in "whoami.dixneuf19.fr" "karma.dixneuf19.fr"; do
    CODE=$(curl -sk -o /dev/null -w "%{http_code}" --connect-timeout 5 -u "${BA_USER}:${BA_PASS}" -H "Host: ${HOST}" "https://${NODE_IP}:${TRAEFIK_PORT}" 2>/dev/null || echo "000")
    if [ "$CODE" = "200" ]; then
      pass "$HOST -> 200 with auth"
    else
      fail "$HOST -> $CODE with auth (expected 200)"
    fi
  done
else
  warn "Skipping authenticated tests"
fi

# -------------------------------------------------------
# 5. ArgoCD backend HTTPS
# -------------------------------------------------------
echo ""
echo "--- ArgoCD Backend HTTPS ---"
if [ -n "$NODE_IP" ]; then
  CODE=$(curl -sk -o /dev/null -w "%{http_code}" --connect-timeout 5 -H "Host: argocd.dixneuf19.fr" "https://${NODE_IP}:${TRAEFIK_PORT}/api/webhook" 2>/dev/null || echo "000")
  if [ "$CODE" != "000" ]; then
    pass "ArgoCD webhook endpoint reachable (status: $CODE)"
  else
    fail "ArgoCD webhook endpoint unreachable"
  fi
fi

# -------------------------------------------------------
# 6. Check no nginx annotations remain on traefik ingresses
# -------------------------------------------------------
echo ""
echo "--- Annotation Cleanup Check ---"
NGINX_ANNOT=$(kubectl get ingress -A -o json 2>/dev/null | grep -c "nginx.ingress.kubernetes.io" || true)
if [ "$NGINX_ANNOT" -eq 0 ]; then
  pass "No nginx.ingress.kubernetes.io annotations found on any Ingress"
else
  fail "$NGINX_ANNOT nginx annotation references still present:"
  kubectl get ingress -A -o json | grep -B5 "nginx.ingress.kubernetes.io" | grep -E "(namespace|name|nginx)" || true
fi

# -------------------------------------------------------
# 7. Check Traefik logs for errors
# -------------------------------------------------------
echo ""
echo "--- Traefik Logs (last 50 lines, errors only) ---"
ERRORS=$(kubectl logs -n traefik -l app.kubernetes.io/name=traefik --tail=50 2>/dev/null | grep -ci "error" || true)
if [ "$ERRORS" -eq 0 ]; then
  pass "No errors in recent Traefik logs"
else
  warn "$ERRORS error lines in recent Traefik logs"
  kubectl logs -n traefik -l app.kubernetes.io/name=traefik --tail=50 2>/dev/null | grep -i "error" | tail -5
fi

# -------------------------------------------------------
# 8. cert-manager can issue via traefik
# -------------------------------------------------------
echo ""
echo "--- cert-manager Certificate Status ---"
CERTS_NOT_READY=$(kubectl get certificates -A -o jsonpath='{range .items[?(@.status.conditions[0].status!="True")]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
if [ -z "$CERTS_NOT_READY" ]; then
  pass "All certificates are Ready"
else
  warn "Some certificates not ready:"
  echo "$CERTS_NOT_READY" | while read -r cert; do
    echo "  - $cert"
  done
fi

# Summary
echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS: $PASS${NC} | ${RED}FAIL: $FAIL${NC} | ${YELLOW}WARN: $WARN${NC}"
if [ "$FAIL" -gt 0 ]; then
  echo -e "${RED}Some checks failed. Fix before proceeding to PR 3.${NC}"
  exit 1
else
  echo -e "${GREEN}All critical checks passed. Safe to proceed to PR 3 (port switch + nginx removal).${NC}"
fi
