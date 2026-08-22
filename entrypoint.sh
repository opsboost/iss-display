#!/usr/bin/env sh
set -o errexit

if [ ! -s /etc/machine-id ]; then
    read -r uuid < /proc/sys/kernel/random/uuid
    printf '%s\n' "${uuid//-/}" > /etc/machine-id
fi

case "$1" in
    sh|bash)
        set -- "$@"
    ;;
    *)
        set -- sway
    ;;
esac

exec "$@"
