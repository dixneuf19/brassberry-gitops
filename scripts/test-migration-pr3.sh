#!/usr/bin/env bash
# Test script for PR 3: Traefik on final ports + ingress-nginx removed
# Run after ArgoCD has synced
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
HTTPS_PORT=32443  # Final port

echo "=== PR 3: Final Migration Verification ==="
echo "Using node IP: ${NODE_IP:-unknown}"
echo "Using HTTPS port: $HTTPS_PORT (final)"
echo ""

# -------------------------------------------------------
# 1. ingress-nginx is gone
# -------------------------------------------------------
echo "--- ingress-nginx Removal ---"
if kubectl get namespace ingress-nginx &>/dev/null; then
  PHASE=$(kubectl get namespace ingress-nginx -o jsonpath='{.status.phase}' 2>/dev/null || echo "unknown")
  if [ "$PHASE" = "Terminating" ]; then
    warn "ingress-nginx namespace still terminating"
  else
    fail "ingress-nginx namespace still exists (phase: $PHASE)"
  fi
else
  pass "ingress-nginx namespace removed"
fi

NGINX_PODS=$(kubectl get pods -n ingress-nginx --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$NGINX_PODS" -eq 0 ]; then
  pass "No ingress-nginx pods running"
else
  fail "$NGINX_PODS ingress-nginx pods still running"
fi

# -------------------------------------------------------
# 2. Traefik on final ports
# -------------------------------------------------------
echo ""
echo "--- Traefik Service Ports ---"
TRAEFIK_PORTS=$(kubectl get svc -n traefik traefik -o jsonpath='{.spec.ports[*].nodePort}' 2>/dev/null || echo "")
if echo "$TRAEFIK_PORTS" | grep -q "32080"; then
  pass "Traefik web on final NodePort 32080"
else
  fail "Traefik web NOT on 32080. Got: $TRAEFIK_PORTS"
fi
if echo "$TRAEFIK_PORTS" | grep -q "32443"; then
  pass "Traefik websecure on final NodePort 32443"
else
  fail "Traefik websecure NOT on 32443. Got: $TRAEFIK_PORTS"
fi

# -------------------------------------------------------
# 3. No ArgoCD app for ingress-nginx
# -------------------------------------------------------
echo ""
echo "--- ArgoCD App Check ---"
if kubectl get application -n argocd ingress-nginx &>/dev/null; then
  fail "ArgoCD Application 'ingress-nginx' still exists"
else
  pass "ArgoCD Application 'ingress-nginx' removed"
fi

if kubectl get application -n argocd traefik &>/dev/null; then
  HEALTH=$(kubectl get application -n argocd traefik -o jsonpath='{.status.health.status}' 2>/dev/null || echo "unknown")
  SYNC=$(kubectl get application -n argocd traefik -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "unknown")
  if [ "$HEALTH" = "Healthy" ] && [ "$SYNC" = "Synced" ]; then
    pass "ArgoCD Application 'traefik' is Healthy/Synced"
  else
    warn "ArgoCD Application 'traefik' status: health=$HEALTH sync=$SYNC"
  fi
else
  fail "ArgoCD Application 'traefik' not found"
fi

# -------------------------------------------------------
# 4. Full app reachability on final ports
# -------------------------------------------------------
echo ""
echo "--- Full App Reachability (final ports) ---"

ALL_HOSTS=(
  "echo.dixneuf19.fr"
  "navidrome.dixneuf19.fr"
  "fip-slack-bot.dixneuf19.fr"
  "fip-telegram-bot.dixneuf19.fr"
  "dank-face-slack-bot.dixneuf19.fr"
  "spliit.dixneuf19.fr"
  "tricount.dixneuf19.fr"
  "baloocount.dixneuf19.fr"
  "readeck.dixneuf19.fr"
  "karakeep.dixneuf19.fr"
  "whoami.dixneuf19.fr"
  "karma.dixneuf19.fr"
  "cd-lna.dixneuf19.fr"
  "lms.dixneuf19.fr"
  "radioyoshi.dixneuf19.fr"
  "argocd.dixneuf19.fr"
  "grafana.dixneuf19.fr"
  "prometheus.dixneuf19.fr"
)

for HOST in "${ALL_HOSTS[@]}"; do
  if [ -n "$NODE_IP" ]; then
    CODE=$(curl -sk -o /dev/null -w "%{http_code}" --connect-timeout 5 -H "Host: ${HOST}" "https://${NODE_IP}:${HTTPS_PORT}" 2>/dev/null || echo "000")
    if [ "$CODE" = "000" ]; then
      fail "$HOST -> unreachable"
    elif [ "$CODE" = "200" ] || [ "$CODE" = "401" ] || [ "$CODE" = "302" ] || [ "$CODE" = "404" ] || [ "$CODE" = "405" ]; then
      pass "$HOST -> $CODE"
    else
      warn "$HOST -> $CODE (unexpected but not necessarily broken)"
    fi
  fi
done

# -------------------------------------------------------
# 5. HTTP -> HTTPS redirect works
# -------------------------------------------------------
echo ""
echo "--- HTTP to HTTPS Redirect ---"
if [ -n "$NODE_IP" ]; then
  CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 -H "Host: echo.dixneuf19.fr" "http://${NODE_IP}:32080" 2>/dev/null || echo "000")
  if [ "$CODE" = "301" ] || [ "$CODE" = "302" ] || [ "$CODE" = "308" ]; then
    pass "HTTP :32080 redirects to HTTPS (status: $CODE)"
  elif [ "$CODE" = "000" ]; then
    fail "HTTP :32080 unreachable"
  else
    warn "HTTP :32080 returned $CODE (expected 301/302/308 redirect)"
  fi
