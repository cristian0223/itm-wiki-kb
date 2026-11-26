#!/usr/bin/env bash
# Arma el texto de las evidencias que salen de la terminal.
# Uso: ./scripts/evidence-text.sh <plan|contenedores|destruccion> <salida.txt>
set -uo pipefail

PHASE="${1:?Fase: plan | contenedores | destruccion}"
OUT="${2:?Archivo de salida}"
PREFIX="${PROJECT_NAME:-itm-wiki}"
EV_DIR="$(dirname "$OUT")"

case "$PHASE" in
  plan)
    {
      echo '$ terraform -chdir=infra validate'
      terraform -chdir=infra validate -no-color
      echo
      echo '$ terraform -chdir=infra plan -out=tfplan'
      grep -E 'will be created|will be read|^Plan:' "$EV_DIR/plan.txt"
    } > "$OUT" 2>&1
    ;;
  contenedores)
    {
      echo '$ docker ps --filter label=project='"$PREFIX"
      docker ps --filter "label=project=${PREFIX}" --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
      echo
      echo '$ curl -s http://localhost:6875/status'
      curl -s http://localhost:6875/status; echo
      echo
      echo '$ docker exec '"$PREFIX"'-mariadb mariadb -e "SELECT VERSION(), tablas de bookstack"'
      docker exec "${PREFIX}-mariadb" sh -c 'mariadb -ubookstack -p"$MARIADB_PASSWORD" bookstack -e "SELECT VERSION() AS version_mariadb, (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE()) AS tablas_bookstack;"'
      echo
      echo '$ docker exec '"$PREFIX"'-redis redis-cli INFO keyspace'
      docker exec "${PREFIX}-redis" sh -c 'redis-cli -a "$REDIS_PASSWORD" --no-auth-warning INFO keyspace'
      echo
      echo '$ terraform -chdir=infra output contenedores'
      terraform -chdir=infra output contenedores
    } > "$OUT" 2>&1
    ;;
  destruccion)
    {
      echo '$ terraform -chdir=infra destroy -auto-approve'
      grep -E 'Destroying|Destruction complete|Destroy complete' "$EV_DIR/destroy.txt" | tail -n 25
      echo
      echo '$ docker ps -a --filter label=project='"$PREFIX"
      n="$(docker ps -aq --filter "label=project=${PREFIX}" | wc -l)"
      [ "$n" = "0" ] && echo 'OK: ningun contenedor del proyecto sigue existiendo' || docker ps -a --filter "label=project=${PREFIX}"
      echo
      echo '$ docker volume ls --filter name='"$PREFIX"
      v="$(docker volume ls -q --filter "name=${PREFIX}" | wc -l)"
      [ "$v" = "0" ] && echo 'OK: ningun volumen del proyecto sigue existiendo' || docker volume ls --filter "name=${PREFIX}"
      echo
      echo '$ docker network ls --filter name='"$PREFIX"
      w="$(docker network ls -q --filter "name=${PREFIX}" | wc -l)"
      [ "$w" = "0" ] && echo 'OK: la red del proyecto fue eliminada' || docker network ls --filter "name=${PREFIX}"
      echo
      echo '$ terraform -chdir=infra state list | wc -l'
      terraform -chdir=infra state list 2>/dev/null | wc -l
    } > "$OUT" 2>&1
    ;;
  *)
    echo "Fase desconocida: $PHASE"; exit 2 ;;
esac

echo "Texto de evidencia: $OUT"
