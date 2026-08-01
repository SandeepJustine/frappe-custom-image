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

variable "DOCKER_METADATA_OUTPUT_TAGS" {
  default = ""
}

variable "FRAPPE_BRANCH" {
  default = "version-16"
}

variable "APPS_JSON_BASE64" {
  default = ""
}

target "custom-apps" {

  context = "https://github.com/frappe/frappe_docker.git#main"

  dockerfile = "images/custom/Containerfile"

  args = {
    FRAPPE_BRANCH = FRAPPE_BRANCH
    APPS_JSON_BASE64 = APPS_JSON_BASE64
  }

  tags = split(",", DOCKER_METADATA_OUTPUT_TAGS)

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
