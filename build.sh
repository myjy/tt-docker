#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="${VERSION_FILE:-${ROOT_DIR}/VERSION}"
REQUESTED_VERSION=""
IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-hejd}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

usage() {
  cat <<'EOF'
Usage:
  ./build.sh [version]
  ./build.sh --version v5.21
  ./build.sh v5.21 --platforms linux/arm64

Environment overrides:
  VERSION=v5.21 IMAGE_NAMESPACE=hejd PLATFORMS=linux/amd64,linux/arm64 ./build.sh
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--version)
      [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 2; }
      REQUESTED_VERSION="$2"
      shift 2
      ;;
    --platforms)
      [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 2; }
      PLATFORMS="$2"
      shift 2
      ;;
    --namespace)
      [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 2; }
      IMAGE_NAMESPACE="$2"
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

build_and_push teamtalk "${ROOT_DIR}/teamtalk"
build_and_push teamtalkpro "${ROOT_DIR}/teamtalkpro"
