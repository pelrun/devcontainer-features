#!/usr/bin/env bash

VERSION=${VERSION:-"latest"}

USERNAME=${USERNAME:-${_REMOTE_USER:-"automatic"}}

set -e

# Clean up
rm -rf /var/lib/apt/lists/*

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

architecture="$(dpkg --print-architecture)"
if [ "${architecture}" != "amd64" ] && [ "${architecture}" != "arm64" ]; then
    echo "(!) Architecture $architecture unsupported"
    exit 1
fi

# Determine the appropriate non-root user
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u "${CURRENT_USER}" >/dev/null 2>&1; then
            USERNAME=${CURRENT_USER}
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u ${USERNAME} >/dev/null 2>&1; then
    USERNAME=root
fi

apt_get_update() {
    if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update -y
    fi
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" >/dev/null 2>&1; then
        apt_get_update
        apt-get -y install --no-install-recommends "$@"
    fi
}

check_git() {
    if [ ! -x "$(command -v git)" ]; then
        check_packages git
    fi
}

export DEBIAN_FRONTEND=noninteractive

GHIDRA_API="https://api.github.com/repos/NationalSecurityAgency/ghidra"

# Resolve which Ghidra version to install. Release tags are strictly
# Ghidra_<version>_build, but asset filenames embed a build date
# (ghidra_X.Y_PUBLIC_YYYYMMDD.zip), so neither the tag nor the URL can be
# derived by string substitution: versions come from git tags / the releases
# API, and the URL is taken from the API's asset listing.
RESOLVE_VERSION="none"
DOWNLOAD_URL=""

if [ "${VERSION}" != "none" ]; then
    if [ "${VERSION}" = "latest" ] || [ -z "${VERSION}" ] || [ "${VERSION}" = "current" ]; then
        # newest non-prerelease release: tag and asset URL from the same response
        echo "Resolving latest Ghidra release via GitHub API..."
        if ! release_json="$(curl -fsSL "${GHIDRA_API}/releases/latest")"; then
            echo "(!) GitHub releases API request failed: ${GHIDRA_API}/releases/latest" >&2
            echo "    Check your network or the GitHub API rate limit." >&2
            exit 1
        fi
        RESOLVE_VERSION="$(printf '%s\n' "${release_json}" \
            | grep -oE '"tag_name":[[:space:]]*"Ghidra_[^"]*_build"' \
            | head -n 1 | sed -E 's/.*Ghidra_([^"]*)_build.*/\1/')"
        DOWNLOAD_URL="$(printf '%s\n' "${release_json}" \
            | grep -oE '"browser_download_url":[[:space:]]*"[^"]*"' \
            | grep -oE 'https://[^"]*ghidra_[^"]*_PUBLIC_[^"]*\.zip' \
            | head -n 1)"
    else
        # concrete or partial version (e.g. 12, 12.1, 12.1.4): newest tag matching prefix
        check_git
        tags="$(git ls-remote --tags https://github.com/NationalSecurityAgency/ghidra \
            | grep -oE 'refs/tags/Ghidra_[0-9][0-9.]*_build$' \
            | sed -E 's|refs/tags/Ghidra_||; s|_build$||' \
            | sort -rV)"
        if [ -z "${tags}" ]; then
            echo "(!) Could not list Ghidra release tags from github.com." >&2
            exit 1
        fi
        RESOLVE_VERSION="$(echo "${tags}" | grep -E "^${VERSION//./\.}([.]|$)" | head -n 1)"
        if [ -z "${RESOLVE_VERSION}" ]; then
            echo "(!) Unknown Ghidra version '${VERSION}'. Available versions:" >&2
            echo "${tags}" | sed 's/^/    /' >&2
            exit 1
        fi
    fi
fi

if [ "${RESOLVE_VERSION}" != "none" ]; then
    check_packages curl ca-certificates unzip
    if [ -z "${DOWNLOAD_URL}" ]; then
        api_url="${GHIDRA_API}/releases/tags/Ghidra_${RESOLVE_VERSION}_build"
        echo "Resolving Ghidra ${RESOLVE_VERSION} download URL via GitHub API..."
        if ! release_json="$(curl -fsSL "${api_url}")"; then
            echo "(!) GitHub releases API request failed: ${api_url}" >&2
            echo "    Check the version, your network, or the GitHub API rate limit." >&2
            exit 1
        fi
        DOWNLOAD_URL="$(printf '%s\n' "${release_json}" \
            | grep -oE '"browser_download_url":[[:space:]]*"[^"]*"' \
            | grep -oE 'https://[^"]*ghidra_[^"]*_PUBLIC_[^"]*\.zip' \
            | head -n 1)"
    fi
    if [ -z "${DOWNLOAD_URL}" ]; then
        echo "(!) No Ghidra .zip asset found in the release (version: ${RESOLVE_VERSION})." >&2
        exit 1
    fi
    echo "Downloading Ghidra ${RESOLVE_VERSION} from ${DOWNLOAD_URL}..."
    curl -fsL "${DOWNLOAD_URL}" -o /tmp/ghidra.zip
    mkdir -p /opt
    unzip -q /tmp/ghidra.zip -d /opt/ghidra
    mv /opt/ghidra/ghidra*/* /opt/ghidra
fi

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Done!"

