#!/usr/bin/env bash
# One-line installer: curl -fsSL .../bootstrap.sh | bash
# Optional: IXTF_TAG=v1.2.4 to pin version
set -euo pipefail

REPO="${IXTF_REPO:-ike-sh/ix-transit-fabric}"
TAG="${IXTF_TAG:-}"

if [[ -z "$TAG" ]]; then
    ver="$(curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/VERSION" | tr -d '[:space:]')"
    [[ -n "$ver" ]] || { echo "[ERROR] 无法读取 VERSION，请设置 IXTF_TAG=vX.Y.Z" >&2; exit 1; }
    TAG="v${ver#v}"
fi
[[ "$TAG" == v* ]] || TAG="v${TAG}"

tmp="$(mktemp /tmp/ix-transit-install.XXXXXX)"
trap 'rm -f -- "$tmp"' EXIT

echo "[INFO] 下载 ${REPO} ${TAG} ..."
curl -fsSL -o "$tmp" "https://raw.githubusercontent.com/${REPO}/${TAG}/install.sh?ts=$(date +%s)"
chmod +x "$tmp"

if [[ "$(id -u)" -eq 0 ]]; then
    bash "$tmp" install-easytier
    bash "$tmp" install-ix-cli
    bash "$tmp" repair-ix-cli
    echo "[OK] $(/usr/local/bin/ix --version 2>/dev/null || echo 'ix 验证失败')"
else
    echo "[INFO] 非 root：仅下载 install.sh 到当前目录"
    install -m 0755 "$tmp" ./install.sh
    echo "[OK] 已保存 ./install.sh"
    echo "请运行：sudo bash install.sh install-easytier && sudo bash install.sh install-ix-cli"
fi
