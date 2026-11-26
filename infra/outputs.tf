output "urls" {
  description = "Direcciones de la wiki y de las herramientas de observabilidad."

  value = {
    wiki         = "http://localhost:${var.ports.wiki}"
    wiki_status  = "http://localhost:${var.ports.wiki}/status"
    grafana      = "http://localhost:${var.ports.grafana}/d/itm-wiki"
    prometheus   = "http://localhost:${var.ports.prometheus}"
    alertmanager = "http://localhost:${var.ports.alertmanager}"
    correo       = "http://localhost:${var.ports.mailpit}"
  }
}

output "contenedores" {
  description = "Contenedores creados por Terraform."

  value = concat(
    [
      docker_container.bookstack.name,
      docker_container.mariadb.name,
      docker_container.redis.name,
      docker_container.mysqld_exporter.name,
      docker_container.redis_exporter.name,
      docker_container.blackbox.name,
      docker_container.prometheus.name,
      docker_container.alertmanager.name,
      docker_container.mailpit.name,
      docker_container.grafana.name,
    ],
    docker_container.cadvisor[*].name,
  )
}

output "reglas_de_alerta" {
  description = "Reglas de alerta definidas en Prometheus."
  value       = flatten([for g in local.alert_rules.groups : [for r in g.rules : r.alert]])
}

output "wiki_login_inicial" {
  description = "Usuario inicial de BookStack (cambiar la contrasena al primer ingreso)."
  value       = "admin@admin.com / password"
}

output "grafana_admin_password" {
  description = "Contrasena del usuario admin de Grafana (terraform output -raw grafana_admin_password)."
  value       = random_password.grafana_admin.result
  sensitive   = true
}
