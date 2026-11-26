variable "project_name" {
  description = "Prefijo de todos los recursos (contenedores, red y volumenes)."
  type        = string
  default     = "itm-wiki"
}

variable "alert_email" {
  description = "Destinatario de las alertas de Alertmanager (se entregan en Mailpit, el buzon local)."
  type        = string
  default     = "erianserna1114297@correo.itm.edu.co"
}

variable "timezone" {
  description = "Zona horaria de los contenedores."
  type        = string
  default     = "America/Bogota"
}

variable "git_sha" {
  description = "Commit que se despliega; queda visible en /build-info.json."
  type        = string
  default     = "local"
}

variable "bookstack_tag" {
  description = "Etiqueta de la imagen base lscr.io/linuxserver/bookstack."
  type        = string
  default     = "latest"
}

variable "bind_ip" {
  description = "IP del equipo donde se publican los puertos. 127.0.0.1 = solo accesible desde el propio equipo."
  type        = string
  default     = "127.0.0.1"
}

variable "ports" {
  description = "Puertos publicados en el equipo."

  type = object({
    wiki         = number
    grafana      = number
    prometheus   = number
    alertmanager = number
    mailpit      = number
  })

  default = {
    wiki         = 6875
    grafana      = 3000
    prometheus   = 9090
    alertmanager = 9093
    mailpit      = 8025
  }
}

variable "enable_cadvisor" {
  description = "Despliega cAdvisor para metricas de CPU y memoria por contenedor."
  type        = bool
  default     = true
}
