ARG MOONSHINE_SWAY_WEB_VERSION=llvmpipe
ARG ALPINE_TAG=3.24
ARG VJU_VERSION=v1-rc7
ARG VJU_PKGVER=1_rc7-r0
ARG VJU_FLAVOUR=vju
ARG SWLC_VERSION=v0-rc0
ARG SWLC_PKGVER=0.0.0-r0
ARG SCREAM_VERSION=v0-rc12
ARG SCREAM_PKGVER=0.1.0-r0
ARG MOONSHINE_VERSION=v0-rc21
ARG GST_MOONSHINE_PKGVER=1.28.3-r7
ARG WAYVNC_MOONSHINE_PKGVER=0.10.0-r0
ARG SERVO_VERSION=0.5.0_rc1
ARG SERVO_PKGREL=0
ARG CONTROLLER_IMAGE=ghcr.io/opsboost/iss-display-controller:latest

FROM docker.io/library/alpine:${ALPINE_TAG} AS fetch
RUN <<'SCRIPT'
set -eu
mkdir -p /packages

cat > /usr/local/bin/fetch <<'EOF'
#!/bin/sh
set -eu
echo "fetching $2"
wget -q -O "$1" "$2" || { echo "FAILED: $2" >&2; exit 1; }
asset="${2##*/}"
expected="$(awk -v a="$asset" '$2 == a { print $1 }' /checksums.txt)"
if [ -z "$expected" ]; then
    echo "no checksum pinned for $asset" >&2
    exit 1
fi
echo "$expected  $1" | sha256sum -c - >/dev/null || {
    echo "checksum mismatch for $asset" >&2
    exit 1
}
EOF
chmod +x /usr/local/bin/fetch

# python-wayland parses these two at startup. They are data, but apk only
# ships them inside -dev packages: wayland-dev alone brings linux-headers,
# pkgconf, expat-dev and libffi-dev, 8 MB of build tooling,
# Taking the files here keeps that out
apk add --no-cache wayland-dev wayland-protocols >/dev/null
mkdir -p /protocols/wayland /protocols/wayland-protocols/stable/xdg-shell
cp /usr/share/wayland/wayland.xml /protocols/wayland/
cp /usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml \
   /protocols/wayland-protocols/stable/xdg-shell/
SCRIPT

FROM fetch AS fetch-servo
ARG SERVO_VERSION
ARG SERVO_PKGREL
RUN <<'SCRIPT'
set -eu
cat > /checksums.txt <<'SUMS'
d74b431b288379ec8212d8af30d5d4e62182f81132392968c499447a2bdc5507  aarch64-servo-0.5.0_rc1-r0.aarch64.apk
dbafaad9a6e81495c6461bf2b73a68009645f85468b3e3cf41b150b529b9c463  x86_64-servo-0.5.0_rc1-r0.x86_64.apk
SUMS
fetch /packages/servo.apk \
    "https://github.com/bbusse/alpine-servo-build/releases/download/v${SERVO_VERSION}/$(apk --print-arch)-servo-${SERVO_VERSION}-r${SERVO_PKGREL}.$(apk --print-arch).apk"
SCRIPT

# gst and wayvnc ship from the same moonshine release, so a bump moves both:
# one stage, one layer to invalidate
FROM fetch AS fetch-moonshine
ARG MOONSHINE_VERSION
ARG GST_MOONSHINE_PKGVER
ARG WAYVNC_MOONSHINE_PKGVER
RUN <<'SCRIPT'
set -eu
cat > /checksums.txt <<'SUMS'
76cb5f3f21a02fb4f53e0fe41e7116a82f0f8d9becad1f2f49a9e2c8847f4099  wayvnc-moonshine-0.10.0-r0.aarch64-v0-rc21.apk
90b0521a96cdc2c48b4647c7cd4b138b32d40c1971fde577510766e0320e3c2f  wayvnc-moonshine-0.10.0-r0.x86_64-v0-rc21.apk
bd360e5ffdd85ab5006e7e2d16e154983622c254a5f20e5ac315bae9a6d1c7ce  gst-moonshine-1.28.3-r7.aarch64-v0-rc21.apk
6009f762110fa01d660d521d99cb1fa28ad94420cbc88ac19d77af66f01cc501  gst-moonshine-1.28.3-r7.x86_64-v0-rc21.apk
SUMS
fetch /packages/gst-moonshine.apk \
    "https://github.com/bbusse/moonshine/releases/download/${MOONSHINE_VERSION}/gst-moonshine-${GST_MOONSHINE_PKGVER}.$(apk --print-arch)-${MOONSHINE_VERSION}.apk"
