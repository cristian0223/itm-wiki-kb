#!/usr/bin/env bash
# Genera trafico contra la wiki para poblar las graficas de Grafana.
# Uso: ./scripts/generate-traffic.sh <URL_BASE> [RONDAS]
set -euo pipefail

BASE_URL="${1:?Indique la URL base de la wiki}"
ROUNDS="${2:-150}"

echo "Enviando ${ROUNDS} rondas de peticiones a ${BASE_URL} ..."
ok=0; other=0
for i in $(seq 1 "$ROUNDS"); do
  for path in / /status /login /search?term=terraform /books; do
    code="$(curl -s -o /dev/null -w '%{http_code}' "${BASE_URL}${path}" || echo 000)"
    case "$code" in
      2*|3*) ok=$((ok + 1)) ;;
      *) other=$((other + 1)) ;;
    esac
  done
  if [ $((i % 50)) -eq 0 ]; then echo "  ${i}/${ROUNDS} rondas (ok=${ok}, otros=${other})"; fi
done
echo "Listo: respuestas ok=${ok}, otros codigos=${other}"
