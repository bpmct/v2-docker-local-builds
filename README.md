---
name: Develop in Docker with custom image builds
description: Builds images on the Docker host, no registry required
tags: [local, docker]
---

# docker-image-builds

This example bundles Dockerfiles in the Coder template, allowing the Docker host to build images itself
instead of relying on an external registry.

For large use cases, we recommend building images using CI/CD pipelines and registries instead of at workspace "runtime." However, this example is practical for tinkering and iterating on Dockerfiles.

## Getting started

Select this template in `coder templates init` and follow instructions. 

## Adding images

Create a Dockerfile (e.g `images/golang.Dockerfile`)

```sh
vim images/golang.Dockerfile
```

```Dockerfile
# Start from base image (built on Docker host)
FROM coder-base:latest

# Install everything as root
USER root

# Install go
RUN curl -L "https://dl.google.com/go/go1.17.1.linux-amd64.tar.gz" | tar -C /usr/local -xzvf -

# Setup go env vars
ENV GOROOT /usr/local/go
ENV PATH $PATH:$GOROOT/bin

ENV GOPATH /home/coder/go
ENV GOBIN $GOPATH/bin
ENV PATH $PATH:$GOBIN

# Set back to coder user
USER coder
```

Edit the template Terraform (`main.tf`)

```sh
vim main.tf
```

Edit the validation to include the new image:

```diff
variable "docker_image" {
    description = "What docker image would you like to use for your workspace?"
    default     = "base"

    # List of images available for the user to choose from.
    # Delete this condition to give users free text input.
    validation {
-       condition     = contains(["base", "java", "node"], var.docker_image)
+       condition     = contains(["base", "java", "node", "golang], var.docker_image)
        error_message = "Invalid Docker Image!"
    }
}
```

Bump the image tag to a new version:

```diff
resource "docker_image" "coder_image" {
    name = "coder-base-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}"
    build {
        path       = "./images/"
        dockerfile = "${var.docker_image}.Dockerfile"
-        tag        = ["coder-${var.docker_image}:v0.1"]
+        tag        = ["coder-${var.docker_image}:v0.2"]
    }

    # Keep alive for other workspaces to use upon deletion
    keep_locally = true
}
```

Update the template:

```sh
coder template update docker-image-builds
```

## Updating images

Edit the Dockerfile (or related assets)

```sh
vim images/node.Dockerfile
```

```diff
# Install Node
- RUN curl -sL https://deb.nodesource.com/setup_14.x | bash -
+ RUN curl -sL https://deb.nodesource.com/setup_16.x | bash -
RUN DEBIAN_FRONTEND="noninteractive" apt-get update -y && \
    apt-get install -y nodejs
```

1. Edit the template Terraform (`main.tf`)

```sh
vim main.tf
```

Bump the image tag to a new version:

```diff
resource "docker_image" "coder_image" {
    name = "coder-base-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}"
    build {
        path       = "./images/"
        dockerfile = "${var.docker_image}.Dockerfile"
-        tag        = ["coder-${var.docker_image}:v0.1"]
+        tag        = ["coder-${var.docker_image}:v0.2"]
    }

    # Keep alive for other workspaces to use upon deletion
    keep_locally = true
}
```

Update the template:

```sh
coder template update docker-image-builds
```

Optional: Update workspaces to the latest template version

```sh
coder ls
coder update [workspace name]
```
