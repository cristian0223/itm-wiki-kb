#!/usr/bin/env bash
# Prueba de humo de la wiki.
# Uso: ./scripts/smoke-test.sh <URL_BASE> [COMMIT_ESPERADO]
set -euo pipefail

BASE_URL="${1:?Indique la URL base, ej. http://localhost:6875}"
EXPECTED_SHA="${2:-}"
ATTEMPTS="${ATTEMPTS:-40}"
SLEEP_SECONDS="${SLEEP_SECONDS:-10}"
TMP="$(mktemp)"

echo "==> Esperando que ${BASE_URL}/status responda 200"
code=""
for i in $(seq 1 "$ATTEMPTS"); do
  code="$(curl -s -o "$TMP" -w '%{http_code}' "${BASE_URL}/status" || true)"
  [ "$code" = "200" ] && break
  echo "    intento ${i}/${ATTEMPTS}: HTTP ${code:-sin respuesta}"
  sleep "$SLEEP_SECONDS"
done

if [ "$code" != "200" ]; then
  echo "ERROR: /status no respondio 200"
  cat "$TMP" 2>/dev/null || true
  exit 1
fi

echo "==> /status: $(cat "$TMP")"
for check in database cache session; do
  grep -q "\"${check}\":true" "$TMP" || { echo "ERROR: '${check}' no es true"; exit 1; }
done
echo "    OK: base de datos, cache (Redis) y sesion funcionan"

login_code="$(curl -s -o /dev/null -w '%{http_code}' "${BASE_URL}/login")"
[ "$login_code" = "200" ] || { echo "ERROR: /login respondio HTTP ${login_code}"; exit 1; }
echo "==> /login: HTTP 200"

build_info="$(curl -s "${BASE_URL}/build-info.json" || true)"
echo "==> build-info.json: ${build_info:-no disponible}"
if [ -n "$EXPECTED_SHA" ]; then
  echo "$build_info" | grep -q "$EXPECTED_SHA" || { echo "ERROR: el commit desplegado no es ${EXPECTED_SHA}"; exit 1; }
  echo "    OK: se esta sirviendo el commit ${EXPECTED_SHA}"
fi

rm -f "$TMP"
echo "==> PRUEBA DE HUMO SUPERADA"
