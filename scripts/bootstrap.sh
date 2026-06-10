#!/usr/bin/env bash
# One-line installer: curl -fsSL .../bootstrap.sh | sudo bash
# Optional: IXTF_TAG=v1.2.6 to pin a release tag instead of main
set -euo pipefail

REPO="${IXTF_REPO:-ike-sh/ix-transit-fabric}"
TAG="${IXTF_TAG:-}"
TS="$(date +%s)"

tmp="$(mktemp /tmp/ix-transit-install.XXXXXX)"
trap 'rm -f -- "$tmp"' EXIT

if [[ -n "$TAG" ]]; then
    [[ "$TAG" == v* ]] || TAG="v${TAG}"
    echo "[INFO] 下载 ${REPO} ${TAG} ..."
    curl -fsSL -o "$tmp" "https://raw.githubusercontent.com/${REPO}/${TAG}/install.sh?ts=${TS}"
else
    echo "[INFO] 下载 ${REPO} main（最新 install.sh）..."
    curl -fsSL -o "$tmp" "https://raw.githubusercontent.com/${REPO}/main/install.sh?ts=${TS}"
fi
chmod +x "$tmp"

if [[ "$(id -u)" -eq 0 ]]; then
    bash "$tmp" install-easytier
    bash "$tmp" install-ix-cli
    bash "$tmp" repair-ix-cli 2>/dev/null || bash "$tmp" install-ix-cli
    ver="$(/usr/local/bin/ix --version 2>/dev/null || true)"
    [[ -n "$ver" ]] && echo "[OK] ${ver}" || { echo "[ERROR] ix 仍不可用，请运行：sudo /usr/local/libexec/ix-transit-fabric/install.sh repair-ix-cli" >&2; exit 1; }
else
    echo "[INFO] 非 root：仅下载 install.sh 到当前目录"
    install -m 0755 "$tmp" ./install.sh
    echo "[OK] 已保存 ./install.sh"
    echo "请运行：sudo bash install.sh install-easytier && sudo bash install.sh install-ix-cli"
fi
