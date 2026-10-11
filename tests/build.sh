#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -f -- "${TEST_DIR}/calls" "${TEST_DIR}/output"; rmdir -- "${TEST_DIR}"' EXIT
trap 'printf "Build check failed at line %s\n" "${LINENO}" >&2' ERR
export TEST_CALLS="${TEST_DIR}/calls"
unset VERSION VER VERSION_FILE IMAGE_NAMESPACE PLATFORMS FAIL_IMAGE

# Replace Docker only in this test process; no images are built or published.
docker() {
  printf '%s\n' "$*" >> "${TEST_CALLS}"
  [[ "${*: -1}" != */"${FAIL_IMAGE:-none}" ]]
}
export -f docker

expect_status() {
  local expected="$1" actual=0
  shift
  : > "${TEST_CALLS}"
  bash "${ROOT_DIR}/build.sh" "$@" > "${TEST_DIR}/output" 2>&1 || actual=$?
  if [[ "${actual}" != "${expected}" ]]; then
    cat "${TEST_DIR}/output" >&2
    printf 'Expected exit %s, got %s for: %s\n' "${expected}" "${actual}" "$*" >&2
    exit 1
  fi
}

expect_status 2 v5.23 --version v5.24
test ! -s "${TEST_CALLS}"
expect_status 2 --version v5.23 v5.24
test ! -s "${TEST_CALLS}"
expect_status 2 --version ''
test ! -s "${TEST_CALLS}"
expect_status 2 --platforms --namespace example
test ! -s "${TEST_CALLS}"
expect_status 2 --image invalid
test ! -s "${TEST_CALLS}"

expect_status 0
test "$(wc -l < "${TEST_CALLS}")" -eq 2
grep -Fq -- "--build-arg VERSION=$(tr -d '[:space:]' < "${ROOT_DIR}/VERSION")" "${TEST_CALLS}"

expect_status 0 5.23 --image teamtalkpro --namespace example --platforms linux/arm64
test "$(wc -l < "${TEST_CALLS}")" -eq 1
grep -Fq -- '--platform linux/arm64 --build-arg VERSION=v5.23 -t example/teamtalkpro:latest -t example/teamtalkpro:v5.23 --push' "${TEST_CALLS}"

export FAIL_IMAGE=teamtalk
expect_status 1 v5.23
test "$(wc -l < "${TEST_CALLS}")" -eq 2
grep -Fq 'Published hejd/teamtalkpro:v5.23' "${TEST_DIR}/output"
grep -Fq -- '--image teamtalk --namespace' "${TEST_DIR}/output"

export FAIL_IMAGE=teamtalkpro
expect_status 1 v5.23
test "$(wc -l < "${TEST_CALLS}")" -eq 2
grep -Fq 'Published hejd/teamtalk:v5.23' "${TEST_DIR}/output"
grep -Fq -- '--image teamtalkpro --namespace' "${TEST_DIR}/output"

expect_status 1 v5.23 --image teamtalkpro
test "$(wc -l < "${TEST_CALLS}")" -eq 1
printf 'Build script regression checks passed.\n'
