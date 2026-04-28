FROM ubuntu:24.04

ARG TARGETARCH
ARG VERSION

ENV TZ=Asia/Shanghai \
    HOME=/etc/teamtalk \
    TEAMTALK_BINARY=/usr/local/bin/tt5srv \
    TEAMTALK_CONFIG_DIR=/etc/teamtalk \
    TEAMTALK_VERSION=${VERSION} \
    chown=auto

SHELL ["/bin/sh", "-eux", "-c"]

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN test -n "${VERSION:-}" || { echo "Build argument VERSION is required" >&2; exit 1; } \
    && case "${VERSION}" in \
        v*) ;; \
        *) echo "Build argument VERSION must include v prefix, e.g. v5.21" >&2; exit 1 ;; \
    esac \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        gosu \
        tzdata \
        wget \
    && chmod +x /usr/local/bin/docker-entrypoint.sh \
    && ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime \
    && echo "${TZ}" > /etc/timezone \
    && case "${TARGETARCH}" in \
        amd64) TT_PLATFORM="ubuntu24-x86_64" ;; \
        arm64) TT_PLATFORM="raspios12-arm64" ;; \
        *) echo "Unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && archive="teamtalk-${VERSION}-${TT_PLATFORM}.tgz" \
    && root="teamtalk-${VERSION}-${TT_PLATFORM}" \
    && wget -O "/tmp/${archive}" "https://bearware.dk/teamtalk/${VERSION}/${archive}" \
    && tar -xzf "/tmp/${archive}" -C /tmp \
    && install -m 0755 "/tmp/${root}/server/tt5srv" /usr/local/bin/tt5srv \
    && mkdir -p /etc/teamtalk \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /etc/teamtalk
VOLUME [ "/etc/teamtalk" ]
EXPOSE 10333/tcp 10333/udp

ENTRYPOINT [ "/usr/local/bin/docker-entrypoint.sh" ]
CMD [ "-nd", "-wd", "/etc/teamtalk", "-verbose" ]
