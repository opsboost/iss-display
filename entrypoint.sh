#!/usr/bin/env sh
set -o errexit

if [ ! -s /etc/machine-id ]; then
    read -r uuid < /proc/sys/kernel/random/uuid
    printf '%s\n' "${uuid//-/}" > /etc/machine-id
fi

# The controller's WayvncServer owns wayvnc, with auth and a per-container
# password. The image ships no sway exec line for it; clear any a config
# drop-in adds so a second, unauthenticated instance never starts
rm -f /etc/sway/config.d/wayvnc

case "$1" in
    sh|bash)
        set -- "$@"
    ;;
    *)
        set -- /venv/bin/python3 /usr/local/bin/controller.py \
               --stream-source=vnc-browser --loglevel="${LOGLEVEL:-INFO}"
    ;;
esac

exec "$@"
