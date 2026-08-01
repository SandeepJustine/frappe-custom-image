// docker-bake.hcl
//
// This bake file does NOT fork or duplicate frappe/frappe_docker.
// It points docker buildx at the official frappe_docker repository as a
// remote git build context and reuses their production-grade
// "layered" Containerfile (images/layered/Containerfile), which is the
// same file the Frappe team uses to publish official images.
//
// Your repo only owns: apps.json, this bake file, and the CI workflow.
// Bumping Frappe/ERPNext versions or adding apps never requires touching
// the Containerfile itself.

variable "REGISTRY" {
  default = "ghcr.io"
}

// GHCR namespace, e.g. "josephsandeep" or "cool-enterprises"
// Overridden by CI from `github.repository_owner`.
variable "REGISTRY_NAMESPACE" {
  default = "sandeepjustine"
}

variable "IMAGE_NAME" {
  default = "erpnext-custom"
}

// Pin this to a specific commit SHA of frappe_docker in real production
// use for full reproducibility. "main" is fine for iteration.
variable "FRAPPE_DOCKER_REPO" {
  default = "https://github.com/frappe/frappe_docker.git"
}

variable "FRAPPE_DOCKER_REF" {
  default = "v16.23.1"
}

variable "FRAPPE_PATH" {
  default = "https://github.com/frappe/frappe"
}

variable "FRAPPE_BRANCH" {
  default = "version-16"
}

// Keep in sync with the versions frappe_docker's CI uses for the
// FRAPPE_BRANCH above. See frappe_docker's resources/*.json or its own
// bake file for the currently supported combination.
variable "PYTHON_VERSION" {
  default = "3.11.9"
}

variable "NODE_VERSION" {
  default = "20.19.2"
}

// Base64-encoded contents of apps.json. Populated by CI
// (`APPS_JSON_BASE64=$(base64 -w 0 apps.json)`); never committed as
// plaintext build state.
variable "APPS_JSON_BASE64" {
  default = ""
}

// Primary version tag for this build, e.g. "v16-2026.08.01-abc1234"
// or a semantic tag such as "v1.3.0". Supplied by CI.
variable "TAG" {
  default = "dev"
}

// Whether to also push :latest alongside TAG. CI sets this to "true"
// only on builds from the default branch.
variable "PUSH_LATEST" {
  default = "false"
}

function "tags" {
  params = []
  result = PUSH_LATEST == "true" ? [
    "${REGISTRY}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${TAG}",
    "${REGISTRY}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:latest",
    ] : [
    "${REGISTRY}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${TAG}",
  ]
}

group "default" {
  targets = ["custom-apps"]
}

target "custom-apps" {
  // Remote git context: "<repo>#<ref>" — buildx clones this directly,
  // so no submodule and no local checkout of frappe_docker is needed.
  context    = "${FRAPPE_DOCKER_REPO}#${FRAPPE_DOCKER_REF}"
  dockerfile = "images/custom/Containerfile"

  args = {
    FRAPPE_PATH      = FRAPPE_PATH
    FRAPPE_BRANCH    = FRAPPE_BRANCH
    PYTHON_VERSION   = PYTHON_VERSION
    NODE_VERSION     = NODE_VERSION
    APPS_JSON_BASE64 = APPS_JSON_BASE64
  }

  tags      = tags()
  platforms = ["linux/amd64"]

  // GitHub Actions cache backend. Subsequent builds reuse layers for
  // the base OS, Python/Node toolchains, and unchanged app sources —
  // only apps whose branch actually moved get rebuilt.
  cache-from = ["type=gha,scope=${IMAGE_NAME}"]
  cache-to   = ["type=gha,mode=max,scope=${IMAGE_NAME}"]

  labels = {
    "org.opencontainers.image.source"      = "https://github.com/${REGISTRY_NAMESPACE}/${IMAGE_NAME}"
    "org.opencontainers.image.description" = "Custom Frappe/ERPNext image built from frappe_docker's layered Containerfile"
    "org.opencontainers.image.licenses"    = "MIT"
  }
}