fi

# -------------------------------------------------------
# 6. TLS certificates valid
# -------------------------------------------------------
echo ""
echo "--- TLS Certificate Check ---"
CERT_HOSTS=("echo.dixneuf19.fr" "argocd.dixneuf19.fr" "grafana.dixneuf19.fr")
for HOST in "${CERT_HOSTS[@]}"; do
  if [ -n "$NODE_IP" ]; then
    CERT_SUBJECT=$(echo | openssl s_client -servername "$HOST" -connect "${NODE_IP}:${HTTPS_PORT}" 2>/dev/null | openssl x509 -noout -subject 2>/dev/null || echo "")
    if [ -n "$CERT_SUBJECT" ]; then
      EXPIRY=$(echo | openssl s_client -servername "$HOST" -connect "${NODE_IP}:${HTTPS_PORT}" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
      pass "$HOST has TLS cert (expires: $EXPIRY)"
    else
      warn "$HOST TLS cert could not be verified (may be using Traefik default cert until renewal)"
    fi
  fi
done

# -------------------------------------------------------
# 7. All certificates in cert-manager
# -------------------------------------------------------
echo ""
echo "--- cert-manager Certificates ---"
TOTAL_CERTS=$(kubectl get certificates -A --no-headers 2>/dev/null | wc -l || echo "0")
READY_CERTS=$(kubectl get certificates -A -o jsonpath='{range .items[?(@.status.conditions[0].status=="True")]}{.metadata.name}{"\n"}{end}' 2>/dev/null | wc -l || echo "0")
if [ "$TOTAL_CERTS" -eq "$READY_CERTS" ]; then
  pass "All $TOTAL_CERTS certificates are Ready"
else
  warn "$READY_CERTS/$TOTAL_CERTS certificates Ready"
  kubectl get certificates -A --no-headers 2>/dev/null | grep -v "True" || true
fi

# -------------------------------------------------------
# 8. No port conflicts
# -------------------------------------------------------
echo ""
echo "--- Port Conflict Check ---"
PORT_32080=$(kubectl get svc -A -o jsonpath='{range .items[*]}{range .spec.ports[*]}{.nodePort}{" "}{end}{end}' 2>/dev/null | tr ' ' '\n' | grep -c "32080" || true)
PORT_32443=$(kubectl get svc -A -o jsonpath='{range .items[*]}{range .spec.ports[*]}{.nodePort}{" "}{end}{end}' 2>/dev/null | tr ' ' '\n' | grep -c "32443" || true)
if [ "$PORT_32080" -eq 1 ]; then
  pass "NodePort 32080 used by exactly 1 service"
else
  fail "NodePort 32080 used by $PORT_32080 services (expected 1)"
fi
if [ "$PORT_32443" -eq 1 ]; then
  pass "NodePort 32443 used by exactly 1 service"
else
  fail "NodePort 32443 used by $PORT_32443 services (expected 1)"
fi

# Summary
echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS: $PASS${NC} | ${RED}FAIL: $FAIL${NC} | ${YELLOW}WARN: $WARN${NC}"
if [ "$FAIL" -gt 0 ]; then
  echo -e "${RED}Some checks failed. Migration not fully complete.${NC}"
  exit 1
else
  echo -e "${GREEN}Migration complete! ingress-nginx removed, Traefik serving all traffic on final ports.${NC}"
  echo ""
  echo "Next step (Phase B): Migrate Ingress resources to Gateway API HTTPRoute"
fi
