#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="${VERSION_FILE:-${ROOT_DIR}/VERSION}"
REQUESTED_VERSION=""
IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-hejd}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
IMAGES=(teamtalk teamtalkpro)

usage() {
  cat <<'EOF'
Usage:
  ./build.sh [version]
  ./build.sh --version v5.23
  ./build.sh v5.23 --platforms linux/arm64
  ./build.sh v5.23 --image teamtalkpro

Builds and pushes both images by default, including their latest tags.
Use --image teamtalk or --image teamtalkpro to publish only one image.
A failure in one image does not stop the other image from being published.

Environment overrides:
  VERSION=v5.23 IMAGE_NAMESPACE=hejd PLATFORMS=linux/amd64,linux/arm64 ./build.sh
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--version)
      [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || { echo "Missing value for $1" >&2; exit 2; }
      [[ -z "${REQUESTED_VERSION}" ]] || { echo "Version was provided more than once" >&2; exit 2; }
      REQUESTED_VERSION="$2"
      shift 2
      ;;
    --platforms)
      [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || { echo "Missing value for $1" >&2; exit 2; }
      PLATFORMS="$2"
      shift 2
      ;;
    --namespace)
      [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || { echo "Missing value for $1" >&2; exit 2; }
      IMAGE_NAMESPACE="$2"
      shift 2
      ;;
    --image)
      [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 2; }
      case "$2" in
        teamtalk|teamtalkpro) IMAGES=("$2") ;;
        *) echo "--image must be teamtalk or teamtalkpro" >&2; exit 2 ;;
      esac
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      [[ -n "$1" ]] || { echo "Version cannot be empty" >&2; exit 2; }
      if [[ -n "${REQUESTED_VERSION}" ]]; then
        echo "Version was provided more than once" >&2
        exit 2
      fi
      REQUESTED_VERSION="$1"
      shift
      ;;
  esac
done

VERSION="${REQUESTED_VERSION:-${VERSION:-${VER:-}}}"

if [[ -z "${VERSION:-}" ]]; then
  [[ -f "${VERSION_FILE}" ]] || { echo "Missing version. Pass one or create ${VERSION_FILE}" >&2; exit 2; }
  VERSION="$(tr -d '[:space:]' < "${VERSION_FILE}")"
fi

[[ -n "${VERSION}" ]] || { echo "Version cannot be empty" >&2; exit 2; }

case "${VERSION}" in
  v*)
    ;;
  V*)
    VERSION="v${VERSION#V}"
    ;;
  *)
    VERSION="v${VERSION}"
    ;;
esac

[[ "${VERSION}" != "v" ]] || { echo "Version cannot be empty" >&2; exit 2; }

build_and_push() {
  local name="$1"
  local context="$2"
  local image="${IMAGE_NAMESPACE}/${name}"

  docker buildx build \
    --pull \
    --platform "${PLATFORMS}" \
    --build-arg "VERSION=${VERSION}" \
    -t "${image}:latest" \
    -t "${image}:${VERSION}" \
    --push \
    "${context}"
}

status=0
for name in "${IMAGES[@]}"; do
  echo "Building and pushing ${IMAGE_NAMESPACE}/${name}:${VERSION}"
  if build_and_push "${name}" "${ROOT_DIR}/${name}"; then
    echo "Published ${IMAGE_NAMESPACE}/${name}:${VERSION} and :latest"
  else
    echo "Failed to publish ${IMAGE_NAMESPACE}/${name}:${VERSION}" >&2
    printf 'Retry: bash %q %q --image %q --namespace %q --platforms %q\n' \
      "${ROOT_DIR}/build.sh" "${VERSION}" "${name}" "${IMAGE_NAMESPACE}" "${PLATFORMS}" >&2
    status=1
  fi
done
exit "${status}"
