# syntax=docker/dockerfile:1
#
ARG IMAGEBASE=frommakefile
#
FROM ${IMAGEBASE}
#
ARG REPO=https://github.com/louislam/uptime-kuma
ARG VERSION
#
ENV \
    HOME=/home/${S6_USER:-alpine} \
    DATADIR=/home/${S6_USER:-alpine}/project/data \
    PROJECTDIR=/home/${S6_USER:-alpine}/project \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=1 \
    UPTIME_KUMA_IS_CONTAINER=1 \
    UPTIME_KUMA_DISABLE_FRAME_SAMEORIGIN=false \
    UPTIME_KUMA_HOST=0.0.0.0 \
    UPTIME_KUMA_PORT=3001
    # UPTIME_KUMA_SSL_KEY=
    # UPTIME_KUMA_SSL_CERT=
#
RUN set -xe \
    && apk add --no-cache --purge -uU \
        # --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing \
        curl \
        iputils \
        musl-nscd \
        py3-click \
        py3-certifi \
        # py3-cryptography \
        py3-markdown \
        py3-pip \
        py3-requests \
        py3-requests-oauthlib \
        # py3-six \
        py3-yaml \
        python3 \
        setpriv \
        sudo \
    && pip install --no-cache-dir --break-system-packages \
        apprise \
        paho-mqtt \
    && mkdir -p \
        "${PROJECTDIR}" \
        "${DATADIR}" \
    && curl -SL "${REPO}/archive/refs/tags/${VERSION}.tar.gz" \
        | tar -xvz --strip 1 -C "${PROJECTDIR}" \
    # nscd does not seem to work under AlpineLinux
    && mv "${PROJECTDIR}/docker/etc/nscd.conf" /etc/nscd.conf \
    && mv "${PROJECTDIR}/docker/etc/sudoers" /etc/sudoers \
    && chown -R \
        ${S6_USER:-alpine}:${PGID:-1000} \
        "${PROJECTDIR}" \
    && cd "${PROJECTDIR}" \
    && s6-setuidgid ${S6_USER:-alpine} npm ci \
        --fetch-retries=5 \
        --no-audit \
        --no-fund \
        --no-update-notifier \
        --omit=dev \
        --production \
    && s6-setuidgid ${S6_USER:-alpine} \
        npm run download-dist \
    && s6-setuidgid ${S6_USER:-alpine} \
        npm cache clear --force \
    && rm -rf /var/cache/apk/* /tmp/* \
        /root/.cache /root/.npm \
        ${HOME}/.cache ${HOME}/.npm
#
COPY root/ /
#
VOLUME ${DATADIR}
#
EXPOSE ${UPTIME_KUMA_PORT}
#
HEALTHCHECK \
    --interval=2m \
    --timeout=30s \
    --start-period=5m \
    --retries=5 \
    CMD node ./extra/healthcheck.js
#
ENTRYPOINT ["/init"]
