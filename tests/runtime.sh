#!/usr/bin/env bash
set -euo pipefail
trap 'printf "Runtime check failed at line %s\n" "${LINENO}" >&2' ERR

IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-tt-docker-validation}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-$(tr -d '[:space:]' < "${ROOT_DIR}/VERSION")}"
# Git Bash must pass Linux paths to Docker without converting them to Windows paths.
export MSYS_NO_PATHCONV=1

for platform in linux/amd64 linux/arm64; do
  for name in teamtalk teamtalkpro; do
    image="${IMAGE_NAMESPACE}/${name}:${VERSION}"
    output="$(docker run --rm --platform "${platform}" --network none \
      --tmpfs /etc/teamtalk \
      -e TEAMTALK_BINARY=/bin/echo \
      -e uid=10001 -e gid=10002 "${image}")"
    [[ "${output}" == '-nd -wd /etc/teamtalk -verbose' ]]

    output="$(docker run --rm --platform "${platform}" --network none \
      --tmpfs /etc/teamtalk \
      -e TEAMTALK_BINARY=/bin/pwd \
      -e uid=10001 -e gid=10002 "${image}" -P)"
    [[ "${output}" == /etc/teamtalk ]]

    output="$(docker run --rm --platform "${platform}" --network none \
      --tmpfs /etc/teamtalk --user 10001:10002 \
      -e TEAMTALK_BINARY=/bin/pwd "${image}" -P)"
    [[ "${output}" == /etc/teamtalk ]]

    output="$(docker run --rm --platform "${platform}" --network none \
      --tmpfs /etc/teamtalk -e TEAMTALK_BINARY=/usr/bin/id \
      -e uid=10001 -e gid=10002 "${image}" -u)"
    [[ "${output}" == 10001 ]]

    docker run --rm --platform "${platform}" --network none \
      --tmpfs /etc/teamtalk "${image}" sh -ec '
        deps=$(ldd "$TEAMTALK_BINARY")
        case "$deps" in *"not found"*) echo "$deps"; exit 1 ;; esac
        version=$("$TEAMTALK_BINARY" --version) || test "$?" = 1
        case "$version" in *"version ${TEAMTALK_VERSION#v}."*) ;; *) exit 1 ;; esac
      '

    answers=(y '中文测试服务器' '测试公告' 10 y y /etc/teamtalk/files 1024 10240 y 10333 10333 n n)
    quit_option=4
    if [[ "${name}" == teamtalkpro ]]; then
      answers+=(n)
      quit_option=5
    fi
    answers+=(2 regression ephemeral-test 2 "${quit_option}" 0 0 0 y)
    printf '%s\n' "${answers[@]}" | docker run --rm -i --platform "${platform}" --network none \
      --tmpfs /etc/teamtalk \
      -e uid=10001 -e gid=10002 "${image}" sh -ec '
        mkdir /etc/teamtalk/files
        timeout 5s /usr/local/bin/docker-entrypoint.sh -wizard | head -c 16000 > /tmp/wizard-output
        grep -q "Changes saved" /tmp/wizard-output
        if grep -q "UTF-8 not enabled" /tmp/wizard-output; then
          echo "Wizard has no UTF-8 locale" >&2
          exit 1
        fi
        config="/etc/teamtalk/${TEAMTALK_BINARY##*/}.xml"
        grep -q "<server-name>中文测试服务器</server-name>" "$config"
        grep -q "<username>regression</username>" "$config"
        grep -q "<files-root>/etc/teamtalk/files</files-root>" "$config"
        test "$(stat -c %u:%g "$config")" = 10001:10002
      '
  done

  container="$(docker run --detach --platform "${platform}" --network none \
    --tmpfs /etc/teamtalk \
    -e uid=10001 -e gid=10002 \
    "${IMAGE_NAMESPACE}/teamtalk:${VERSION}")"
  trap 'docker rm --force "${container}" > /dev/null' EXIT
  started=false
  for _attempt in {1..30}; do
    if docker logs "${container}" 2>&1 | grep -q 'Started TeamTalk Server'; then
      started=true
      break
    fi
    sleep 0.2
  done
  [[ "${started}" == true ]]
  docker exec "${container}" sh -ec '
    test -f /etc/teamtalk/tt5srv.xml
    test "$(stat -c %u:%g /etc/teamtalk/tt5srv.xml)" = 10001:10002
  '
  docker stop --time 5 "${container}" > /dev/null
  docker logs "${container}" 2>&1 | grep -q 'Stopped TeamTalk Server'
  [[ "$(docker inspect --format '{{.State.ExitCode}}' "${container}")" == 0 ]]
  docker rm "${container}" > /dev/null
  trap - EXIT
done
printf 'Runtime regression checks passed for both images and architectures.\n'