fetch /packages/wayvnc-moonshine.apk \
    "https://github.com/bbusse/moonshine/releases/download/${MOONSHINE_VERSION}/wayvnc-moonshine-${WAYVNC_MOONSHINE_PKGVER}.$(apk --print-arch)-${MOONSHINE_VERSION}.apk"
SCRIPT

FROM fetch AS fetch-vju
ARG VJU_VERSION
ARG VJU_PKGVER
ARG VJU_FLAVOUR
RUN <<'SCRIPT'
set -eu
cat > /checksums.txt <<'SUMS'
37cb29139dbe72c9a8f1cb9bac5ea6d859668b54b68757b8d562138fec1b0219  vju-1_rc7-r0.aarch64-v1-rc7.apk
dddf20cbc6812c8310ceacc8405bf1bee0017fe26c21fd1e14dd2c1896ef0f23  vju-1_rc7-r0.x86_64-v1-rc7.apk
SUMS
fetch /packages/vju.apk \
    "https://github.com/bbusse/vju/releases/download/${VJU_VERSION}/${VJU_FLAVOUR}-${VJU_PKGVER}.$(apk --print-arch)-${VJU_VERSION}.apk"
SCRIPT

FROM fetch AS fetch-swlc
ARG SWLC_VERSION
ARG SWLC_PKGVER
RUN <<'SCRIPT'
set -eu
cat > /checksums.txt <<'SUMS'
e3c40af91e7a6970fdc95640f4beb5cad25dc626776b447fe6c8154b3b36755a  swlc-0.0.0-r0.aarch64-v0-rc0.apk
162e05cd3966527ffa422ec2c0469cc24f1996d2e0f2724fa65cf7935a54efdc  swlc-0.0.0-r0.x86_64-v0-rc0.apk
SUMS
fetch /packages/swlc.apk \
    "https://github.com/bbusse/swlc/releases/download/${SWLC_VERSION}/swlc-${SWLC_PKGVER}.$(apk --print-arch)-${SWLC_VERSION}.apk"
SCRIPT

FROM fetch AS fetch-scream
ARG SCREAM_VERSION
ARG SCREAM_PKGVER
RUN <<'SCRIPT'
set -eu
cat > /checksums.txt <<'SUMS'
71036a818f01a14e3bb5afaceea76f899d2e340123d3cc31fd4d0f21abb5235d  scream-0.1.0-r0.aarch64-v0-rc12.apk
ec3ccb5e6b2a92583116fcfee2c9d915a59316ea207e7660ea4e26c6c31dd9c8  scream-0.1.0-r0.x86_64-v0-rc12.apk
SUMS
fetch /packages/scream.apk \
    "https://github.com/bbusse/scream/releases/download/${SCREAM_VERSION}/scream-${SCREAM_PKGVER}.$(apk --print-arch)-${SCREAM_VERSION}.apk"
SCRIPT

FROM ${CONTROLLER_IMAGE} AS controller

FROM ghcr.io/bbusse/moonshine-sway-web:${MOONSHINE_SWAY_WEB_VERSION}
ARG VJU_FLAVOUR
LABEL maintainer="Björn Busse <bj.rn@baerlin.eu>"
LABEL org.opencontainers.image.source=https://github.com/bbusse/swayvnc-firefox

ENV APK_ADD="sed \
             python3 \
             gstreamer-tools \
             gnutls-utils \
             libwebp \
             libwebpmux \
             libwebpdemux" \
    APK_DEL="" \
    PATH_VENV="/venv" \
    PATH="${PATH_VENV}/bin:${PATH}"

