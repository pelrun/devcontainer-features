#!/usr/bin/env bash

PI_VERSION=${VERSION:-"latest"}
PI_PACKAGE="@earendil-works/pi-coding-agent"

set -e

export NPM_CONFIG_UPDATE_NOTIFIER=false

if ! command -v npm >/dev/null 2>&1; then
    echo "(!) npm not found on PATH; the node feature (ghcr.io/devcontainers/features/node:2) is a hard dependency of this feature." >&2
    exit 1
fi

if [ "${PI_VERSION}" != "latest" ]; then
    PI_PACKAGE="${PI_PACKAGE}@${PI_VERSION}"
fi

echo "Installing ${PI_PACKAGE}..."
npm install -g --ignore-scripts "${PI_PACKAGE}"
