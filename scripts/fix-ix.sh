#!/usr/bin/env bash
# Fix broken ix wrapper (e.g. points to /root/install.sh). Run:
# curl -fsSL "https://raw.githubusercontent.com/ike-sh/ix-transit-fabric/main/scripts/fix-ix.sh?ts=$(date +%s)" | sudo bash
set -euo pipefail

REPO="${IXTF_REPO:-ike-sh/ix-transit-fabric}"
LIBEXEC="/usr/local/libexec/ix-transit-fabric"
INSTALL_SH="${LIBEXEC}/install.sh"
TS="$(date +%s)"

if [[ "$(id -u)" -ne 0 ]]; then
    echo "[ERROR] 请使用 sudo 运行" >&2
    exit 1
fi

echo "[INFO] 同步 install.sh ..."
install -d -m 0755 "$LIBEXEC" /usr/local/bin
curl -fsSL -o "$INSTALL_SH" "https://raw.githubusercontent.com/${REPO}/main/install.sh?ts=${TS}"
chmod 0755 "$INSTALL_SH"

echo "[INFO] 重写 ix / IX wrapper ..."
tee /usr/local/bin/ix >/dev/null <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
IX_INSTALL_SH="/usr/local/libexec/ix-transit-fabric/install.sh"
if [[ ! -x "$IX_INSTALL_SH" ]]; then
    printf '%s\n' "[ERROR] 未找到：${IX_INSTALL_SH}" >&2
    exit 1
fi
if (($#)); then
    exec bash "$IX_INSTALL_SH" "$@"
else
    exec bash "$IX_INSTALL_SH" ix
fi
EOF
chmod 0755 /usr/local/bin/ix
cp -a /usr/local/bin/ix /usr/local/bin/IX

if declare -F ix >/dev/null 2>&1; then
    echo "[WARN] 当前 shell 存在 ix 函数，请执行：unset -f ix; hash -r"
fi

echo "[OK] $("/usr/local/bin/ix" --version)"
echo "[OK] 请用绝对路径测试：/usr/local/bin/ix"
echo "若仍失败，执行：type ix; head -3 /usr/local/bin/ix"
