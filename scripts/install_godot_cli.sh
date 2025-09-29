#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.2.2}"
GODOT_VARIANT="${GODOT_VARIANT:-headless}"
ARCHIVE_NAME="Godot_v${GODOT_VERSION}-stable_linux_${GODOT_VARIANT}.64.zip"
DOWNLOAD_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/${ARCHIVE_NAME}"
INSTALL_ROOT="/usr/local/lib/godot"
TARGET_LINK="/usr/local/bin/godot"

SUDO=""
if command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

for tool in curl unzip; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool" >&2
    exit 1
  fi
done

if command -v godot >/dev/null 2>&1; then
  echo "Godot CLI already installed at $(command -v godot)"
  exit 0
fi

echo "Installing Godot ${GODOT_VERSION} (${GODOT_VARIANT}) from ${DOWNLOAD_URL}"

tmp_dir=$(mktemp -d)
trap 'rm -rf "${tmp_dir}"' EXIT

archive_path="${tmp_dir}/${ARCHIVE_NAME}"

curl -L --fail --progress-bar "${DOWNLOAD_URL}" -o "${archive_path}"

extract_dir="${tmp_dir}/extract"
mkdir -p "${extract_dir}"
unzip -q "${archive_path}" -d "${extract_dir}"

binary_path=$(find "${extract_dir}" -maxdepth 1 -type f -name "Godot_v*.64" | head -n1)
if [[ -z "${binary_path}" ]]; then
  echo "Failed to locate Godot binary in archive" >&2
  exit 1
fi

install_dir="${INSTALL_ROOT}/${GODOT_VERSION}-${GODOT_VARIANT}"
${SUDO} mkdir -p "${install_dir}"

binary_target="${install_dir}/godot"
${SUDO} install -m 0755 "${binary_path}" "${binary_target}"

${SUDO} ln -sf "${binary_target}" "${TARGET_LINK}"

echo "Godot CLI installed to ${TARGET_LINK}"
