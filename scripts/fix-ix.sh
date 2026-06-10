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

remove_ix_shell_overrides() {
    local f line removed=0
    for f in /root/.bashrc /root/.bash_profile /root/.profile /etc/bash.bashrc /etc/profile; do
        [[ -f "$f" ]] || continue
        if grep -qE 'alias (ix|IX)=' "$f" 2>/dev/null; then
            line="$(grep -nE 'alias (ix|IX)=' "$f" | head -1 || true)"
            sed -i.bak -E '/alias (ix|IX)=/d' "$f"
            echo "[OK] 已移除 ${f} 中的 ix 别名（${line}）"
            removed=1
        fi
    done
    [[ "$removed" -eq 1 ]] || echo "[INFO] 未在常见 rc 文件中发现 ix 别名"
    cat >/etc/profile.d/ix-transit-fabric.sh <<'EOF'
# ix-transit-fabric: 清除指向旧 ~/install.sh 的 shell 别名
unalias ix 2>/dev/null || true
unalias IX 2>/dev/null || true
EOF
    chmod 0644 /etc/profile.d/ix-transit-fabric.sh
}

remove_ix_shell_overrides

echo "[OK] $("/usr/local/bin/ix" --version)"
echo "[OK] 当前会话请执行：unalias ix 2>/dev/null; hash -r; ix"
echo "或新开 SSH 会话后直接运行 ix"
