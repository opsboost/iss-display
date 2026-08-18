ARG SWAYVNC_VERSION=latest
FROM ghcr.io/bbusse/swayvnc:${SWAYVNC_VERSION}
LABEL maintainer="Björn Busse <bj.rn@baerlin.eu>"
LABEL org.opencontainers.image.source=https://github.com/bbusse/swayvnc-firefox

ARG SCREAM_VERSION=v0-rc3

ENV USER="swayvnc" \
    APK_ADD="libxkbcommon \
             geckodriver@testing \
             grim \
             firefox \
             wayland-protocols" \
    APK_DEL="" \
    PATH_VENV="/venv" \
    PATH="${PATH_VENV}/bin:${PATH}" \
    GECKODRIVER="/usr/bin/geckodriver" \
    FIREFOX_BIN="/usr/bin/firefox"

USER root

COPY keys/apk-releases.rsa.pub /etc/apk/keys/apk-releases.rsa.pub

# Add application user and application
# Cleanup: Remove files and users
RUN addgroup -S $USER && adduser -S $USER -G $USER \
    && echo "@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
    # https://gitlab.alpinelinux.org/alpine/aports/-/issues/11768
    && sed -i -e 's/https/http/' /etc/apk/repositories \
    # Add packages
    && apk add --no-cache ${APK_ADD} \
    && apk del --no-cache ${APK_DEL} \
    # Install scream from its GitHub release apk, verified against
    # keys/apk-releases.rsa.pub (copied in above)
    && wget -O /tmp/scream.apk "https://github.com/bbusse/scream/releases/download/${SCREAM_VERSION}/scream-0.1.0-r0.$(apk --print-arch)-${SCREAM_VERSION}.apk" \
    && apk add --no-cache /tmp/scream.apk \
    && rm /tmp/scream.apk \
    # Cleanup: Remove files
    && rm -rf \
      /usr/share/man/* \
      /usr/includes/* \
      /var/cache/apk/* \

    # Configure controller.py startup
    && echo "exec /usr/bin/env sh -c 'PATH=/home/swayvnc/venv-controller/bin/:$PATH source ${PATH_VENV}/bin/activate && controller.py --stream-source=vnc-browser --loglevel=DEBUG'" \
    > /etc/sway/config.d/controller \

    # Start rtsp stream with scream
    && echo "exec /usr/bin/env sh -c 'WAYLAND_DISPLAY=/tmp/wayland-1 /usr/bin/scream'" \
    > /etc/sway/config.d/scream \

    # Disable Xwayland explicitly
    && echo "xwayland disable" > /etc/sway/config.d/xwayland

USER root
# Copy controller virtual environment from external image
COPY --from=ghcr.io/opsboost/iss-display-controller:latest /venv "${PATH_VENV}"
COPY --from=ghcr.io/opsboost/iss-display-controller:latest /controller/controller.py /usr/local/bin/controller.py
# Copy controller
COPY controller.py /usr/local/bin

COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
