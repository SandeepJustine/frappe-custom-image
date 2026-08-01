#!/usr/bin/env bash
# Build the custom image locally exactly the way CI does, for testing
# an apps.json change before pushing.
#
# Usage:
#   ./scripts/build-local.sh [tag] [frappe_branch]
#
# Example:
#   ./scripts/build-local.sh dev-test version-16

set -euo pipefail

cd "$(dirname "$0")/.."

TAG="${1:-dev-test}"
FRAPPE_BRANCH="${2:-version-16}"
REGISTRY_NAMESPACE="${REGISTRY_NAMESPACE:-local}"
IMAGE_NAME="${IMAGE_NAME:-erpnext-custom}"

if ! python3 -m json.tool apps.json > /dev/null; then
  echo "apps.json is not valid JSON" >&2
  exit 1
fi

APPS_JSON_BASE64="$(base64 -w 0 apps.json)"

export DOCKER_METADATA_OUTPUT_TAGS="${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${TAG}"

echo "Building ${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${TAG} (frappe branch: ${FRAPPE_BRANCH})"

docker buildx bake \
  --file docker-bake.hcl \
  --set custom-apps.args.APPS_JSON_BASE64="${APPS_JSON_BASE64}" \
  --set custom-apps.args.FRAPPE_BRANCH="${FRAPPE_BRANCH}" \
  --load \
  custom-apps

echo "Done. Image loaded locally as:"
echo "  ${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${TAG}"
echo
echo "Sanity check the apps that made it into the image:"
echo "  docker run --rm ${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${TAG} ls /home/frappe/frappe-bench/apps"
