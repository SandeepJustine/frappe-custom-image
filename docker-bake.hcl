variable "REGISTRY" {
  default = "ghcr.io"
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


target "custom-apps" {

  context = "https://github.com/frappe/frappe_docker.git#main"

  dockerfile = "images/custom/Containerfile"

  args = {
    FRAPPE_BRANCH = FRAPPE_BRANCH
    CACHE_BUST = "1"
  }

  tags = [
    "${REGISTRY}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${TAG}"
  ]

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