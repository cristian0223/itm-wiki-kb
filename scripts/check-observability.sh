#!/usr/bin/env bash
# Verifica que la observabilidad desplegada por Terraform este activa:
# Prometheus con todos sus objetivos arriba y las 8 reglas cargadas,
# Alertmanager listo, Grafana sano con el dashboard y el buzon de Mailpit.
set -euo pipefail

PROM="${PROM_URL:-http://localhost:9090}"
AM="${AM_URL:-http://localhost:9093}"
GRAFANA="${GRAFANA_URL:-http://localhost:3000}"
MAIL="${MAIL_URL:-http://localhost:8025}"

wait_ok() {
  local url="$1" name="$2"
  for i in $(seq 1 30); do
    if curl -fsS -o /dev/null "$url"; then echo "    OK: ${name}"; return 0; fi
    sleep 5
  done
  echo "ERROR: ${name} no responde (${url})"; return 1
}

echo "==> Servicios de observabilidad"
wait_ok "$PROM/-/ready" "Prometheus listo"
wait_ok "$AM/-/ready" "Alertmanager listo"
wait_ok "$GRAFANA/api/health" "Grafana sano"
wait_ok "$MAIL/api/v1/messages" "Mailpit (buzon de alertas) disponible"

echo "==> Objetivos de Prometheus (los principales deben estar 'up'; cAdvisor es opcional)"
for i in $(seq 1 24); do
  down="$(curl -s "$PROM/api/v1/targets" | jq '[.data.activeTargets[] | select(.health != "up" and .labels.job != "cadvisor")] | length')"
  [ "$down" = "0" ] && break
  sleep 5
done
curl -s "$PROM/api/v1/targets" | jq -r '.data.activeTargets[] | "    \(.labels.job)\t\(.health)\t\(.scrapeUrl)"' | sort
[ "$down" = "0" ] || { echo "ERROR: hay objetivos caidos"; exit 1; }

echo "==> Reglas de alerta cargadas en Prometheus"
curl -s "$PROM/api/v1/rules" | jq -r '.data.groups[] | .name as $g | .rules[] | "    \($g)\t\(.name)\t\(.health)"'
rules="$(curl -s "$PROM/api/v1/rules" | jq '[.data.groups[].rules[]] | length')"
echo "    Total: ${rules} reglas"
[ "$rules" -ge 8 ] || { echo "ERROR: se esperaban 8 reglas"; exit 1; }

echo "==> Dashboard aprovisionado en Grafana"
title="$(curl -s "$GRAFANA/api/dashboards/uid/itm-wiki" | jq -r '.dashboard.title // empty')"
[ -n "$title" ] || { echo "ERROR: no se encontro el dashboard itm-wiki"; exit 1; }
echo "    OK: ${title}"

echo "==> OBSERVABILIDAD ACTIVA"
