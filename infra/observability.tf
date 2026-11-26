# =============================================================================
# OBSERVABILIDAD COMO CODIGO (servicios)
#  Exportadores: mysqld-exporter (MariaDB), redis-exporter, blackbox (/status),
#                cAdvisor (CPU y memoria por contenedor)
#  Prometheus:   recolecta metricas y evalua 8 reglas de alerta
#  Alertmanager: envia las alertas por correo
#  Mailpit:      buzon SMTP local y gratuito donde llegan esos correos
#  Grafana:      dashboard aprovisionado desde Terraform
# =============================================================================

# ------------------------------- Exportadores --------------------------------
resource "docker_image" "mysqld_exporter" {
  name         = "prom/mysqld-exporter:v0.15.1"
  keep_locally = true
}

resource "docker_container" "mysqld_exporter" {
  name    = "${local.prefix}-mysqld-exporter"
  image   = docker_image.mysqld_exporter.image_id
  restart = "unless-stopped"
  command = ["--mysqld.address=mariadb:3306", "--mysqld.username=exporter"]
  env     = ["MYSQLD_EXPORTER_PASSWORD=${random_password.db_exporter.result}"]

  networks_advanced {
    name    = docker_network.wiki.name
    aliases = ["mysqld-exporter"]
  }

  labels {
    label = "project"
    value = var.project_name
  }

  depends_on = [docker_container.mariadb]
}

resource "docker_image" "redis_exporter" {
  name         = "oliver006/redis_exporter:v1.62.0"
  keep_locally = true
}

resource "docker_container" "redis_exporter" {
  name    = "${local.prefix}-redis-exporter"
  image   = docker_image.redis_exporter.image_id
  restart = "unless-stopped"
  env     = ["REDIS_ADDR=redis://redis:6379", "REDIS_PASSWORD=${random_password.redis.result}"]

  networks_advanced {
    name    = docker_network.wiki.name
    aliases = ["redis-exporter"]
  }

  labels {
    label = "project"
    value = var.project_name
  }

  depends_on = [docker_container.redis]
}

resource "docker_image" "blackbox" {
  name         = "prom/blackbox-exporter:v0.25.0"
  keep_locally = true
}

resource "docker_container" "blackbox" {
  name    = "${local.prefix}-blackbox-exporter"
  image   = docker_image.blackbox.image_id
  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.wiki.name
    aliases = ["blackbox-exporter"]
  }

  labels {
    label = "project"
    value = var.project_name
  }
}

resource "docker_image" "cadvisor" {
  count = var.enable_cadvisor ? 1 : 0

  name         = "gcr.io/cadvisor/cadvisor:v0.49.1"
  keep_locally = true
}

resource "docker_container" "cadvisor" {
  count = var.enable_cadvisor ? 1 : 0

  name       = "${local.prefix}-cadvisor"
  image      = docker_image.cadvisor[0].image_id
  restart    = "unless-stopped"
  privileged = true
  command    = ["--docker_only=true", "--housekeeping_interval=10s", "--store_container_labels=false"]

  networks_advanced {
    name    = docker_network.wiki.name
    aliases = ["cadvisor"]
  }

  volumes {
    host_path      = "/"
    container_path = "/rootfs"
    read_only      = true
  }

  volumes {
    host_path      = "/var/run"
    container_path = "/var/run"
    read_only      = true
  }

  volumes {
    host_path      = "/sys"
    container_path = "/sys"
    read_only      = true
  }

  volumes {
    host_path      = "/var/lib/docker"
    container_path = "/var/lib/docker"
    read_only      = true
  }

  labels {
    label = "project"
    value = var.project_name
  }
}

# --------------------------------- Prometheus --------------------------------
resource "docker_image" "prometheus" {
  name         = "prom/prometheus:v2.54.1"
  keep_locally = true
}

