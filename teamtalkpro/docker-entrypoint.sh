#!/bin/sh
set -eu

if [ "$#" -eq 0 ]; then
    set -- "${TEAMTALK_BINARY}" -nd -wd "${TEAMTALK_CONFIG_DIR}" -verbose
elif [ "${1#-}" != "$1" ]; then
    set -- "${TEAMTALK_BINARY}" "$@"
fi

if [ "$(id -u)" = "0" ] && { [ "$1" = "${TEAMTALK_BINARY}" ] || [ "$1" = "${TEAMTALK_BINARY##*/}" ]; }; then
    run_uid="${uid:-0}"
    run_gid="${gid:-${run_uid}}"
    chown_mode="${chown:-auto}"

    case "${run_uid}" in
        ''|*[!0-9]*) echo "uid must be numeric" >&2; exit 1 ;;
    esac
    case "${run_gid}" in
        ''|*[!0-9]*) echo "gid must be numeric" >&2; exit 1 ;;
    esac

    mkdir -p "${TEAMTALK_CONFIG_DIR}"

    case "${chown_mode}" in
        1|true|TRUE|yes|YES|always|ALWAYS)
            chown -R "${run_uid}:${run_gid}" "${TEAMTALK_CONFIG_DIR}"
            ;;
        auto|AUTO)
            if [ "${run_uid}" != "0" ] || [ "${run_gid}" != "0" ]; then
                chown -R "${run_uid}:${run_gid}" "${TEAMTALK_CONFIG_DIR}"
            fi
            ;;
        0|false|FALSE|no|NO|never|NEVER)
            ;;
        *) echo "chown must be auto, true, or false" >&2; exit 1 ;;
    esac

    if [ "${run_uid}" = "0" ] && [ "${run_gid}" = "0" ]; then
        exec "$@"
    fi

    exec gosu "${run_uid}:${run_gid}" "$@"
fi

exec "$@"