ENV VJU_BIN="${VJU_FLAVOUR}"
USER root
COPY --from=fetch /protocols/ /usr/share/
COPY keys/apk-releases.rsa.pub /etc/apk/keys/apk-releases.rsa.pub

RUN --mount=type=bind,from=fetch-servo,source=/packages,target=/tmp/packages \
    apk add --no-cache eudev-libs libunwind wayland-libs-egl \
    && apk add --no-cache /tmp/packages/servo.apk

# Cleanup: Remove files
# Only paths this layer itself populated: deleting files owned by the base or
# by another layer writes whiteouts that reclaim nothing (the reasoning behind
# the apk bind mounts above). The old X11 entry also deleted sway's keymap
# data, so the pycache rm rides with the layer that installs python3
RUN apk add --no-cache ${APK_ADD} \
    && apk del --no-cache ${APK_DEL} \
    && rm -rf \
      /usr/share/man/* \
      /var/cache/apk/* \
      /usr/lib/python3.*/__pycache__ \
      /usr/lib/python3.*/*/__pycache__ \
      /usr/lib/python3.*/*/*/__pycache__

RUN --mount=type=bind,from=fetch-moonshine,source=/packages,target=/tmp/packages \
    apk add --no-cache /tmp/packages/gst-moonshine.apk \
    && apk add --no-cache /tmp/packages/wayvnc-moonshine.apk

# vju dlopens the unversioned libwayland-egl.so, which only wayland-dev ships,
# so the symlink stands in for that package
RUN --mount=type=bind,from=fetch-vju,source=/packages,target=/tmp/packages \
    apk add --no-cache /tmp/packages/vju.apk \
    && ln -sf libwayland-egl.so.1 /usr/lib/libwayland-egl.so

RUN --mount=type=bind,from=fetch-swlc,source=/packages,target=/tmp/packages \
    apk add --no-cache /tmp/packages/swlc.apk

RUN --mount=type=bind,from=fetch-scream,source=/packages,target=/tmp/packages \
    apk add --no-cache /tmp/packages/scream.apk

RUN found="$(apk info -e wayland-dev wayland-protocols linux-headers \
                  expat-dev libffi-dev \
                  mesa mesa-egl mesa-gl mesa-gles llvm22-libs \
                  libsoup3 glib-networking libpulse cdparanoia-libs \
                  gdk-pixbuf libglycin librsvg shared-mime-info \
                  gst-libav ffmpeg-libavcodec x265-libs libSvtAv1Enc aom-libs libdvdcss \
                  libbluray vulkan-loader libplacebo \
                  binutils 2>/dev/null || true)" \
    && if [ -n "$found" ]; then \
           echo "packages that should not be installed: $found" >&2; \
           exit 1; \
       fi

# Config only, so an edit here rebuilds nothing but this layer
RUN echo "swaybg_command -" > /etc/sway/config.d/no-swaybg
USER root

# Copy controller virtual environment from external image. --chown, not a
# later chown -R: pangocffi compiles its bindings into its own package dir on
# first import, so the venv has to be writable by the account the controller
# runs as, and --chown does that in the copy rather than in a second layer
# that would duplicate the venv's size
COPY --chown=1000:1000 --from=controller /venv "${PATH_VENV}"
COPY --from=controller /controller/controller.py /controller/render.py /usr/local/bin/

# The named theme and playlist presets, read by the controller from beside
# itself. Synced into this context
COPY themes.toml playlists.toml /usr/local/bin/

# py3status probes for i3 with pgrep before doing anything and dies without
# it. procps-ng cannot be installed next to uutils (both own cmd:uptime)
RUN printf '#!/bin/sh\nexit 1\n' > /usr/local/bin/pgrep && \
    chmod +x /usr/local/bin/pgrep

RUN : > /etc/machine-id && chown 1000:1000 /etc/machine-id
COPY entrypoint.sh /
USER moonshine
ENTRYPOINT ["/entrypoint.sh"]
