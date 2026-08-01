variable "FRAPPE_BRANCH" {
  default = "version-16"
}

variable "APPS_JSON_BASE64" {
  default = ""
}

variable "TAGS" {
  default = ""
}

target "custom-apps" {
  context = "https://github.com/frappe/frappe_docker.git#main"
  dockerfile = "images/custom/Containerfile"
  
  args = {
    FRAPPE_BRANCH = FRAPPE_BRANCH
    APPS_JSON_BASE64 = APPS_JSON_BASE64
  }
  
  tags = TAGS != "" ? split(",", TAGS) : ["ghcr.io/sandeepjustine/erpnext-custom:latest"]
  
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