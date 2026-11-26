# -----------------------------------------------------------------------------
# Capa de datos administrada con Terraform:
#  - MariaDB 11.4 (relacional): contenido de la wiki, usuarios y permisos.
#  - Redis 7.4 (en memoria): cache de la aplicacion y sesiones de usuario.
# Version fija, volumen persistente, credenciales generadas, health check
# y limite de memoria, todo declarado aqui.
# -----------------------------------------------------------------------------

resource "docker_image" "mariadb" {
  name         = "mariadb:11.4"
  keep_locally = true
}

resource "docker_container" "mariadb" {
  name    = "${local.prefix}-mariadb"
  image   = docker_image.mariadb.image_id
  restart = "unless-stopped"
  memory  = 512

  env = [
    "MARIADB_DATABASE=bookstack",
    "MARIADB_USER=bookstack",
    "MARIADB_PASSWORD=${random_password.db.result}",
    "MARIADB_ROOT_PASSWORD=${random_password.db_root.result}",
    "TZ=${var.timezone}",
  ]

  networks_advanced {
    name    = docker_network.wiki.name
    aliases = ["mariadb"]
  }

  volumes {
    volume_name    = docker_volume.mariadb.name
    container_path = "/var/lib/mysql"
  }

  # Usuario de solo lectura para el exportador de metricas de Prometheus.
  upload {
    file = "/docker-entrypoint-initdb.d/10-exporter.sql"

    content = <<-SQL
      CREATE USER IF NOT EXISTS 'exporter'@'%' IDENTIFIED BY '${random_password.db_exporter.result}' WITH MAX_USER_CONNECTIONS 3;
      GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';
      FLUSH PRIVILEGES;
    SQL
  }

  healthcheck {
    test         = ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
    interval     = "10s"
    timeout      = "5s"
    retries      = 12
    start_period = "20s"
  }

  wait         = true
  wait_timeout = 240

  labels {
    label = "project"
    value = var.project_name
  }
}

resource "docker_image" "redis" {
  name         = "redis:7.4-alpine"
  keep_locally = true
}

resource "docker_container" "redis" {
  name    = "${local.prefix}-redis"
  image   = docker_image.redis.image_id
  restart = "unless-stopped"
  memory  = 192

  command = [
    "redis-server",
    "--requirepass", random_password.redis.result,
    "--appendonly", "yes",
    "--maxmemory", "128mb",
    "--maxmemory-policy", "allkeys-lru",
  ]

  env = ["REDIS_PASSWORD=${random_password.redis.result}"]

  networks_advanced {
    name    = docker_network.wiki.name
    aliases = ["redis"]
  }

  volumes {
    volume_name    = docker_volume.redis.name
    container_path = "/data"
  }

  healthcheck {
    test         = ["CMD-SHELL", "redis-cli -a \"$REDIS_PASSWORD\" --no-auth-warning ping | grep -q PONG"]
    interval     = "10s"
    timeout      = "5s"
    retries      = 6
    start_period = "5s"
  }

  wait         = true
  wait_timeout = 120

  labels {
    label = "project"
    value = var.project_name
  }
}
