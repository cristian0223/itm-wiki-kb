terraform {
  required_version = ">= 1.6.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Se conecta al Docker local: el socket de Linux en el runner de GitHub Actions
# o Docker Desktop en Windows/macOS. No hay ninguna nube involucrada: costo cero.
provider "docker" {}
