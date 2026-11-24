#!/usr/bin/env bash
set -e

RENODE_VERSION="${VERSION:-"1.17.0"}"

echo "Installing Renode ${RENODE_VERSION}..."

export DEBIAN_FRONTEND=noninteractive

# Install GTK/X11 runtime libraries, curl, tar, and Python for renode-test
apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    tar \
    gzip \
    python3 \
    python3-pip \
    python3-venv \
    libgtk-3-0 \
    libglib2.0-0 \
    libx11-6 \
    libxext6 \
    libxrender1 \
    libxtst6 \
    libxi6 \
    libicu-dev

rm -rf /var/lib/apt/lists/*

# Handle filename differences between Renode >= 1.17.0 and <= 1.16.x
ARCHIVE_NAME="renode-${RENODE_VERSION}.linux-portable.tar.gz"
if [[ "${RENODE_VERSION}" == 1.15.* || "${RENODE_VERSION}" == 1.16.* ]]; then
    ARCHIVE_NAME="renode-${RENODE_VERSION}.linux-portable-dotnet.tar.gz"
fi
#https://github.com/renode/renode/releases/download/v1.17.0/renode-1.17.0.linux-portable.tar.gz
DOWNLOAD_URL="https://github.com/renode/renode/releases/download/v${RENODE_VERSION}/${ARCHIVE_NAME}"

curl -fsSL "${DOWNLOAD_URL}" -o /tmp/renode.tar.gz
mkdir -p /opt/renode
tar -xzf /tmp/renode.tar.gz -C /opt/renode --strip-components=1
rm -f /tmp/renode.tar.gz

ln -sf /opt/renode/renode /usr/local/bin/renode
ln -sf /opt/renode/renode-test /usr/local/bin/renode-test

# Install Robot Framework requirements if present
if [ -f /opt/renode/tests/requirements.txt ]; then
    pip3 install --no-cache-dir --break-system-packages -r /opt/renode/tests/requirements.txt
fi

echo "Renode ${RENODE_VERSION} installed successfully."