resource "docker_container" "prometheus" {
  name    = "${local.prefix}-prometheus"
  image   = docker_image.prometheus.image_id
  restart = "unless-stopped"

  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--storage.tsdb.path=/prometheus",
    "--storage.tsdb.retention.time=7d",
    "--web.enable-lifecycle",
  ]

  networks_advanced {
    name    = docker_network.wiki.name
    aliases = ["prometheus"]
  }

  ports {
    internal = 9090
    external = var.ports.prometheus
    ip       = var.bind_ip
  }

  volumes {
    volume_name    = docker_volume.prometheus.name
    container_path = "/prometheus"
  }

  upload {
    file    = "/etc/prometheus/prometheus.yml"
    content = yamlencode(local.prometheus_config)
  }

  upload {
    file    = "/etc/prometheus/alerts.yml"
    content = yamlencode(local.alert_rules)
  }

  labels {
    label = "project"
    value = var.project_name
  }

  depends_on = [
    docker_container.mysqld_exporter,
    docker_container.redis_exporter,
    docker_container.blackbox,
  ]
}

# -------------------------------- Alertmanager -------------------------------
resource "docker_image" "mailpit" {
  name         = "axllent/mailpit:v1.20.0"
  keep_locally = true
}

resource "docker_container" "mailpit" {
  name    = "${local.prefix}-mailpit"
  image   = docker_image.mailpit.image_id
  restart = "unless-stopped"
  env     = ["MP_SMTP_AUTH_ACCEPT_ANY=1", "MP_SMTP_AUTH_ALLOW_INSECURE=1", "TZ=${var.timezone}"]

  networks_advanced {
    name    = docker_network.wiki.name
    aliases = ["mailpit"]
  }

  ports {
    internal = 8025
    external = var.ports.mailpit
    ip       = var.bind_ip
  }

  labels {
    label = "project"
    value = var.project_name
  }
}

resource "docker_image" "alertmanager" {
  name         = "prom/alertmanager:v0.27.0"
  keep_locally = true
}

resource "docker_container" "alertmanager" {
  name    = "${local.prefix}-alertmanager"
  image   = docker_image.alertmanager.image_id
  restart = "unless-stopped"
  command = ["--config.file=/etc/alertmanager/alertmanager.yml", "--storage.path=/alertmanager"]

  networks_advanced {
    name    = docker_network.wiki.name
    aliases = ["alertmanager"]
  }

  ports {
    internal = 9093
    external = var.ports.alertmanager
    ip       = var.bind_ip
  }

  upload {
    file    = "/etc/alertmanager/alertmanager.yml"
    content = yamlencode(local.alertmanager_config)
  }

  labels {
    label = "project"
    value = var.project_name
  }

  depends_on = [docker_container.mailpit]
}

# ---------------------------------- Grafana ----------------------------------
resource "docker_image" "grafana" {
  name         = "grafana/grafana:11.2.0"
  keep_locally = true
}

resource "docker_container" "grafana" {
  name    = "${local.prefix}-grafana"
  image   = docker_image.grafana.image_id
  restart = "unless-stopped"

  env = [
    "GF_SECURITY_ADMIN_USER=admin",
    "GF_SECURITY_ADMIN_PASSWORD=${random_password.grafana_admin.result}",
    "GF_AUTH_ANONYMOUS_ENABLED=true",
    "GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer",
    "GF_USERS_DEFAULT_THEME=light",
    "GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/etc/grafana/dashboards/itm-wiki.json",
    "GF_ANALYTICS_REPORTING_ENABLED=false",
    "GF_NEWS_NEWS_FEED_ENABLED=false",
  ]

  networks_advanced {
    name    = docker_network.wiki.name
    aliases = ["grafana"]
  }

  ports {
    internal = 3000
    external = var.ports.grafana
    ip       = var.bind_ip
  }

  volumes {
    volume_name    = docker_volume.grafana.name
    container_path = "/var/lib/grafana"
  }

  upload {
    file    = "/etc/grafana/provisioning/datasources/prometheus.yml"
    content = yamlencode(local.grafana_datasources)
  }

  upload {
    file    = "/etc/grafana/provisioning/dashboards/itm-wiki.yml"
    content = yamlencode(local.grafana_dashboard_provider)
  }

  upload {
    file    = "/etc/grafana/dashboards/itm-wiki.json"
    content = jsonencode(local.grafana_dashboard)
  }

  labels {
    label = "project"
    value = var.project_name
  }

  depends_on = [docker_container.prometheus]
}
