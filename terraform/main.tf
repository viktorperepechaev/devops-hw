terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "4.6.0"
    }
  }
}

provider "docker" {
  host = "ssh://deployer@111.88.162.127:22"

  ssh_opts = [
    "-i", pathexpand("~/.ssh/devops_hw_ed25519"),
    "-o", "BatchMode=yes"
  ]
}

variable "nginx_port" {
  description = "HTTP port on the VM"
  type        = number
  default     = 8081
}

resource "docker_network" "nginx" {
  name   = "tf-network"
  driver = "bridge"
}

resource "docker_volume" "nginx_data" {
  name = "tf-nginx-data"
}

resource "docker_image" "nginx" {
  name         = "nginx:1.30.5-alpine"
  platform     = "linux/amd64"
  keep_locally = true
}

resource "docker_container" "nginx" {
  name    = "tf-nginx"
  image   = docker_image.nginx.image_id
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.nginx.name
  }

  volumes {
    volume_name    = docker_volume.nginx_data.name
    container_path = "/usr/share/nginx/html"
    read_only      = true
  }

  ports {
    internal = 80
    external = var.nginx_port
  }
}
