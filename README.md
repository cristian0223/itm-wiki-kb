# Actividad 5 - IaC - CI - CD - Observabilidad · Wikis / Knowledge bases

Instituto Tecnológico Metropolitano (ITM) · Despliegue de software · 27 de noviembre de 2026
Erian Jose Serna Marin · Sara Arciniegas Villa · Cristian Camilo Cano Garcia

Wiki corporativa **BookStack** desplegada con **Terraform** sobre **Docker**, con costo **cero**:
no usa ninguna nube de pago. Terraform crea 10 servicios contenerizados (la wiki, MariaDB, Redis y
la pila de observabilidad: Prometheus, Alertmanager, Grafana, exportadores y un buzón de correo
local) y los pipelines de **GitHub Actions** los prueban y los destruyen de forma automática.

```
.
├── infra/               Terraform: red, volúmenes, secretos, datos, wiki y observabilidad
├── app/                 Imagen de la wiki (BookStack + configuración de Redis)
├── scripts/             Pruebas, verificación de observabilidad, prueba de alertas y capturas
├── docker-compose.yml   Entorno rápido para el CI de la aplicación
└── .github/workflows/   app.yml (Opción A) e infra.yml (Opción B)
```

## Opción 1: todo en GitHub Actions (recomendada, no requiere instalar nada)

1. Crear un repositorio **público** en GitHub llamado `itm-wiki-kb` (en repositorios públicos los
   minutos de Actions y GHCR son gratuitos e ilimitados).
2. Subir este código a la rama `main`.
3. En la pestaña **Actions** se ejecutan los dos pipelines. El de infraestructura despliega todo,
   lo prueba, genera las capturas y destruye los recursos.
4. Descargar el artefacto `evidencias-N` al final de la ejecución de *IaC - Terraform (Opcion B)*.

```bash
gh repo create itm-wiki-kb --public --source=. --remote=origin
git add . && git commit -m "Actividad 5: IaC + CI/CD + observabilidad" && git push -u origin main
gh run watch
gh run download --name "evidencias-1" --dir evidencias
```

## Opción 2: en el propio computador (Docker Desktop + Terraform)

```bash
terraform -chdir=infra init
terraform -chdir=infra apply                # escribir: yes   (en Windows: -var enable_cadvisor=false)
terraform -chdir=infra output urls
./scripts/smoke-test.sh http://localhost:6875
./scripts/check-observability.sh            # requiere jq
terraform -chdir=infra destroy              # escribir: yes
```

En Windows (PowerShell), antes de `init`: `$env:DOCKER_HOST="npipe:////./pipe/docker_engine"`.

| Servicio | Dirección |
| --- | --- |
| Wiki (BookStack) | http://localhost:6875 · `admin@admin.com` / `password` |
| Grafana | http://localhost:3000 (lectura anónima) |
| Prometheus | http://localhost:9090 |
| Alertmanager | http://localhost:9093 |
| Buzón de alertas (Mailpit) | http://localhost:8025 |
