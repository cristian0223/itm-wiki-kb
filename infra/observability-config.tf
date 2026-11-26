# =============================================================================
# OBSERVABILIDAD COMO CODIGO (configuracion)
# Prometheus (metricas + 8 reglas de alerta), Alertmanager (aviso por correo)
# y Grafana (fuente de datos + dashboard) se generan desde estas estructuras.
# =============================================================================

locals {
  scrape_jobs = [
    {
      job_name       = "prometheus"
      static_configs = [{ targets = ["localhost:9090"] }]
    },
    {
      job_name       = "mariadb"
      static_configs = [{ targets = ["mysqld-exporter:9104"] }]
    },
    {
      job_name       = "redis"
      static_configs = [{ targets = ["redis-exporter:9121"] }]
    },
    {
      job_name       = "alertmanager"
      static_configs = [{ targets = ["alertmanager:9093"] }]
    },
    {
      job_name       = "grafana"
      static_configs = [{ targets = ["grafana:3000"] }]
    },
    {
      job_name       = "cadvisor"
      static_configs = [{ targets = ["cadvisor:8080"] }]
    },
    {
      job_name       = "wiki_status"
      metrics_path   = "/probe"
      params         = { module = ["http_2xx"] }
      static_configs = [{ targets = ["http://bookstack/status"] }]

      relabel_configs = [
        { source_labels = ["__address__"], target_label = "__param_target" },
        { source_labels = ["__param_target"], target_label = "instance" },
        { target_label = "__address__", replacement = "blackbox-exporter:9115" },
      ]
    },
  ]

  prometheus_config = {
    global = {
      scrape_interval     = "15s"
      evaluation_interval = "15s"
      external_labels     = { proyecto = var.project_name }
    }
    rule_files = ["/etc/prometheus/alerts.yml"]

    alerting = {
      alertmanagers = [{ static_configs = [{ targets = ["alertmanager:9093"] }] }]
    }
    scrape_configs = [for job in local.scrape_jobs : job if job.job_name != "cadvisor" || var.enable_cadvisor]
  }

  alert_rules = {
    groups = [
      {
        name = "wiki-disponibilidad"

        rules = [
          {
            alert  = "WikiNoDisponible"
            expr   = "probe_success{job=\"wiki_status\"} == 0"
            "for"  = "1m"
            labels = { severity = "critical" }

            annotations = {
              summary     = "La wiki no responde en /status"
              description = "BookStack no pasa su chequeo de salud desde hace 1 minuto. Revisar MariaDB, Redis o el contenedor de la aplicacion."
            }
          },
          {
            alert  = "WikiLenta"
            expr   = "probe_duration_seconds{job=\"wiki_status\"} > 2"
            "for"  = "5m"
            labels = { severity = "warning" }

            annotations = {
              summary     = "La wiki tarda mas de 2 segundos en responder"
              description = "El chequeo de /status supera los 2 segundos durante 5 minutos."
            }
          },
          {
            alert  = "ObjetivoDeMonitoreoCaido"
            expr   = "up == 0"
            "for"  = "2m"
            labels = { severity = "warning" }

            annotations = {
              summary     = "Prometheus no puede leer {{ $labels.job }}"
              description = "El objetivo {{ $labels.instance }} del job {{ $labels.job }} no responde desde hace 2 minutos."
            }
          },
        ]
      },
      {
        name = "wiki-datos"

        rules = [
          {
            alert  = "MariaDBCaida"
            expr   = "mysql_up == 0"
            "for"  = "1m"
            labels = { severity = "critical" }

            annotations = {
              summary     = "MariaDB no responde"
              description = "El exportador no logra conectarse a MariaDB desde hace 1 minuto."
            }
          },
          {
            alert  = "MariaDBConexionesAltas"
            expr   = "mysql_global_status_threads_connected / mysql_global_variables_max_connections > 0.8"
            "for"  = "5m"
            labels = { severity = "warning" }

            annotations = {
              summary     = "MariaDB usa mas del 80% de sus conexiones"
              description = "Las conexiones abiertas superan el 80% del maximo durante 5 minutos."
            }
          },
          {
            alert  = "RedisCaido"
            expr   = "redis_up == 0"
            "for"  = "1m"
            labels = { severity = "critical" }

            annotations = {
              summary     = "Redis no responde"
              description = "La cache y las sesiones de la wiki no estan disponibles desde hace 1 minuto."
            }
          },
          {
            alert  = "RedisMemoriaAlta"
            expr   = "(redis_memory_used_bytes / redis_memory_max_bytes > 0.8) and redis_memory_max_bytes > 0"
            "for"  = "5m"
            labels = { severity = "warning" }

            annotations = {
              summary     = "Redis usa mas del 80% de su memoria"
              description = "Redis empezara a descartar claves de la cache."
            }
          },
        ]
      },
      {
        name = "wiki-contenedores"

        rules = [
          {
            alert  = "ContenedorCPUAlta"
            expr   = "sum by (name) (rate(container_cpu_usage_seconds_total{name=~\"${var.project_name}-.*\"}[2m])) > 0.8"
            "for"  = "5m"
            labels = { severity = "warning" }

            annotations = {
              summary     = "El contenedor {{ $labels.name }} usa mas de 0,8 CPU"
              description = "Consumo sostenido de CPU durante 5 minutos."
            }
          },
        ]
      },
    ]
  }

  alertmanager_config = {
    route = {
      receiver        = "equipo-correo"
      group_by        = ["alertname"]
      group_wait      = "10s"
      group_interval  = "1m"
      repeat_interval = "3h"
    }

    receivers = [
      {
        name = "equipo-correo"

        email_configs = [
          {
            to            = var.alert_email
            from          = "alertas-wiki@itm-wiki.local"
            smarthost     = "mailpit:1025"
            require_tls   = false
            send_resolved = true
          },
        ]
      },
    ]
  }

  grafana_datasources = {
    apiVersion = 1

    datasources = [
      {
        name      = "Prometheus"
        uid       = "prometheus"
        type      = "prometheus"
        access    = "proxy"
        url       = "http://prometheus:9090"
        isDefault = true
      },
    ]
  }

  grafana_dashboard_provider = {
    apiVersion = 1

    providers = [
      {
        name            = "itm-wiki"
        folder          = "ITM Wiki"
        type            = "file"
        disableDeletion = true
        options         = { path = "/etc/grafana/dashboards" }
      },
    ]
  }

  # ------------------------------- Dashboard ----------------------------------
  ds = { type = "prometheus", uid = "prometheus" }

  up_mappings = [
    {
      type = "value"

      options = {
        "0" = { text = "Caido", color = "red" }
        "1" = { text = "Arriba", color = "green" }
      }
    },
  ]

  stat_defs = [
    { title = "Wiki (/status)", expr = "probe_success{job=\"wiki_status\"}" },
    { title = "MariaDB", expr = "mysql_up" },
    { title = "Redis", expr = "redis_up" },
  ]

  stat_panels = [for i, d in local.stat_defs : {
    id         = i + 1
    type       = "stat"
    title      = d.title
    datasource = local.ds
    gridPos    = { h = 5, w = 6, x = i * 6, y = 0 }
    targets    = [{ refId = "A", expr = d.expr, datasource = local.ds }]
    options    = { colorMode = "background", graphMode = "none", reduceOptions = { calcs = ["lastNotNull"], fields = "", values = false } }

    fieldConfig = {
      defaults = {
        mappings   = local.up_mappings
        thresholds = { mode = "absolute", steps = [{ color = "red", value = null }, { color = "green", value = 1 }] }
      }
      overrides = []
    }
  }]

  alerts_panel = {
    id         = 4
    type       = "stat"
    title      = "Alertas activas"
    datasource = local.ds
    gridPos    = { h = 5, w = 6, x = 18, y = 0 }
    targets    = [{ refId = "A", expr = "count(ALERTS{alertstate=\"firing\"}) or vector(0)", datasource = local.ds }]
    options    = { colorMode = "background", graphMode = "none", reduceOptions = { calcs = ["lastNotNull"], fields = "", values = false } }

    fieldConfig = {
      defaults = {
        thresholds = { mode = "absolute", steps = [{ color = "green", value = null }, { color = "red", value = 1 }] }
      }
      overrides = []
    }
  }

  ts_defs = [
    {
      title   = "Latencia de /status (s)"
      unit    = "s"
      targets = [{ expr = "probe_duration_seconds{job=\"wiki_status\"}", legend = "wiki" }]
    },
    {
      title   = "Codigo HTTP de /status"
      unit    = "none"
      targets = [{ expr = "probe_http_status_code{job=\"wiki_status\"}", legend = "HTTP" }]
    },
    {
      title   = "MariaDB: consultas por segundo"
      unit    = "ops"
      targets = [{ expr = "rate(mysql_global_status_queries[1m])", legend = "consultas/s" }]
    },
    {
      title   = "MariaDB: conexiones abiertas"
      unit    = "none"
      targets = [{ expr = "mysql_global_status_threads_connected", legend = "conexiones" }]
    },
    {
      title = "Redis: comandos por segundo"
      unit  = "ops"

      targets = [
        { expr = "rate(redis_commands_processed_total[1m])", legend = "comandos/s" },
      ]
    },
    {
      title = "Redis: aciertos y fallos de cache"
      unit  = "ops"

      targets = [
        { expr = "rate(redis_keyspace_hits_total[1m])", legend = "aciertos" },
        { expr = "rate(redis_keyspace_misses_total[1m])", legend = "fallos" },
      ]
    },
    {
      title   = "Redis: memoria usada"
      unit    = "bytes"
      targets = [{ expr = "redis_memory_used_bytes", legend = "memoria" }]
    },
    {
      title   = "Redis: clientes conectados"
      unit    = "none"
      targets = [{ expr = "redis_connected_clients", legend = "clientes" }]
    },
    {
      title   = "CPU por contenedor (nucleos)"
      unit    = "short"
      targets = [{ expr = "sum by (name) (rate(container_cpu_usage_seconds_total{name=~\"${var.project_name}-.*\"}[1m]))", legend = "{{name}}" }]
    },
    {
      title   = "Memoria por contenedor"
      unit    = "bytes"
      targets = [{ expr = "container_memory_working_set_bytes{name=~\"${var.project_name}-.*\"}", legend = "{{name}}" }]
    },
  ]

  ts_panels = [for i, d in local.ts_defs : {
    id          = 10 + i
    type        = "timeseries"
    title       = d.title
    datasource  = local.ds
    gridPos     = { h = 8, w = 12, x = (i % 2) * 12, y = 5 + floor(i / 2) * 8 }
    targets     = [for k, t in d.targets : { refId = substr("ABCDEF", k, 1), expr = t.expr, legendFormat = t.legend, datasource = local.ds }]
    fieldConfig = { defaults = { unit = d.unit }, overrides = [] }
    options     = { legend = { displayMode = "list", placement = "bottom" }, tooltip = { mode = "multi" } }
  }]

  grafana_dashboard = {
    uid           = "itm-wiki"
    title         = "ITM Wiki - Observabilidad"
    tags          = ["itm", "wiki", "bookstack"]
    timezone      = "browser"
    schemaVersion = 39
    version       = 1
    refresh       = "10s"
    time          = { from = "now-15m", to = "now" }
    panels        = flatten([local.stat_panels, [local.alerts_panel], local.ts_panels])
  }
}
