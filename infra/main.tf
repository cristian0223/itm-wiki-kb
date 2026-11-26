# -----------------------------------------------------------------------------
# Base comun: red privada, volumenes persistentes y secretos generados.
# Todo corre sobre Docker local o sobre el runner gratuito de GitHub Actions.
# -----------------------------------------------------------------------------

locals {
  prefix   = var.project_name
  app_dir  = abspath("${path.module}/../app")
  app_hash = sha1(join("", [for f in sort(fileset(local.app_dir, "**")) : filesha1("${local.app_dir}/${f}")]))
}

resource "docker_network" "wiki" {
  name   = "${local.prefix}-net"
  driver = "bridge"
}

resource "docker_volume" "mariadb" {
  name = "${local.prefix}-mariadb-data"
}

resource "docker_volume" "redis" {
  name = "${local.prefix}-redis-data"
}

resource "docker_volume" "bookstack" {
  name = "${local.prefix}-bookstack-config"
}

resource "docker_volume" "prometheus" {
  name = "${local.prefix}-prometheus-data"
}

resource "docker_volume" "grafana" {
  name = "${local.prefix}-grafana-data"
}

# Secretos: Terraform los genera y los entrega a cada contenedor.
# Nunca se escriben en el repositorio.
resource "random_password" "db" {
  length  = 24
  special = false
}

resource "random_password" "db_root" {
  length  = 24
  special = false
}

resource "random_password" "db_exporter" {
  length  = 24
  special = false
}

resource "random_password" "redis" {
  length  = 24
  special = false
}

resource "random_password" "grafana_admin" {
  length  = 20
  special = false
}

resource "random_id" "app_key" {
  byte_length = 32
}
