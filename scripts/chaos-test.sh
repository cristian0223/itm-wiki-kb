#!/usr/bin/env bash
# Prueba controlada de alertas de punta a punta:
#   1. detenemos Redis
#   2. Prometheus dispara RedisCaido (y WikiNoDisponible)
#   3. Alertmanager envia el correo, que llega al buzon de Mailpit
#   4. (opcional) se toma la captura de la evidencia
#   5. encendemos Redis de nuevo y comprobamos que la wiki se recupera
# Uso: ./scripts/chaos-test.sh [CARPETA_EVIDENCIAS]
set -euo pipefail

EVIDENCE_DIR="${1:-}"
PREFIX="${PROJECT_NAME:-itm-wiki}"
PROM="${PROM_URL:-http://localhost:9090}"
AM="${AM_URL:-http://localhost:9093}"
MAIL="${MAIL_URL:-http://localhost:8025}"
WIKI="${WIKI_URL:-http://localhost:6875}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

restore() { docker start "${PREFIX}-redis" > /dev/null 2>&1 || true; }
trap restore EXIT

echo "==> Simulamos una falla: detenemos ${PREFIX}-redis"
docker stop "${PREFIX}-redis"

echo "==> Esperando que Prometheus dispare RedisCaido (maximo 5 minutos)"
firing=""
for i in $(seq 1 30); do
  firing="$(curl -s "$PROM/api/v1/alerts" | jq -r '[.data.alerts[] | select(.state == "firing") | .labels.alertname] | unique | join(", ")')"
  echo "    intento ${i}: alertas disparadas = ${firing:-ninguna}"
  echo "$firing" | grep -q "RedisCaido" && break
  sleep 10
done
echo "$firing" | grep -q "RedisCaido" || { echo "ERROR: la alerta RedisCaido no se disparo"; exit 1; }

echo "==> Esperando el correo de Alertmanager en Mailpit"
total=0
for i in $(seq 1 24); do
  total="$(curl -s "$MAIL/api/v1/messages" | jq -r '.total // .messages_count // 0')"
  [ "$total" -ge 1 ] && break
  sleep 5
done
[ "$total" -ge 1 ] || { echo "ERROR: no llego ningun correo de alerta"; exit 1; }
curl -s "$MAIL/api/v1/messages" | jq -r '.messages[] | "    Correo: \(.Subject)  ->  \(.To[0].Address)"'

if [ -n "$EVIDENCE_DIR" ]; then
  node "$SCRIPT_DIR/evidencias.mjs" alertas "$AM" "$MAIL" "$EVIDENCE_DIR/figura-6-alerta-y-correo.png" || echo "    (no se pudo generar la captura)"
fi

echo "==> Encendemos Redis de nuevo"
docker start "${PREFIX}-redis"
trap - EXIT

echo "==> Esperando que la wiki se recupere"
for i in $(seq 1 24); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "$WIKI/status" || true)"
  [ "$code" = "200" ] && { echo "    OK: /status volvio a responder 200"; break; }
  sleep 5
done
[ "$code" = "200" ] || { echo "ERROR: la wiki no se recupero"; exit 1; }

echo "==> PRUEBA DE ALERTAS SUPERADA (falla detectada, correo enviado y servicio recuperado)"
