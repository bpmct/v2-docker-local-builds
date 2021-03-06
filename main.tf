terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.4.1"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.16.0"
    }
  }
}

# Admin parameters
variable "arch" {
  description = "arch: What archicture is your Docker host on?"
  validation {
    condition     = contains(["amd64", "arm64", "armv7"], var.arch)
    error_message = "Value must be amd64, arm64 or armv7."
  }
  sensitive = true
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

data "coder_workspace" "me" {
}

resource "coder_agent" "dev" {
  arch = var.arch
  os   = "linux"
}

variable "docker_image" {
  description = "What docker image would you like to use for your workspace?"
  default     = "base"

  # List of images available for the user to choose from.
  # Delete this condition to give users free text input.
  validation {
    condition     = contains(["base", "java", "node"], var.docker_image)
    error_message = "Invalid Docker Image!"
  }

  # Prevents admin errors when the image is not found
  validation {
    condition     = fileexists("images/${var.docker_image}.Dockerfile")
    error_message = "Invalid docker image. The file does not exist in the images directory."
  }
}

resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}-root"
}

resource "docker_image" "coder_image" {
  name = "coder-base-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}"
  build {
    path       = "./images/"
    dockerfile = "${var.docker_image}.Dockerfile"
    tag        = ["coder-${var.docker_image}:v0.1"]
  }

  # Keep alive for other workspaces to use upon deletion
  keep_locally = true
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = docker_image.coder_image.latest
  # Uses lower() to avoid Docker restriction on container names.
  name = "coder-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}"
  # Hostname makes the shell more user friendly: coder@base:~$
  hostname = lower(data.coder_workspace.me.name)
  dns      = ["1.1.1.1"]
  command  = ["sh", "-c", coder_agent.dev.init_script]
  env      = ["CODER_AGENT_TOKEN=${coder_agent.dev.token}"]
  volumes {
    container_path = "/home/coder/"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }
}
