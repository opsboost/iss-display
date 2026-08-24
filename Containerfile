ARG MOONSHINE_SWAY_WEB_VERSION=latest
FROM ghcr.io/bbusse/moonshine-sway-web:${MOONSHINE_SWAY_WEB_VERSION}
LABEL maintainer="Björn Busse <bj.rn@baerlin.eu>"
LABEL org.opencontainers.image.source=https://github.com/bbusse/swayvnc-firefox

ARG VJU_VERSION=v1-rc5
ARG VJU_PKGVER=1_rc5-r0
ARG SERVO_VERSION=0.4.0_rc1
ARG SERVO_PKGREL=0

# The software mesa and fonts come from moonshine-sway-web
# Only what the controller itself needs is added here
ENV USER="swayvnc" \
    APK_ADD="sed \
             curl \
             python3 \
             grim \
             wayland-protocols \
             wayland-dev \
             gst-plugins-base \
             gst-plugins-good \
             gst-plugins-ugly \
             gst-rtsp-server" \
    APK_DEL="" \
    PATH_VENV="/venv" \
    PATH="${PATH_VENV}/bin:${PATH}"

USER root

COPY keys/apk-releases.rsa.pub /etc/apk/keys/apk-releases.rsa.pub

# Add application
# Cleanup: Remove files
RUN apk add --no-cache ${APK_ADD} \
    && apk del --no-cache ${APK_DEL} \
    # Install vju from its GitHub release apk, verified against
    # keys/apk-releases.rsa.pub (copied in above)
    && curl -sL -o /tmp/vju.apk "https://github.com/bbusse/vju/releases/download/${VJU_VERSION}/vju-${VJU_PKGVER}.$(apk --print-arch)-${VJU_VERSION}.apk" \
    && apk add --no-cache /tmp/vju.apk \
    && rm /tmp/vju.apk \
    # Install servoshell from its GitHub release apk, verified against the same
    # key as scream (copied in above)
    # Built with !tracedeps, so its shared libraries are named here; the libEGL
    # it dlopens through surfman is moonshine-sway-web's mesa-softpipe
    && apk add --no-cache eudev-libs libunwind \
    && curl -sL -o /tmp/servoshell.apk "https://github.com/bbusse/alpine-servo-build/releases/download/v${SERVO_VERSION}/$(apk --print-arch)-servoshell-${SERVO_VERSION}-r${SERVO_PKGREL}.$(apk --print-arch).apk" \
    && apk add --no-cache /tmp/servoshell.apk \
    && rm /tmp/servoshell.apk \
    # Cleanup: Remove files
    && rm -rf \
      /usr/share/man/* \
      /usr/includes/* \
      /var/cache/apk/* \
\
    # The controller starts sway itself, so there is no exec line for it here
    # Set bg with vju
    && echo "exec /usr/bin/vju --fullscreen --center-text --watch 1s date" \
    > /etc/sway/config.d/vju-bg \
\
    # Start rtsp stream with scream
    && echo "exec /usr/local/bin/scream" \
    > /etc/sway/config.d/scream

USER root
# Copy controller virtual environment from external image
COPY --from=iss-display-controller:latest /venv "${PATH_VENV}"
COPY --from=iss-display-controller:latest /controller/controller.py /usr/local/bin/controller.py
# Copy controller
COPY controller.py /usr/local/bin
# Copy swlc and scream (built by `make` before `make image`)
COPY swlc /usr/local/bin
COPY scream /usr/local/bin

COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
