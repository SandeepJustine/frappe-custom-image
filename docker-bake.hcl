variable "REGISTRY" {
  default = "ghcr.io"
}

variable "FRAPPE_DOCKER_REPO" {
  default = "https://github.com/frappe/frappe_docker.git"
}

variable "FRAPPE_DOCKER_REF" {
  default = "main"
}

variable "REGISTRY_NAMESPACE" {
  default = "sandeepjustine"
}

variable "IMAGE_NAME" {
  default = "erpnext-custom"
}

variable "TAG" {
  default = "latest"
}

variable "FRAPPE_BRANCH" {
  default = "version-16"
}

group "default" {
  targets = ["custom-apps"]
}

target "custom-apps" {

  context    = "${FRAPPE_DOCKER_REPO}#${FRAPPE_DOCKER_REF}"
  dockerfile = "images/custom/Containerfile"

  tags = [
    "${REGISTRY}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${TAG}"
  ]

  args = {
    FRAPPE_BRANCH = FRAPPE_BRANCH
  }

  platforms = [
    "linux/amd64"
  ]

  cache-from = [
    "type=gha"
  ]

  cache-to = [
    "type=gha,mode=max"
  ]
}