# -----------------------------------------------------------------------------
# Servicio contenerizado: BookStack (wiki / base de conocimiento).
# Terraform construye la imagen desde ../app y la vuelve a construir solo
# cuando cambia algun archivo de esa carpeta.
# -----------------------------------------------------------------------------

resource "docker_image" "bookstack" {
  name         = "${local.prefix}/bookstack:${var.git_sha}"
  keep_locally = false

  build {
    context = local.app_dir

    build_args = {
      BOOKSTACK_TAG = var.bookstack_tag
      GIT_SHA       = var.git_sha
      BUILD_DATE    = "terraform"
    }
  }

  triggers = {
    app_hash = local.app_hash
  }
}

resource "docker_container" "bookstack" {
  name    = "${local.prefix}-bookstack"
  image   = docker_image.bookstack.image_id
  restart = "unless-stopped"
  memory  = 768

  env = [
    "PUID=1000",
    "PGID=1000",
    "TZ=${var.timezone}",
    "APP_URL=http://localhost:${var.ports.wiki}",
    "APP_KEY=base64:${random_id.app_key.b64_std}",
    "APP_LANG=es",
    "DB_HOST=mariadb",
    "DB_PORT=3306",
    "DB_DATABASE=bookstack",
    "DB_USERNAME=bookstack",
    "DB_PASSWORD=${random_password.db.result}",
    "REDIS_SERVERS=redis:6379:0:${random_password.redis.result}",
  ]

  networks_advanced {
    name    = docker_network.wiki.name
    aliases = ["bookstack"]
  }

  ports {
    internal = 80
    external = var.ports.wiki
    ip       = var.bind_ip
  }

  volumes {
    volume_name    = docker_volume.bookstack.name
    container_path = "/config"
  }

  # /status responde 200 solo si base de datos, cache y sesion funcionan.
  healthcheck {
    test         = ["CMD-SHELL", "curl -fsS http://localhost/status > /dev/null || exit 1"]
    interval     = "15s"
    timeout      = "10s"
    retries      = 20
    start_period = "60s"
  }

  wait         = true
  wait_timeout = 420

  labels {
    label = "project"
    value = var.project_name
  }

  depends_on = [
    docker_container.mariadb,
    docker_container.redis,
  ]
}
