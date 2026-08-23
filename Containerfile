ARG MOONSHINE_SWAY_WEB_VERSION=latest
FROM ghcr.io/bbusse/moonshine-sway-web:${MOONSHINE_SWAY_WEB_VERSION}
LABEL maintainer="Björn Busse <bj.rn@baerlin.eu>"
LABEL org.opencontainers.image.source=https://github.com/bbusse/swayvnc-firefox

ARG SCREAM_VERSION=v0-rc3
ARG VJU_VERSION=v1-rc5
ARG VJU_PKGVER=1_rc5-r0

# Firefox, geckodriver and fonts come from moonshine-sway-web
# Only what the controller itself needs is added here
ENV USER="swayvnc" \
    APK_ADD="sed \
             curl \
             python3 \
             grim \
             wayland-protocols \
             wayland-dev" \
    APK_DEL="" \
    PATH_VENV="/venv" \
    PATH="${PATH_VENV}/bin:${PATH}"

USER root

COPY keys/apk-releases.rsa.pub /etc/apk/keys/apk-releases.rsa.pub

# Add application
# Cleanup: Remove files
RUN apk add --no-cache ${APK_ADD} \
    && apk del --no-cache ${APK_DEL} \
    # Install scream from its GitHub release apk, verified against
    # keys/apk-releases.rsa.pub (copied in above)
    && curl -sL -o /tmp/scream.apk "https://github.com/bbusse/scream/releases/download/${SCREAM_VERSION}/scream-0.1.0-r0.$(apk --print-arch)-${SCREAM_VERSION}.apk" \
    && apk add --no-cache /tmp/scream.apk \
    && rm /tmp/scream.apk \
    # Install vju from its GitHub release apk, verified against the same
    # key as scream (copied in above)
    && curl -sL -o /tmp/vju.apk "https://github.com/bbusse/vju/releases/download/${VJU_VERSION}/vju-${VJU_PKGVER}.$(apk --print-arch)-${VJU_VERSION}.apk" \
    && apk add --no-cache /tmp/vju.apk \
    && rm /tmp/vju.apk \
    # Cleanup: Remove files
    && rm -rf \
      /usr/share/man/* \
      /usr/includes/* \
      /var/cache/apk/* \
\
    # Configure controller.py startup
    && echo "exec /bin/sh -c 'source ${PATH_VENV}/bin/activate && python3 /usr/local/bin/controller.py --stream-source=vnc-browser --loglevel=DEBUG'" \
    > /etc/sway/config.d/controller \
\
    # Set bg with vju
    && echo "exec /bin/sh -c 'WAYLAND_DISPLAY=/tmp/wayland-1 /usr/bin/vju --fullscreen --center-text --watch 1s date'" \
    > /etc/sway/config.d/vju-bg \
\
    # Start rtsp stream with scream
    && echo "exec /bin/sh -c 'WAYLAND_DISPLAY=/tmp/wayland-1 /usr/bin/scream'" \
    > /etc/sway/config.d/scream

USER root
# Copy controller virtual environment from external image
COPY --from=iss-display-controller:latest /venv "${PATH_VENV}"
COPY --from=iss-display-controller:latest /controller/controller.py /usr/local/bin/controller.py
# Copy controller
COPY controller.py /usr/local/bin
# Copy swlc
COPY swlc /usr/local/bin

COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
