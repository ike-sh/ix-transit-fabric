#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_VERSION="1.2.0-alpha.28"
APP_NAME="ix-transit-fabric"

CONFIG_DIR="/etc/ix-transit-fabric"
ENV_FILE="${CONFIG_DIR}/ix-transit.env"
PROFILES_DIR="${CONFIG_DIR}/profiles"
RULES_DIR="${CONFIG_DIR}/rules"
CODES_DIR="${CONFIG_DIR}/codes"
STATE_DIR="${CONFIG_DIR}/state"
SWITCH_HISTORY_FILE="${STATE_DIR}/switch-history.tsv"
HEALTH_HISTORY_FILE="${STATE_DIR}/health-history.tsv"
LAST_NOTIFY_FILE="${STATE_DIR}/last-notify.tsv"
LAST_HEALTH_STATUS_FILE="${STATE_DIR}/last-health-status.tsv"
NOTIFY_ENV_FILE="${CONFIG_DIR}/notify.env"
MONITOR_SERVICE_NAME="ix-transit-monitor.service"
MONITOR_TIMER_NAME="ix-transit-monitor.timer"
MONITOR_SERVICE_FILE="/etc/systemd/system/${MONITOR_SERVICE_NAME}"
MONITOR_TIMER_FILE="/etc/systemd/system/${MONITOR_TIMER_NAME}"
MONITOR_INTERVAL_FILE="${STATE_DIR}/monitor-interval"
MONITOR_LAST_RUN_FILE="${STATE_DIR}/monitor-last-run"
DDNS_SERVICE_NAME="ix-transit-ddns.service"
DDNS_TIMER_NAME="ix-transit-ddns.timer"
DDNS_SERVICE_FILE="/etc/systemd/system/${DDNS_SERVICE_NAME}"
DDNS_TIMER_FILE="/etc/systemd/system/${DDNS_TIMER_NAME}"
DDNS_INTERVAL_FILE="${STATE_DIR}/ddns-interval"
DDNS_LAST_RUN_FILE="${STATE_DIR}/ddns-last-run"
DDNS_DISABLED_FILE="${STATE_DIR}/ddns-disabled"
DDNS_DEFAULT_INTERVAL_MINUTES=3
BACKUP_DIR="/var/backups/ix-transit-fabric"
SERVICE_NAME="ix-transit-easytier.service"
SYSTEMD_SERVICE="/etc/systemd/system/${SERVICE_NAME}"
PROFILE_SERVICE_TEMPLATE="/etc/systemd/system/ix-transit-easytier@.service"
SYSCTL_FILE="/etc/sysctl.d/99-ix-transit-fabric.conf"
NFT_DIR="/etc/nftables.d"
NFT_FILE="${NFT_DIR}/ix-transit-fabric.nft"
NFT_TABLE="ix_transit_fabric"
LIBEXEC_DIR="/usr/local/libexec/ix-transit-fabric"
WRAPPER_FILE="${LIBEXEC_DIR}/easytier-start"
IX_CLI_INSTALL_SH="${LIBEXEC_DIR}/install.sh"
IX_CLI_BIN="/usr/local/bin/ix"
IX_CLI_BIN_UPPER="/usr/local/bin/IX"
EASYTIER_TARGET="/usr/local/bin/easytier-core"
LANDING_CODE_FILE="${CONFIG_DIR}/landing-code.txt"

DEFAULT_GITHUB_MIRRORS="https://gh.ddlc.top/,https://gh-proxy.com/,https://ghproxy.net/,https://gh.llkk.cc/"
GITHUB_REPO="EasyTier/EasyTier"
AUTO_INSTALL_EASYTIER="false"
INSTALL_ENV_FILE_PATH=""
CODE_ARG=""
CODE_FILE_ARG=""

IXTF_COLOR_ENABLED="false"
IXTF_C_RED=""
IXTF_C_GREEN=""
IXTF_C_YELLOW=""
IXTF_C_BLUE=""
IXTF_C_CYAN=""
IXTF_C_BOLD=""
IXTF_C_DIM=""
IXTF_C_RESET=""

color_init() {
    local mode="${IXTF_COLOR:-auto}"
    if [[ -n "${NO_COLOR:-}" ]]; then
        mode="never"
    fi
    case "$mode" in
        always) IXTF_COLOR_ENABLED="true" ;;
        never) IXTF_COLOR_ENABLED="false" ;;
        auto|*) [[ -t 1 && -t 2 && -n "${TERM:-}" && "${TERM:-dumb}" != "dumb" ]] && IXTF_COLOR_ENABLED="true" || IXTF_COLOR_ENABLED="false" ;;
    esac
    IXTF_C_RED=""
    IXTF_C_GREEN=""
    IXTF_C_YELLOW=""
    IXTF_C_BLUE=""
    IXTF_C_CYAN=""
    IXTF_C_BOLD=""
    IXTF_C_DIM=""
    IXTF_C_RESET=""
    if [[ "$IXTF_COLOR_ENABLED" == "true" ]]; then
        IXTF_C_RED=$'\033[31m'
        IXTF_C_GREEN=$'\033[32m'
        IXTF_C_YELLOW=$'\033[33m'
        IXTF_C_BLUE=$'\033[34m'
        IXTF_C_CYAN=$'\033[36m'
        IXTF_C_BOLD=$'\033[1m'
        IXTF_C_DIM=$'\033[2m'
        IXTF_C_RESET=$'\033[0m'
    fi
}

c_red() { printf '%s%s%s' "$IXTF_C_RED" "$*" "$IXTF_C_RESET"; }
c_green() { printf '%s%s%s' "$IXTF_C_GREEN" "$*" "$IXTF_C_RESET"; }
c_yellow() { printf '%s%s%s' "$IXTF_C_YELLOW" "$*" "$IXTF_C_RESET"; }
c_blue() { printf '%s%s%s' "$IXTF_C_BLUE" "$*" "$IXTF_C_RESET"; }
c_cyan() { printf '%s%s%s' "$IXTF_C_CYAN" "$*" "$IXTF_C_RESET"; }
c_bold() { printf '%s%s%s' "$IXTF_C_BOLD" "$*" "$IXTF_C_RESET"; }
c_dim() { printf '%s%s%s' "$IXTF_C_DIM" "$*" "$IXTF_C_RESET"; }
c_reset() { printf '%s' "$IXTF_C_RESET"; }

print_ok() { printf '%s %s\n' "$(c_green '[OK]')" "$*" >&2; }
print_warn() { printf '%s %s\n' "$(c_yellow '[WARN]')" "$*" >&2; }
print_error() { printf '%s %s\n' "$(c_red '[ERROR]')" "$*" >&2; }
print_info() { printf '%s %s\n' "$(c_cyan '[INFO]')" "$*" >&2; }
print_step() { printf '\n%s %s\n' "$(c_bold "$(c_blue '==>')")" "$(c_bold "$*")" >&2; }
print_box() {
    local title="$1"
    shift || true
    printf '\n%s\n' "$(c_bold "$title")"
    printf '%s\n' "$@"
}
print_next_steps() {
    local title="${1:-下一步：}" i=1 step
    shift || true
    printf '\n%s\n' "$(c_green "$title")"
    for step in "$@"; do
        printf '  %s. %s\n' "$i" "$step"
        i=$((i + 1))
    done
}

print_port_map_compact() {
    local profile_id="${PROFILE_ID:-default}"
    local listener_port="${LISTENER_PORT:-${ET_LISTENER_PORT:-${CODE_LISTENER_PORT:-EasyTier listener 端口}}}"
    local ingress_listener_port="${INGRESS_LISTENER_PORT:-${ET_LISTENER_PORT:-}}"
    local remote_port="${REMOTE_PORT:-${SERVICE_PORT:-落地业务端口}}"
    local local_port="${LOCAL_PORT:-客户端入口端口}"
    local cnix_port="${CNIX_ENTRY_PORT:-商家入口端口}"
    local cnix_host="${CNIX_ENTRY_HOST:-商家入口地址}"
    local landing_ip="${LANDING_ET_IP:-落地机虚拟 IP}"
    local landing_public="${LANDING_PUBLIC_HOST:-${CODE_LANDING_PUBLIC_HINT:-落地 VPS 公网 IP}}"
    local ingress_et_ip="${INGRESS_ET_IP:-公网入口机虚拟 IP}"
    local nat_et_ip="${NAT_ET_IP:-NAT IX 虚拟 IP}"
    local transit_port="${TRANSIT_PORT:-虚拟网中转端口}"
    local ingress_public="${INGRESS_PUBLIC_HOST:-公网入口 VPS}"
    local landing_host="${LANDING_HOST:-落地机地址}"
    local landing_port="${LANDING_PORT:-落地业务端口}"
    local nat_direction="${NAT_DIRECTION:-ingress-listener}"
    local nat_public="${NAT_PUBLIC_HOST:-商家 NAT/IX 入口地址}"
    local nat_listener_port="${NAT_LISTENER_PORT:-${ET_LISTENER_PORT:-}}"

    case "${ROLE:-}" in
        nat-ingress)
            if [[ "$nat_direction" == "nat-listener" ]]; then
                printf '线路：%s（公网入口线路）\n\n' "$profile_id"
                printf '客户端连接：\n'
                printf '  公网入口机公网 IP:%s\n\n' "$(c_cyan "$local_port")"
                printf '连接 NAT IX：\n'
                if [[ -n "$nat_listener_port" ]]; then
                    printf '  %s:%s\n\n' "$nat_public" "$(c_cyan "$nat_listener_port")"
                else
                    printf '  商家 NAT/IX 入口地址:商家分配入口端口（未配置）\n\n'
                fi
                printf '转发规则：\n'
                format_rules_for_port_map "$profile_id"
                printf '说明：虚拟网中转端口只在 EasyTier 虚拟网内部使用，不是公网端口，不是商家入口端口。\n'
            else
                printf '线路：%s（公网入口线路，兼容旧模式）\n\n' "$profile_id"
                printf '客户端连接：\n'
                printf '  %s:%s\n\n' "$ingress_public" "$(c_cyan "$local_port")"
                printf 'EasyTier 监听：\n'
                if [[ -n "$ingress_listener_port" ]]; then
                    printf '  %s:%s\n\n' "$ingress_public" "$(c_cyan "$ingress_listener_port")"
                else
                    printf '  公网入口机 EasyTier 监听端口未配置\n\n'
                fi
                printf '虚拟网转发：\n'
                printf '  客户端入口端口 %s -> %s:%s\n\n' "$local_port" "$nat_et_ip" "$transit_port"
                printf '说明：这是兼容旧模式，NAT IX 机器会连接公网入口机。\n'
            fi
            ;;
        nat-transit)
            if [[ "$nat_direction" == "nat-listener" ]]; then
                printf '线路：%s（NAT IX 中转线路）\n\n' "$profile_id"
                printf '商家入口：\n'
                if [[ -n "$nat_listener_port" ]]; then
                    printf '  %s:%s\n\n' "$nat_public" "$(c_cyan "$nat_listener_port")"
                else
                    printf '  商家 NAT/IX 入口地址:商家分配入口端口（未配置）\n\n'
                fi
                printf '用途：公网入口机通过 EasyTier 连接到这里。\n\n'
                printf '虚拟网：\n'
                printf '  NAT IX 虚拟 IP：%s\n' "$nat_et_ip"
                printf '  公网入口机虚拟 IP：%s\n\n' "$ingress_et_ip"
                printf '转发规则：\n'
                format_rules_for_port_map "$profile_id"
                printf '说明：虚拟网中转端口只在 EasyTier 虚拟网内部使用，不是公网端口，不需要商家放行。\n\n'
                printf '客户端连接：\n'
                printf '  公网入口机导入接入码后，客户端连接各规则的公网入口端口。\n'
            else
                printf '线路：%s（NAT IX 中转线路，兼容旧模式）\n\n' "$profile_id"
                printf '连接公网入口机：\n'
                if [[ -n "$ingress_listener_port" ]]; then
                    printf '  %s:%s\n\n' "$ingress_public" "$(c_cyan "$ingress_listener_port")"
                else
                    printf '  公网入口机 EasyTier 监听端口未配置\n\n'
                fi
                printf '虚拟网中转：\n'
                printf '  %s:%s -> %s:%s\n\n' "$nat_et_ip" "$(c_cyan "$transit_port")" "$landing_host" "$landing_port"
                printf '客户端连接：\n'
                printf '  %s:%s\n' "$ingress_public" "$local_port"
            fi
            ;;
        *)
            printf '[WARN] 当前角色未知：%s\n' "${ROLE:-未设置}"
            ;;
    esac
}

color_init

log_info() { print_info "$*"; }
log_warn() { print_warn "$*"; }
log_error() { print_error "$*"; }

legacy_panel_removed() {
    die_user "panel-landing / panel-ingress 已彻底移除。请使用 NAT IX 流程：创建中转线路 + 公网入口导入接入码。"
}

reject_legacy_panel_role() {
    case "${ROLE:-}" in
        panel-landing|panel-ingress)
            legacy_panel_removed
            ;;
    esac
}

debug_enabled() {
    case "${IXTF_DEBUG:-false}" in
        1|true|TRUE|yes|YES|on|ON|debug|DEBUG) return 0 ;;
        *) return 1 ;;
    esac
}
log_debug() {
    debug_enabled || return 0
    print_info "$*"
}
log_ok() { print_ok "$*"; }

on_error() {
    local exit_code=$?
    local line="${1:-unknown}"
    log_error "脚本在第 ${line} 行异常退出（退出码 ${exit_code}）。"
}
if [[ "${IXTF_TEST_SOURCE:-}" != "1" ]]; then
    trap 'on_error $LINENO' ERR
fi

die_user() {
    log_error "$*"
    exit 1
}

return_or_exit() {
    local rc="${1:-1}"
    if [[ "${IXTF_TEST_SOURCE:-}" == "1" ]]; then
        return "$rc"
    fi
    exit "$rc"
}

usage() {
    cat <<'USAGE'
ix-transit-fabric - NAT-IX + EasyTier + nftables 中转线路管理脚本
作者：ike
项目地址：https://github.com/ike-sh/ix-transit-fabric

基础：
  bash install.sh --help
  bash install.sh --version
  bash install.sh --menu
  bash install.sh ix
  bash install.sh IX
  ix / IX                 # 安装快捷命令后，直接输入即可进菜单
  bash install.sh install-ix-cli
  bash install.sh --debug install-easytier

安装 / 更新：
  bash install.sh install-easytier
  bash install.sh update-easytier
  bash install.sh install-netcat
  bash install.sh install-diagnostics-tools
  bash install.sh preflight [landing|ingress|all]

	NAT-IX 正式流程：
	  bash install.sh add-nat-listener-profile
	  bash install.sh add-nat-ingress-from-listener-code [--code IXTF1:...] [--code-file PATH]
	  bash install.sh import-code [--code IXTF1:...] [--code-file PATH]
	  bash install.sh show-code [线路ID]
	  bash install.sh show-nat-code [线路ID]
	  bash install.sh show-config [PROFILE_ID]
	  bash install.sh show-port-map [线路ID] [--compact]
	  bash install.sh show-port-map --all [--compact]
	  bash install.sh show-port-map-compact [线路ID]
	  bash install.sh list-rules [线路ID]
	  bash install.sh add-rule [线路ID]
	  bash install.sh edit-rule 线路ID 规则ID
	  bash install.sh enable-rule 线路ID 规则ID
	  bash install.sh disable-rule 线路ID 规则ID
	  bash install.sh delete-rule 线路ID 规则ID
	  bash install.sh show-rule 线路ID 规则ID
	  bash install.sh apply-rules [线路ID]
	  bash install.sh set-easytier-protocol [线路ID]
	  bash install.sh nat-guide [线路ID]
	  bash install.sh check-port [--all|线路ID]
	  bash install.sh check-business [--all|线路ID]

	show-config PROFILE_ID 优先读取 profiles/PROFILE_ID.env；若只有一条线路，自动选择唯一线路。

	多线路：
	  bash install.sh list-profiles
	  bash install.sh show-profile 线路ID
	  bash install.sh enable-profile 线路ID
	  bash install.sh disable-profile 线路ID
	  bash install.sh delete-profile 线路ID
  bash install.sh status-all
  bash install.sh doctor-all

更换：
	  bash install.sh refresh-code [线路ID]
	  bash install.sh refresh-nat-code [线路ID]
	  bash install.sh show-easytier-command [线路ID]
	  bash install.sh show-easytier-status [线路ID]
	  bash install.sh diagnose [线路ID]

主备：
  bash install.sh health-all
  bash install.sh health-report [--group GROUP]
  bash install.sh primary-backup-check GROUP
  bash install.sh switch-dry-run GROUP TARGET_PROFILE_ID
  bash install.sh switch-line GROUP TARGET_PROFILE_ID
  bash install.sh switch-history [GROUP] [--limit N]
  bash install.sh switch-rollback-last
  bash install.sh verify-nft-profiles

监控 / 通知 / 流量：
  bash install.sh monitor-run-once [--force-notify]
  bash install.sh monitor-enable
  bash install.sh monitor-disable
  bash install.sh monitor-status
  bash install.sh ddns-refresh
  bash install.sh ddns-status
  bash install.sh ddns-enable
  bash install.sh ddns-disable
  bash install.sh notify-config
  bash install.sh notify-test
  bash install.sh notify-status
	  bash install.sh health-history [线路ID|--group GROUP] [--limit N]
	  bash install.sh traffic-report [--group GROUP] [--sample N]
	  bash install.sh latency-report 线路ID [--sample N]
	  bash install.sh nat-latency 线路ID [--sample N]
  bash install.sh latency-all [--sample N]

维护：
  bash install.sh logs
  bash install.sh show-nft
  bash install.sh self-check
  bash install.sh export-diagnostic
  bash install.sh cleanup-history [--keep-health N] [--keep-switch N]
  bash install.sh cleanup-state
  bash install.sh uninstall
  bash install.sh purge

说明：
  - 无参数且当前是交互式 TTY 时进入菜单。
  - 运行 install-ix-cli 后，可直接输入 ix 或 IX 进入管理菜单（首次 bash install.sh ix 也会自动安装）。
  - monitor / notify 只做检查和提醒，不会自动切换。
  - DDNS 默认启用：商家域名 IP 变化时自动刷新 nftables / EasyTier（每 3 分钟）；`ddns-disable` 可关闭定时刷新。
	  - 普通菜单只展示 NAT IX listener 正式流程。
	  - 历史配置仍尽量兼容，但新部署只推荐 NAT IX listener 流程。
	  - show-port-map / verify-nft-profiles / traffic-report 支持 NAT-IX 线路。
	  - 转发规则管理支持规则备注、商家入口端口、虚拟网中转端口、rules 数组、code_schema=4、rule-main。
	  - EasyTier 组网协议支持 WebSocket、WebSocket TLS、QUIC、WireGuard 和 ALL。
	  - latency-report / nat-latency / latency-all 提供 NAT-IX 分段延迟诊断。
	  - purge 会删除配置、线路、接入码、state、notify.env、history 和备份，执行前必须确认。
USAGE
}

is_tty() {
    [[ -t 0 && -t 1 ]]
}

is_interactive_input() {
    [[ "${IXTF_FORCE_NON_TTY:-}" == "1" ]] && return 1
    [[ -n "${IXTF_IN_MENU:-}" || -n "${IXTF_ALLOW_INTERACTIVE:-}" ]] && return 0
    [[ -t 0 ]] && return 0
    [[ "${IXTF_USE_DEV_TTY:-}" == "1" && -r /dev/tty && -w /dev/tty ]] && return 0
    return 1
}

fail_need_tty() {
    local cmd="${1:-add-nat-listener-profile}"
    local example="bash install.sh add-nat-listener-profile --env-file examples/legacy/profile-landing.env"
    case "$cmd" in
        add-nat-ingress-from-listener-code)
            example="bash install.sh add-nat-ingress-from-listener-code --env-file examples/legacy/profile-ingress.env"
            ;;
        add-nat-ingress-from-listener-code-from-code)
            example="bash install.sh add-nat-ingress-from-listener-code-from-code --code-file /root/landing.code"
            ;;
        --menu|menu)
            example="ssh -tt root@SERVER 'cd /root/ix-transit-fabric && bash install.sh --menu'"
            ;;
    esac
    log_error "当前命令需要交互式终端 TTY。"
    log_info "请先进入交互式 SSH："
    printf '       ssh -tt root@SERVER\n' >&2
    log_info "或使用非交互 env 文件方式："
    printf '       %s\n' "$example" >&2
    exit 1
}

require_tty() {
    is_interactive_input || fail_need_tty "${1:-add-nat-listener-profile}"
}

require_root() {
    [[ "${EUID}" -eq 0 ]] || die_user "请使用 root 权限运行，例如：sudo bash install.sh $*"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

detect_nc_cmd() {
    if command_exists nc; then
        printf 'nc\n'
        return 0
    fi
    if command_exists ncat; then
        printf 'ncat\n'
        return 0
    fi
    return 1
}

assume_yes_enabled() {
    case "${IXTF_ASSUME_YES:-false}" in
        true|TRUE|1|yes|YES|y|Y) return 0 ;;
        *) return 1 ;;
    esac
}

auto_install_easytier_enabled() {
    [[ "$AUTO_INSTALL_EASYTIER" == "true" ]] && return 0
    case "${IXTF_AUTO_INSTALL_EASYTIER:-false}" in
        true|TRUE|1|yes|YES|y|Y) return 0 ;;
        *) return 1 ;;
    esac
}

suggest_install_nc() {
    cat <<'EOF'
nc/ncat 不可用，已跳过 TCP 业务端口探测。
Debian/Ubuntu 可安装：apt install -y netcat-openbsd
可选替代：apt install -y ncat
EOF
}

install_nc_tool() {
    require_root "$@"
    if detect_nc_cmd >/dev/null 2>&1; then
        log_ok "netcat 诊断工具已存在：$(detect_nc_cmd)"
        return 0
    fi
    if ! command_exists apt-get; then
        log_warn "未检测到 apt，请手动安装 nc 或 ncat。"
        return 1
    fi
    log_info "正在安装 netcat 诊断工具。"
    apt-get update || return 1
    if DEBIAN_FRONTEND=noninteractive apt-get install -y netcat-openbsd; then
        :
    elif DEBIAN_FRONTEND=noninteractive apt-get install -y ncat; then
        :
    elif DEBIAN_FRONTEND=noninteractive apt-get install -y openbsd-netcat; then
        :
    else
        log_warn "netcat 安装失败；netcat 仅用于诊断，EasyTier 线路仍可继续安装。"
        return 1
    fi
    if detect_nc_cmd >/dev/null 2>&1; then
        log_ok "netcat 诊断工具安装完成：$(detect_nc_cmd)"
        return 0
    fi
    log_warn "netcat 安装后仍未找到 nc/ncat；netcat 仅用于诊断，EasyTier 线路仍可继续安装。"
    return 1
}

ensure_nc_tool() {
    if detect_nc_cmd >/dev/null 2>&1; then
        return 0
    fi
    log_warn "未找到 nc/ncat。建议安装 netcat 以便健康检查和端口诊断。"
    if assume_yes_enabled; then
        install_nc_tool || true
        return 0
    fi
    if is_tty; then
        if [[ "$(prompt_yes_no "是否现在安装 netcat 诊断工具" "true")" == "true" ]]; then
            install_nc_tool || true
        else
            log_warn "已跳过 netcat 安装；netcat 仅用于诊断，EasyTier 线路仍可继续安装。"
        fi
        return 0
    fi
    log_warn "非交互模式未自动安装 netcat；可稍后运行：bash install.sh install-netcat"
    return 0
}

ensure_systemctl() {
    command_exists systemctl || die_user "当前系统没有 systemctl。本脚本需要 systemd。"
}

ensure_config_dir() {
    install -d -m 700 "$CONFIG_DIR"
    install -d -m 700 "$BACKUP_DIR"
}

ensure_profile_dirs() {
    ensure_config_dir
    install -d -m 700 "$PROFILES_DIR" "$RULES_DIR" "$CODES_DIR" "$STATE_DIR"
}

make_tmp_file() {
    local prefix="$1" tmp_dir="${IXTF_TMPDIR:-/tmp}"
    [[ "$tmp_dir" == "/tmp" ]] || install -d -m 700 "$tmp_dir"
    mktemp "${tmp_dir%/}/${prefix}.XXXXXX"
}

make_tmp_dir() {
    local prefix="$1" tmp_dir="${IXTF_TMPDIR:-/tmp}"
    [[ "$tmp_dir" == "/tmp" ]] || install -d -m 700 "$tmp_dir"
    mktemp -d "${tmp_dir%/}/${prefix}.XXXXXX"
}

backup_file() {
    local path="$1"
    [[ -e "$path" ]] || return 0

    ensure_config_dir
    local stamp safe_name target
    stamp="$(date +%Y%m%d-%H%M%S)"
    safe_name="${path#/}"
    safe_name="${safe_name//\//__}"
    target="${BACKUP_DIR}/${safe_name}.${stamp}.bak"
    cp -a -- "$path" "$target"
    chmod go-rwx "$target" 2>/dev/null || true
    log_debug "已备份旧文件：${path} -> ${target}"
}

install_if_changed() {
    local tmp="$1" target="$2" mode="$3" label="$4"
    if [[ -f "$target" ]] && cmp -s "$tmp" "$target"; then
        rm -f -- "$tmp"
        log_debug "${label}已是最新。"
        return 0
    fi
    backup_file "$target"
    install -m "$mode" "$tmp" "$target"
    rm -f -- "$tmp"
    log_debug "已写入 ${label}：${target}"
    return 0
}

backup_binary() {
    local path="$1"
    [[ -e "$path" ]] || return 0

    ensure_config_dir
    local stamp target
    stamp="$(date +%Y%m%d-%H%M%S)"
    target="${BACKUP_DIR}/easytier-core.${stamp}"
    cp -a -- "$path" "$target"
    chmod 700 "$target" 2>/dev/null || true
    log_debug "已备份旧版本：${target}"
}

backup_and_remove_file() {
    local path="$1"
    [[ -e "$path" ]] || return 0
    backup_file "$path"
    rm -f -- "$path"
    log_ok "已删除：${path}"
}

trim_space() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s\n' "$value"
}

normalize_menu_choice() {
    trim_space "${1%$'\r'}"
}

split_mirrors() {
    local mirrors item old_ifs
    if [[ -v IXTF_GITHUB_MIRRORS ]]; then
        mirrors="${IXTF_GITHUB_MIRRORS}"
    else
        mirrors="${DEFAULT_GITHUB_MIRRORS}"
    fi

    [[ -z "$mirrors" ]] && return 0
    old_ifs="$IFS"
    IFS=','
    for item in $mirrors; do
        item="$(trim_space "$item")"
        [[ -n "$item" ]] && printf '%s\n' "$item"
    done
    IFS="$old_ifs"
}

mirror_url() {
    local mirror="$1"
    local original="$2"
    [[ "${mirror: -1}" == "/" ]] || mirror="${mirror}/"
    printf '%s%s\n' "$mirror" "$original"
}

download_file() {
    local url="$1"
    local dest="$2"

    rm -f -- "$dest"
    if command_exists curl; then
        curl -fL -sS --connect-timeout 6 --max-time 20 --retry 1 -o "$dest" "$url"
    elif command_exists wget; then
        wget -q -O "$dest" -T 20 "$url"
    else
        die_user "未找到 curl 或 wget。请先安装其中一个下载工具。"
    fi
}

verify_download() {
    local url="$1"
    local path="$2"
    local clean_url="${url%%\?*}"

    [[ -s "$path" ]] || return 1

    case "$clean_url" in
        *.tar.gz|*.tgz)
            tar -tzf "$path" >/dev/null
            ;;
        *.zip)
            if command_exists unzip; then
                unzip -tq "$path" >/dev/null
            else
                log_warn "未安装 unzip，跳过 zip 完整性测试。"
            fi
            ;;
    esac
}

download_with_mirrors() {
    local original_url="$1"
    local dest="$2"
    local attempt_url part mirror direct_first err_file failures=""

    part="${dest}.part.$$"
    err_file="${part}.err"
    direct_first="${IXTF_GITHUB_DIRECT_FIRST:-false}"

    try_download_source() {
        local label="$1"
        local url="$2"
        local detail
        log_debug "正在尝试下载源：${label}"
        log_debug "下载地址：${url}"
        rm -f -- "$err_file"
        if download_file "$url" "$part" 2>"$err_file" && verify_download "$original_url" "$part" 2>>"$err_file"; then
            mv -f -- "$part" "$dest"
            rm -f -- "$err_file"
            log_debug "下载完成，已通过基本校验：${label}"
            return 0
        fi
        rm -f -- "$part"
        detail="$(sed -n '1,3p' "$err_file" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' || true)"
        failures="${failures}下载源失败：${label}
URL：${url}
原因：${detail:-下载或校验失败}
"
        if debug_enabled; then
            log_warn "下载源失败：${label}"
            [[ -n "$detail" ]] && log_warn "$detail"
        fi
        rm -f -- "$err_file"
        return 1
    }

    if [[ "$direct_first" == "true" ]]; then
        try_download_source "原始 GitHub" "$original_url" && return 0
    fi

    while IFS= read -r mirror; do
        attempt_url="$(mirror_url "$mirror" "$original_url")"
        try_download_source "镜像 ${mirror}" "$attempt_url" && return 0
    done < <(split_mirrors)

    if [[ "$direct_first" != "true" ]]; then
        try_download_source "原始 GitHub（最后兜底）" "$original_url" && return 0
    fi

    log_error "所有下载源均失败。"
    [[ -n "$failures" ]] && printf '%s' "$failures" >&2
    log_error "可设置 IXTF_GITHUB_MIRRORS 指定镜像，或设置 IXTF_EASYTIER_DOWNLOAD_URL 指定 release archive。"
    log_error "也可设置 IXTF_EASYTIER_VERSION 指定版本，或设置 IXTF_GITHUB_DIRECT_FIRST=true 先走原始 GitHub。"
    log_error "手工方案：在另一台机器安装后复制 /usr/local/bin/easytier-core 到本机同路径，并 chmod +x。"
    rm -f -- "$err_file"
    return 1
}

detect_os() {
    local os
    os="$(uname -s 2>/dev/null || true)"
    case "${os,,}" in
        linux) printf 'linux\n' ;;
        *) die_user "不支持的系统：${os:-unknown}。当前自动安装仅支持 Linux。" ;;
    esac
}

detect_arch() {
    local arch
    log_debug "正在检测系统架构。"
    arch="$(uname -m 2>/dev/null || true)"
    case "$arch" in
        x86_64|amd64) printf 'amd64\n' ;;
        aarch64|arm64) printf 'arm64\n' ;;
        *) die_user "不支持的系统架构：${arch:-unknown}。当前支持 amd64 / arm64。" ;;
    esac
}

easytier_asset_arch() {
    case "$1" in
        amd64) printf 'x86_64\n' ;;
        arm64) printf 'aarch64\n' ;;
        *) return 1 ;;
    esac
}

normalize_easytier_version() {
    local version="$1"
    [[ -n "$version" ]] || return 1
    if [[ "$version" == v* ]]; then
        printf '%s\n' "$version"
    else
        printf 'v%s\n' "$version"
    fi
}

latest_easytier_version() {
    local tmp tag
    tmp="$(make_tmp_file "ix-transit-fabric.github-api")"
    if ! download_with_mirrors "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" "$tmp"; then
        rm -f -- "$tmp"
        return 1
    fi

    tag="$(grep -m1 '"tag_name"' "$tmp" | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' || true)"
    rm -f -- "$tmp"
    [[ -n "$tag" && "$tag" != *"tag_name"* ]] || return 1
    printf '%s\n' "$tag"
}

resolve_easytier_download_url() {
    local os arch asset_arch version asset
    os="$(detect_os)"
    arch="$(detect_arch)"
    asset_arch="$(easytier_asset_arch "$arch")"

    if [[ -n "${IXTF_EASYTIER_DOWNLOAD_URL:-}" ]]; then
        printf '%s\n' "$IXTF_EASYTIER_DOWNLOAD_URL"
        return 0
    fi

    if [[ -n "${IXTF_EASYTIER_VERSION:-}" ]]; then
        version="$(normalize_easytier_version "$IXTF_EASYTIER_VERSION")"
    else
        log_debug "正在解析 EasyTier 最新版本。"
        if ! version="$(latest_easytier_version)"; then
            die_user "无法解析 EasyTier 最新版本。请设置 IXTF_EASYTIER_VERSION 或 IXTF_EASYTIER_DOWNLOAD_URL。"
        fi
    fi

    asset="easytier-${os}-${asset_arch}-${version}.zip"
    printf 'https://github.com/%s/releases/download/%s/%s\n' "$GITHUB_REPO" "$version" "$asset"
}

detect_easytier_binary() {
    if [[ -x "$EASYTIER_TARGET" ]]; then
        printf '%s\n' "$EASYTIER_TARGET"
        return 0
    fi

    if command_exists easytier-core; then
        command -v easytier-core
        return 0
    fi

    return 1
}

get_easytier_version() {
    local bin="${1:-}"
    local output rc
    [[ -n "$bin" && -x "$bin" ]] || {
        printf '未知\n'
        return 0
    }

    set +e
    output="$("$bin" --version 2>&1 | sed -n '1p')"
    rc=$?
    set -e

    if [[ "$rc" -ne 0 || -z "$output" ]]; then
        log_warn "无法读取 EasyTier 版本。"
        printf '未知\n'
    else
        printf '%s\n' "$output"
    fi
}

extract_easytier_archive() {
    local archive="$1"
    local url="$2"
    local workdir="$3"
    local clean_url="${url%%\?*}"

    case "$clean_url" in
        *.tar.gz|*.tgz)
            tar -xzf "$archive" -C "$workdir"
            ;;
        *.zip)
            command_exists unzip || die_user "下载的是 zip 包，但系统没有 unzip。请安装 unzip，或用 IXTF_EASYTIER_DOWNLOAD_URL 指定 tar.gz 包。"
            unzip -q "$archive" -d "$workdir"
            ;;
        *)
            die_user "不支持的 EasyTier 压缩包格式：${url}"
            ;;
    esac
}

install_easytier() {
    require_root "$@"

    local url archive workdir binary new_target installed_version
    ensure_config_dir
    printf '正在安装 EasyTier...\n'
    printf '正在尝试多个下载源，请稍候...\n'
    url="$(resolve_easytier_download_url)"
    archive="$(make_tmp_file "ix-transit-fabric.easytier")"
    workdir="$(make_tmp_dir "ix-transit-fabric.extract")"

    log_debug "EasyTier 下载地址：${url}"
    if ! download_with_mirrors "$url" "$archive"; then
        rm -rf -- "$archive" "$workdir"
        die_user "EasyTier 下载失败，已有 easytier-core 不会被改动。可设置 IXTF_EASYTIER_VERSION / IXTF_EASYTIER_DOWNLOAD_URL 后重试，或手动复制 easytier-core 到 ${EASYTIER_TARGET} 并 chmod +x。"
    fi

    log_debug "下载完成，正在解压和校验。"
    extract_easytier_archive "$archive" "$url" "$workdir"
    binary="$(find "$workdir" -type f -name easytier-core 2>/dev/null | head -n 1 || true)"
    [[ -n "$binary" ]] || {
        rm -rf -- "$archive" "$workdir"
        die_user "压缩包内没有找到 easytier-core，已有版本不会被改动。"
    }

    backup_binary "$EASYTIER_TARGET"
    new_target="${EASYTIER_TARGET}.new.$$"
    log_debug "正在安装 easytier-core。"
    install -m 0755 "$binary" "$new_target"
    mv -f -- "$new_target" "$EASYTIER_TARGET"

    rm -rf -- "$archive" "$workdir"
    installed_version="$(get_easytier_version "$EASYTIER_TARGET")"
    printf 'EasyTier 安装完成。\n'
    log_debug "EasyTier 安装路径：${EASYTIER_TARGET}（${installed_version}）"
}

update_easytier() {
    install_easytier "$@"
}

ensure_easytier() {
    if detect_easytier_binary >/dev/null 2>&1; then
        return 0
    fi

    if auto_install_easytier_enabled || assume_yes_enabled; then
        printf 'EasyTier：未安装，将自动安装\n'
        install_easytier
        return 0
    fi

    if is_tty; then
        printf 'EasyTier：未安装，可自动安装\n'
        if [[ "$(prompt_yes_no "是否现在自动下载并安装 EasyTier" "true")" == "true" ]]; then
            install_easytier
            return 0
        fi
        log_warn "未安装 EasyTier，当前线路无法启动。稍后可运行："
        printf '  bash install.sh install-easytier\n' >&2
        return 1
    fi

    die_user "easytier-core 不存在。非交互模式请先运行：bash install.sh install-easytier，或设置 IXTF_ASSUME_YES=true / IXTF_AUTO_INSTALL_EASYTIER=true。"
}

install_nftables() {
    if command_exists nft; then
        return 0
    fi

    command_exists apt-get || die_user "未找到 nft 命令，且系统没有 apt-get。请手动安装 nftables。"
    log_info "正在安装 nftables。"
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y nftables
    command_exists nft || die_user "nftables 安装后仍未找到 nft 命令。"
}

mode_nat_transit="nat-transit"
mode_nat_ingress="nat-ingress"

preflight_mode_label() {
    case "${1:-all}" in
        nat-ingress|ingress) printf '公网入口线路\n' ;;
        nat-transit) printf 'NAT IX 中转线路\n' ;;
        landing|nat-transit) printf 'NAT IX 中转线路\n' ;;
        all) printf '完整环境\n' ;;
        *) printf '%s\n' "${1:-完整环境}" ;;
    esac
}

preflight_check() {
    require_root "$@"
    local mode="${1:-all}" missing_core=0 cmd nft_required="false" network_missing=0
    printf 'ix-transit-fabric 环境预检\n'
    printf '预检类型：%s\n' "$(preflight_mode_label "$mode")"
    printf '说明：仅检查环境，不会修改配置或 nftables。\n'

    preflight_line() {
        local item="$1" detail="$2"
        printf '%s：%s\n' "$item" "$detail"
    }

    preflight_debug_line() {
        debug_enabled || return 0
        local status="$1" item="$2" detail="${3:-}"
        if [[ -n "$detail" ]]; then
            printf '[%s] %s: %s\n' "$status" "$item" "$detail"
        else
            printf '[%s] %s\n' "$status" "$item"
        fi
    }

    if command_exists systemctl; then
        preflight_line "系统服务管理" "正常"
        preflight_debug_line OK "systemctl" "$(command -v systemctl 2>/dev/null || true)"
    else
        preflight_line "系统服务管理" "不可用，请先安装 systemd/systemctl"
        preflight_debug_line ERROR "systemctl" "missing"
        missing_core=$((missing_core + 1))
    fi

    for cmd in ip ss; do
        if command_exists "$cmd"; then
            preflight_debug_line OK "$cmd" "$(command -v "$cmd" 2>/dev/null || true)"
        else
            preflight_debug_line ERROR "$cmd" "missing"
            network_missing=$((network_missing + 1))
        fi
    done
    if [[ "$network_missing" -eq 0 ]]; then
        preflight_line "网络工具" "正常"
    else
        preflight_line "网络工具" "不可用，请先安装 iproute2"
        missing_core=$((missing_core + 1))
    fi

    case "$mode" in
        ingress|nat-ingress|nat-transit|all) nft_required="true" ;;
    esac
    if [[ "$nft_required" == "true" ]]; then
        if command_exists nft; then
            preflight_line "防火墙工具" "正常"
            preflight_debug_line OK "nft" "$(command -v nft 2>/dev/null || true)"
        elif command_exists apt-get; then
            preflight_line "防火墙工具" "未安装，将在安装线路时自动安装"
            preflight_debug_line WARN "nftables" "missing; apt-get available"
        else
            preflight_line "防火墙工具" "不可用，请先手动安装 nftables"
            preflight_debug_line ERROR "nft" "${mode} requires nftables"
            missing_core=$((missing_core + 1))
        fi
    else
        if command_exists nft; then
            preflight_line "防火墙工具" "正常"
            preflight_debug_line OK "nft" "$(command -v nft 2>/dev/null || true)"
        else
            preflight_line "防火墙工具" "未安装，当前预检可继续"
            preflight_debug_line INFO "nft" "landing-only can install later"
        fi
    fi
    if command_exists curl || command_exists wget; then
        preflight_line "下载工具" "正常"
        preflight_debug_line OK "curl/wget" "available"
    else
        preflight_line "下载工具" "不可用，请先安装 curl 或 wget"
        preflight_debug_line ERROR "curl/wget" "missing"
        missing_core=$((missing_core + 1))
    fi
    if command_exists tar; then
        preflight_debug_line OK "tar" "$(command -v tar 2>/dev/null || true)"
    else
        preflight_debug_line ERROR "tar" "missing"
        missing_core=$((missing_core + 1))
    fi
    if command_exists tar && command_exists unzip; then
        preflight_line "解压工具" "正常"
        preflight_debug_line OK "unzip" "$(command -v unzip 2>/dev/null || true)"
    elif command_exists tar; then
        preflight_line "解压工具" "tar 正常，unzip 未安装（zip 包需要时请安装）"
        preflight_debug_line WARN "unzip" "zip release package needs unzip"
    else
        preflight_line "解压工具" "不可用，请先安装 tar"
    fi
    if detect_easytier_binary >/dev/null 2>&1; then
        preflight_line "EasyTier" "正常"
        preflight_debug_line OK "easytier-core" "$(detect_easytier_binary)"
    else
        preflight_line "EasyTier" "未安装，将自动安装"
        preflight_debug_line INFO "easytier-core" "missing; install when needed"
    fi
    if detect_nc_cmd >/dev/null 2>&1; then
        preflight_line "诊断工具" "正常"
        preflight_debug_line OK "nc/ncat" "$(detect_nc_cmd)"
    else
        preflight_line "诊断工具" "未安装，可稍后运行 bash install.sh install-netcat"
        preflight_debug_line INFO "nc/ncat" "missing; run bash install.sh install-netcat"
    fi
    if [[ "$missing_core" -gt 0 ]]; then
        printf '预检结果：未通过（核心依赖问题：%s）\n' "$missing_core"
        debug_enabled && printf 'preflight result: core dependency issue(s)=%s\n' "$missing_core"
        return 1
    fi
    printf '预检结果：通过\n'
    debug_enabled && printf 'preflight result: OK\n'
}

run_profile_install_preflight() {
    local mode="${1:-all}"
    preflight_check "$mode" || true
    case "$mode" in
        ingress|nat-ingress|nat-transit)
            if ! command_exists nft && ! is_interactive_input && ! assume_yes_enabled; then
                die_user "${mode} 缺少 nftables。非交互模式请先显式安装依赖：bash install.sh install-diagnostics-tools，或手动 apt install -y nftables。"
            fi
            ;;
    esac
    ensure_easytier
    ensure_nc_tool
}

validate_port() {
    local value="$1"
    [[ "$value" =~ ^[0-9]{1,5}$ ]] || return 1
    local port=$((10#$value))
    (( port >= 1 && port <= 65535 ))
}

ports_equal() {
    validate_port "${1:-}" || return 1
    validate_port "${2:-}" || return 1
    (( 10#$1 == 10#$2 ))
}

validate_network_name() {
    local value="$1"
    [[ "$value" =~ ^[A-Za-z0-9._-]{1,64}$ ]]
}

validate_secret() {
    local value="$1"
    [[ ${#value} -ge 12 && ${#value} -le 256 ]] || return 1
    [[ "$value" =~ ^[A-Za-z0-9._~:@%+=,/-]+$ ]]
}

validate_hostname_value() {
    local value="$1"
    [[ "$value" =~ ^[A-Za-z0-9._-]{1,64}$ ]]
}

validate_ipv4() {
    local value="$1"
    local a b c d part
    IFS=. read -r a b c d <<<"$value"
    [[ -n "${a:-}" && -n "${b:-}" && -n "${c:-}" && -n "${d:-}" ]] || return 1
    for part in "$a" "$b" "$c" "$d"; do
        [[ "$part" =~ ^[0-9]{1,3}$ ]] || return 1
        (( 10#$part >= 0 && 10#$part <= 255 )) || return 1
    done
}

validate_ipv4_cidr() {
    local value="$1"
    [[ "$value" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]] || return 1
    local ip="${value%/*}"
    local prefix="${value##*/}"
    validate_ipv4 "$ip" || return 1
    (( 10#$prefix >= 0 && 10#$prefix <= 32 ))
}

ipv4_to_int() {
    local ip="$1" a b c d
    validate_ipv4 "$ip" || return 1
    IFS=. read -r a b c d <<<"$ip"
    printf '%s\n' $(( (10#$a << 24) + (10#$b << 16) + (10#$c << 8) + 10#$d ))
}

cidr_network24() {
    local cidr="$1" ip a b c d
    validate_ipv4_cidr "$cidr" || return 1
    ip="${cidr%/*}"
    IFS=. read -r a b c d <<<"$ip"
    printf '%s.%s.%s.0/24\n' "$((10#$a))" "$((10#$b))" "$((10#$c))"
}

cidr_prefix() {
    local cidr="$1"
    validate_ipv4_cidr "$cidr" || return 1
    printf '%s\n' "${cidr##*/}"
}

ip_from_cidr_host() {
    local cidr="$1" host="$2" ip a b c d
    validate_ipv4_cidr "$cidr" || return 1
    [[ "$host" =~ ^[0-9]{1,3}$ ]] || return 1
    (( 10#$host >= 1 && 10#$host <= 254 )) || return 1
    ip="${cidr%/*}"
    IFS=. read -r a b c d <<<"$ip"
    printf '%s.%s.%s.%s\n' "$((10#$a))" "$((10#$b))" "$((10#$c))" "$((10#$host))"
}

cidr_from_subnet_host() {
    local subnet="$1" host="$2" prefix ip
    prefix="$(cidr_prefix "$subnet")" || return 1
    ip="$(ip_from_cidr_host "$subnet" "$host")" || return 1
    printf '%s/%s\n' "$ip" "$prefix"
}

same_ipv4_subnet24() {
    local a="$1" b="$2" an bn
    an="$(cidr_network24 "$a")" || return 1
    bn="$(cidr_network24 "$b")" || return 1
    [[ "$an" == "$bn" ]]
}

is_reserved_private_subnet() {
    local subnet="$1"
    case "$subnet" in
        10.0.0.0/24|10.8.0.0/24|10.10.10.0/24|10.144.144.0/24|192.168.*|172.16.*|172.17.*|172.18.*|172.19.*|172.20.*|172.21.*|172.22.*|172.23.*|172.24.*|172.25.*|172.26.*|172.27.*|172.28.*|172.29.*|172.30.*|172.31.*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

subnet_conflicts_local_routes() {
    local subnet="$1" net
    command_exists ip || return 1
    net="${subnet%/24}"
    ip route 2>/dev/null | grep -Fq "$net"
}

generate_et_subnet() {
    local tries=0 b c subnet
    while (( tries < 60 )); do
        b=$((64 + (0x$(random_hex 1) % 64)))
        c=$((0x$(random_hex 1)))
        subnet="10.${b}.${c}.0/24"
        if ! is_reserved_private_subnet "$subnet" && ! subnet_conflicts_local_routes "$subnet"; then
            printf '%s\n' "$subnet"
            return 0
        fi
        tries=$((tries + 1))
    done
    printf '10.%s.%s.0/24\n' "$((64 + ($$ % 64)))" "$((($(date +%s) + $$) % 255))"
}

generate_landing_et_ip() {
    local subnet="${1:-}"
    [[ -n "$subnet" ]] || subnet="$(generate_et_subnet)"
    cidr_from_subnet_host "$subnet" 2
}

generate_ingress_et_ip() {
    local subnet="${1:-}"
    [[ -n "$subnet" ]] || subnet="$(generate_et_subnet)"
    cidr_from_subnet_host "$subnet" 1
}

validate_et_cidr_pair() {
    local landing_cidr="$1" ingress_cidr="$2" landing_ip ingress_ip
    validate_ipv4_cidr "$landing_cidr" || return 1
    validate_ipv4_cidr "$ingress_cidr" || return 1
    same_ipv4_subnet24 "$landing_cidr" "$ingress_cidr" || return 1
    landing_ip="${landing_cidr%/*}"
    ingress_ip="${ingress_cidr%/*}"
    [[ "$landing_ip" != "$ingress_ip" ]]
}

validate_host() {
    local value="$1"
    [[ -n "$value" ]] || return 1
    [[ "$value" =~ ^[A-Za-z0-9.-]{1,253}$ ]]
}

detect_public_ipv4() {
    local value url output
    for value in "${IXTF_PUBLIC_IP:-}" "${IXTF_INGRESS_PUBLIC_HOST:-}"; do
        value="$(trim_space "$value")"
        if validate_ipv4 "$value"; then
            printf '%s\n' "$value"
            return 0
        fi
    done

    for url in \
        https://api.ipify.org \
        https://ifconfig.me \
        https://icanhazip.com; do
        output=""
        if command_exists curl; then
            output="$(curl -4 -fsS --max-time 5 "$url" 2>/dev/null | sed -n '1p' | tr -d '\r' || true)"
        elif command_exists wget; then
            output="$(wget -4 -qO- --timeout=5 "$url" 2>/dev/null | sed -n '1p' | tr -d '\r' || true)"
        else
            return 1
        fi
        output="$(trim_space "$output")"
        if validate_ipv4 "$output"; then
            printf '%s\n' "$output"
            return 0
        fi
    done
    return 1
}

detect_public_host() {
    local value detected
    value="$(trim_space "${IXTF_PUBLIC_IP:-}")"
    if validate_ipv4 "$value"; then
        printf '%s\n' "$value"
        return 0
    fi
    value="$(trim_space "${IXTF_INGRESS_PUBLIC_HOST:-}")"
    if validate_host "$value"; then
        printf '%s\n' "$value"
        return 0
    fi
    if detected="$(detect_public_ipv4)"; then
        printf '%s\n' "$detected"
        return 0
    fi
    return 1
}

detect_env_ingress_public_host() {
    local value
    value="$(trim_space "${IXTF_PUBLIC_IP:-}")"
    if validate_ipv4 "$value"; then
        printf '%s\n' "$value"
        return 0
    fi
    value="$(trim_space "${IXTF_INGRESS_PUBLIC_HOST:-}")"
    if validate_host "$value"; then
        printf '%s\n' "$value"
        return 0
    fi
    return 1
}

suggest_ingress_public_host() {
    local detected
    if detected="$(detect_public_host)"; then
        printf '%s\n' "$detected"
        return 0
    fi
    printf 'localhost\n'
}

random_hex() {
    local bytes="${1:-2}"
    if [[ -r /dev/urandom ]]; then
        od -An -N"$bytes" -tx1 /dev/urandom 2>/dev/null | tr -d ' \n'
    else
        printf '%x%x\n' "$$" "$(date +%s)"
    fi
}

generate_network_name() {
    printf 'ix-%s\n' "$(random_hex 2)"
}

generate_profile_id() {
    local prefix="${1:-line}"
    prefix="${prefix,,}"
    prefix="${prefix//[^a-z0-9-]/}"
    [[ -n "$prefix" ]] || prefix="line"
    printf '%s-%s\n' "$prefix" "$(random_hex 2)"
}

generate_unique_profile_id() {
    local prefix="${1:-line}" id attempt
    for attempt in $(seq 1 30); do
        id="$(generate_profile_id "$prefix")"
        if [[ ! -e "$(profile_env_path "$id" 2>/dev/null || printf '%s/%s.env' "$PROFILES_DIR" "$id")" ]]; then
            printf '%s\n' "$id"
            return 0
        fi
    done
    return 1
}

validate_profile_id() {
    local value="$1"
    [[ "$value" =~ ^[a-z0-9-]{3,32}$ ]] || return 1
    [[ "$value" != */* && "$value" != *' '* ]]
}

validate_rule_id() {
    local value="$1"
    [[ "$value" =~ ^[a-z0-9-]{3,32}$ ]] || return 1
    [[ "$value" != */* && "$value" != *' '* ]]
}

profile_env_path() {
    local profile_id="$1"
    validate_profile_id "$profile_id" || return 1
    printf '%s/%s.env\n' "$PROFILES_DIR" "$profile_id"
}

profile_rules_dir() {
    local profile_id="$1"
    validate_profile_id "$profile_id" || return 1
    printf '%s/%s\n' "$RULES_DIR" "$profile_id"
}

rule_env_path() {
    local profile_id="$1" rule_id="$2"
    validate_profile_id "$profile_id" || return 1
    validate_rule_id "$rule_id" || return 1
    printf '%s/%s/%s.env\n' "$RULES_DIR" "$profile_id" "$rule_id"
}

profile_code_path() {
    local profile_id="$1"
    validate_profile_id "$profile_id" || return 1
    printf '%s/%s.code\n' "$CODES_DIR" "$profile_id"
}

profile_service_name() {
    local profile_id="$1"
    validate_profile_id "$profile_id" || return 1
    printf 'ix-transit-easytier@%s.service\n' "$profile_id"
}

profile_ids() {
    local file base
    [[ -d "$PROFILES_DIR" ]] || return 0
    for file in "$PROFILES_DIR"/*.env; do
        [[ -e "$file" ]] || continue
        base="$(basename "$file" .env)"
        validate_profile_id "$base" || continue
        printf '%s\n' "$base"
    done | sort
}

profile_count() {
    profile_ids | awk 'NF{c++} END{print c+0}'
}

clear_rule_vars() {
    local key
    for key in RULE_ID RULE_NOTE RULE_ENABLED CLIENT_PORT NAT_PUBLIC_PORT TRANSIT_PORT LANDING_HOST LANDING_PORT FORWARD_PROTO CREATED_AT UPDATED_AT LANDING_IP; do
        unset "$key" 2>/dev/null || true
    done
}

profile_supports_forward_rules() {
    case "${ROLE:-}" in
        nat-ingress|nat-transit) return 0 ;;
        *) return 1 ;;
    esac
}

profile_has_legacy_rule_fields() {
    case "${ROLE:-}" in
        nat-ingress)
            [[ -n "${LOCAL_PORT:-}" && -n "${TRANSIT_PORT:-}" && -n "${FORWARD_PROTO:-}" ]]
            ;;
        nat-transit)
            [[ -n "${TRANSIT_PORT:-}" && -n "${LANDING_HOST:-}" && -n "${LANDING_PORT:-}" && -n "${FORWARD_PROTO:-}" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

profile_rule_files_count() {
    local profile_id="$1" dir count=0 file base
    dir="$(profile_rules_dir "$profile_id")" || return 0
    [[ -d "$dir" ]] || { printf '0\n'; return 0; }
    for file in "$dir"/*.env; do
        [[ -e "$file" ]] || continue
        base="$(basename "$file" .env)"
        validate_rule_id "$base" || continue
        count=$((count + 1))
    done
    printf '%s\n' "$count"
}

profile_rule_ids() {
    local profile_id="$1" dir file base
    validate_profile_id "$profile_id" || return 1
    dir="$(profile_rules_dir "$profile_id")"
    if [[ -d "$dir" ]]; then
        for file in "$dir"/*.env; do
            [[ -e "$file" ]] || continue
            base="$(basename "$file" .env)"
            validate_rule_id "$base" || continue
            printf '%s\n' "$base"
        done | sort | awk '
            $0 == "rule-main" { main = 1; next }
            { other[++count] = $0 }
            END {
                if (main) print "rule-main"
                for (i = 1; i <= count; i++) print other[i]
            }
        '
    fi
    if [[ ! -d "$dir" && "$(profile_rule_files_count "$profile_id")" -eq 0 ]] && profile_supports_forward_rules && profile_has_legacy_rule_fields; then
        printf 'rule-main\n'
    fi
}

load_rule_from_path() {
    local path="$1" line key value
    clear_rule_vars
    [[ -f "$path" && -r "$path" ]] || return 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
        [[ "$line" == *=* ]] || continue
        key="$(trim_space "${line%%=*}")"
        value="$(trim_space "${line#*=}")"
        value="$(strip_optional_quotes "$value")"
        case "$key" in
            RULE_ID|RULE_NOTE|RULE_ENABLED|CLIENT_PORT|NAT_PUBLIC_PORT|TRANSIT_PORT|LANDING_HOST|LANDING_PORT|FORWARD_PROTO|CREATED_AT|UPDATED_AT|LANDING_IP)
                printf -v "$key" '%s' "$value"
                ;;
        esac
    done <"$path"
}

load_legacy_rule() {
    local rule_id="$1"
    local profile_client="${LOCAL_PORT:-}" profile_nat_public="${NAT_PUBLIC_PORT:-${NAT_LISTENER_PORT:-}}" profile_transit="${TRANSIT_PORT:-}" profile_landing_host="${LANDING_HOST:-}" profile_landing_port="${LANDING_PORT:-}" profile_proto="${FORWARD_PROTO:-both}" profile_created="${CREATED_AT:-}" profile_updated="${UPDATED_AT:-}"
    clear_rule_vars
    RULE_ID="$rule_id"
    RULE_NOTE="${RULE_NOTE:-默认转发}"
    RULE_ENABLED="${FORWARD_ENABLED:-true}"
    CLIENT_PORT="$profile_client"
    NAT_PUBLIC_PORT="$profile_nat_public"
    TRANSIT_PORT="$profile_transit"
    LANDING_HOST="$profile_landing_host"
    LANDING_PORT="$profile_landing_port"
    FORWARD_PROTO="$profile_proto"
    CREATED_AT="$profile_created"
    UPDATED_AT="$profile_updated"
}

load_rule() {
    local profile_id="$1" rule_id="$2" path dir
    validate_profile_id "$profile_id" || return 1
    validate_rule_id "$rule_id" || return 1
    path="$(rule_env_path "$profile_id" "$rule_id")" || return 1
    dir="$(profile_rules_dir "$profile_id")" || return 1
    if [[ -f "$path" ]]; then
        load_rule_from_path "$path" || return 1
    elif [[ "$rule_id" == "rule-main" && ! -d "$dir" ]] && profile_has_legacy_rule_fields; then
        load_legacy_rule "$rule_id"
    else
        return 1
    fi
    RULE_ID="${RULE_ID:-$rule_id}"
    if [[ -z "${RULE_NOTE+x}" ]]; then
        if [[ "$rule_id" == "rule-main" ]]; then
            RULE_NOTE="默认转发"
        else
            RULE_NOTE=""
        fi
    fi
    RULE_ENABLED="${RULE_ENABLED:-true}"
    FORWARD_PROTO="$(normalize_forward_proto "${FORWARD_PROTO:-both}" "both" 2>/dev/null || printf 'both\n')"
}

save_rule_env() {
    local profile_id="$1" rule_id="${2:-${RULE_ID:-}}" path dir tmp now
    validate_profile_id "$profile_id" || die_user "PROFILE_ID 格式不正确：${profile_id}"
    validate_rule_id "$rule_id" || die_user "RULE_ID 格式不正确：${rule_id}"
    RULE_ID="$rule_id"
    validate_rule_config_current
    check_rule_port_conflicts_for_save "$profile_id" "$rule_id"
    ensure_profile_dirs
    dir="$(profile_rules_dir "$profile_id")"
    install -d -m 700 "$dir"
    path="$(rule_env_path "$profile_id" "$rule_id")"
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    CREATED_AT="${CREATED_AT:-$now}"
    UPDATED_AT="$now"
    RULE_NOTE="${RULE_NOTE:-}"
    RULE_ENABLED="${RULE_ENABLED:-true}"
    tmp="$(make_tmp_file "ix-transit-fabric.rule")"
    chmod 600 "$tmp"
    {
        printf '# Managed by ix-transit-fabric forwarding rule. Do not share this file.\n'
        printf 'RULE_ID=%s\n' "$RULE_ID"
        printf 'RULE_NOTE=%s\n' "$(quote_env_value "$RULE_NOTE")"
        printf 'RULE_ENABLED=%s\n' "$RULE_ENABLED"
        [[ -n "${CLIENT_PORT:-}" ]] && printf 'CLIENT_PORT=%s\n' "$CLIENT_PORT"
        [[ -n "${NAT_PUBLIC_PORT:-}" ]] && printf 'NAT_PUBLIC_PORT=%s\n' "$NAT_PUBLIC_PORT"
        printf 'TRANSIT_PORT=%s\n' "$TRANSIT_PORT"
        printf 'LANDING_HOST=%s\n' "$(quote_env_value "${LANDING_HOST:-}")"
        [[ -n "${LANDING_PORT:-}" ]] && printf 'LANDING_PORT=%s\n' "$LANDING_PORT"
        [[ -n "${LANDING_IP:-}" ]] && printf 'LANDING_IP=%s\n' "$LANDING_IP"
        printf 'FORWARD_PROTO=%s\n' "${FORWARD_PROTO:-both}"
        printf 'CREATED_AT=%s\n' "$CREATED_AT"
        printf 'UPDATED_AT=%s\n' "$UPDATED_AT"
    } >"$tmp"
    backup_file "$path"
    mv -f -- "$tmp" "$path"
    chmod 600 "$path"
}

validate_rule_config_current() {
    [[ -n "${RULE_ID:-}" ]] || die_user "规则缺少 RULE_ID。"
    validate_rule_id "$RULE_ID" || die_user "RULE_ID 格式不正确：${RULE_ID}"
    case "${RULE_ENABLED:-true}" in true|false) ;; *) die_user "RULE_ENABLED 只能是 true 或 false。" ;; esac
    [[ -n "${TRANSIT_PORT:-}" ]] || die_user "规则缺少 TRANSIT_PORT。"
    validate_port "$TRANSIT_PORT" || die_user "TRANSIT_PORT 必须是 1-65535 的端口。"
    if [[ -n "${CLIENT_PORT:-}" ]]; then
        validate_port "$CLIENT_PORT" || die_user "CLIENT_PORT 必须是 1-65535 的端口。"
    fi
    if [[ -n "${NAT_PUBLIC_PORT:-}" ]]; then
        validate_port "$NAT_PUBLIC_PORT" || die_user "NAT_PUBLIC_PORT 必须是 1-65535 的端口。"
    fi
    if [[ -n "${LANDING_HOST:-}" ]]; then
        validate_host "$LANDING_HOST" || die_user "LANDING_HOST 必须是 IPv4 或域名。"
    fi
    if [[ -n "${LANDING_PORT:-}" ]]; then
        validate_port "$LANDING_PORT" || die_user "LANDING_PORT 必须是 1-65535 的端口。"
    fi
    FORWARD_PROTO="$(normalize_forward_proto "${FORWARD_PROTO:-both}" "both")" || die_user "FORWARD_PROTO 只能是 tcp、udp 或 both。"
}

ensure_default_rule_for_profile() {
    local profile_id="$1" dir count saved_client saved_nat_public saved_transit saved_landing_host saved_landing_port saved_proto saved_forward saved_created
    validate_profile_id "$profile_id" || return 1
    profile_supports_forward_rules || return 0
    profile_has_legacy_rule_fields || return 0
    dir="$(profile_rules_dir "$profile_id")" || return 1
    [[ ! -d "$dir" ]] || return 0
    count="$(profile_rule_files_count "$profile_id")"
    [[ "$count" -eq 0 ]] || return 0
    saved_client="${LOCAL_PORT:-}"
    saved_nat_public="${NAT_PUBLIC_PORT:-${NAT_LISTENER_PORT:-}}"
    saved_transit="${TRANSIT_PORT:-}"
    saved_landing_host="${LANDING_HOST:-}"
    saved_landing_port="${LANDING_PORT:-}"
    saved_proto="${FORWARD_PROTO:-both}"
    saved_forward="${FORWARD_ENABLED:-true}"
    saved_created="${CREATED_AT:-}"
    RULE_ID="rule-main"
    RULE_NOTE="默认转发"
    RULE_ENABLED="$saved_forward"
    CLIENT_PORT="$saved_client"
    NAT_PUBLIC_PORT="$saved_nat_public"
    TRANSIT_PORT="$saved_transit"
    LANDING_HOST="$saved_landing_host"
    LANDING_PORT="$saved_landing_port"
    FORWARD_PROTO="$saved_proto"
    CREATED_AT="$saved_created"
    save_rule_env "$profile_id" "rule-main"
    LOCAL_PORT="$saved_client"
    NAT_PUBLIC_PORT="$saved_nat_public"
    TRANSIT_PORT="$saved_transit"
    LANDING_HOST="$saved_landing_host"
    LANDING_PORT="$saved_landing_port"
    FORWARD_PROTO="$saved_proto"
    FORWARD_ENABLED="$saved_forward"
}

check_profile_rule_conflicts() {
    local profile_id="${1:-${PROFILE_ID:-}}" rule_id seen_client=" " seen_transit=" " seen_nat_public=" " nat_public
    local saved_nat_public="${NAT_PUBLIC_PORT:-}" saved_transit="${TRANSIT_PORT:-}" saved_landing_host="${LANDING_HOST:-}" saved_landing_port="${LANDING_PORT:-}" saved_proto="${FORWARD_PROTO:-}" saved_local="${LOCAL_PORT:-}"
    validate_profile_id "$profile_id" || die_user "PROFILE_ID 格式不正确：${profile_id}"
    profile_supports_forward_rules || return 0
    for rule_id in $(profile_rule_ids "$profile_id"); do
        load_rule "$profile_id" "$rule_id" || continue
        validate_rule_config_current
        if [[ "${RULE_ENABLED:-true}" == "true" && -n "${CLIENT_PORT:-}" ]]; then
            if [[ "$seen_client" == *" ${CLIENT_PORT} "* ]]; then
                die_user "同一线路下客户端入口端口冲突：${CLIENT_PORT}"
            fi
            seen_client="${seen_client}${CLIENT_PORT} "
        fi
        if [[ "${RULE_ENABLED:-true}" == "true" && -n "${TRANSIT_PORT:-}" ]]; then
            if [[ "$seen_transit" == *" ${TRANSIT_PORT} "* ]]; then
                die_user "同一线路下虚拟网中转端口冲突：${TRANSIT_PORT}"
            fi
            seen_transit="${seen_transit}${TRANSIT_PORT} "
        fi
        if [[ "${ROLE:-}" == "nat-transit" && "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" && "${RULE_ENABLED:-true}" == "true" ]]; then
            nat_public="$(rule_nat_public_port_value 2>/dev/null || true)"
            [[ -n "$nat_public" ]] || die_user "规则缺少 NAT_PUBLIC_PORT：${rule_id}"
            validate_port "$nat_public" || die_user "NAT_PUBLIC_PORT 必须是 1-65535 的端口：${rule_id}"
            if [[ "$seen_nat_public" == *" ${nat_public} "* ]]; then
                die_user "同一线路下商家入口端口冲突：${nat_public}"
            fi
            seen_nat_public="${seen_nat_public}${nat_public} "
        fi
        if [[ "${ROLE:-}" == "nat-ingress" && "${RULE_ENABLED:-true}" == "true" && -n "${CLIENT_PORT:-}" ]] && is_port_in_use "$CLIENT_PORT"; then
            log_warn "CLIENT_PORT ${CLIENT_PORT} 已被本机进程监听，可能和 nftables DNAT 冲突。"
            show_port_owner "$CLIENT_PORT" >&2
        fi
    done
    NAT_PUBLIC_PORT="$saved_nat_public"
    TRANSIT_PORT="$saved_transit"
    LANDING_HOST="$saved_landing_host"
    LANDING_PORT="$saved_landing_port"
    FORWARD_PROTO="$saved_proto"
    LOCAL_PORT="$saved_local"
}

current_profile_forward_transit_ports() {
    local profile_id="${1:-${PROFILE_ID:-}}" rule_id
    local saved_rule_id="${RULE_ID:-}" saved_note="${RULE_NOTE:-}" saved_enabled="${RULE_ENABLED:-}" saved_client="${CLIENT_PORT:-}" saved_nat_public="${NAT_PUBLIC_PORT:-}"
    local saved_transit="${TRANSIT_PORT:-}" saved_landing_host="${LANDING_HOST:-}" saved_landing_port="${LANDING_PORT:-}" saved_proto="${FORWARD_PROTO:-both}" saved_created="${CREATED_AT:-}" saved_updated="${UPDATED_AT:-}"
    [[ "${ENABLED:-true}" == "true" && "${FORWARD_ENABLED:-true}" == "true" ]] || return 0
    case "${ROLE:-}" in
        nat-transit)
            for rule_id in $(profile_rule_ids "$profile_id"); do
                load_rule "$profile_id" "$rule_id" || continue
                [[ "${RULE_ENABLED:-true}" == "true" && -n "${TRANSIT_PORT:-}" ]] || continue
                printf '%s\n' "$TRANSIT_PORT"
            done
            ;;
    esac
    RULE_ID="$saved_rule_id"; RULE_NOTE="$saved_note"; RULE_ENABLED="$saved_enabled"; CLIENT_PORT="$saved_client"; NAT_PUBLIC_PORT="$saved_nat_public"; TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"; CREATED_AT="$saved_created"; UPDATED_AT="$saved_updated"
}

profile_forward_transit_ports_for_conflict() (
    local profile_id="$1"
    load_profile "$profile_id" >/dev/null 2>&1 || return 0
    current_profile_forward_transit_ports "$profile_id"
)

profile_uses_rule_port_for_conflict() {
    local profile_id="$1" field="$2" port="$3" except_rule="${4:-}" rule_id value
    port_used_by_profile_rule "$profile_id" "$field" "$port" "$except_rule" && return 0
    case "$field" in
        client)
            for other in $(profile_ids); do
                [[ "$other" == "$profile_id" ]] && continue
                while IFS= read -r value; do
                    [[ -n "$value" ]] || continue
                    [[ "$value" == "$port" ]] && return 0
                done < <(profile_forward_client_ports_for_conflict "$other")
            done
            ;;
        transit)
            [[ "${ROLE:-}" == "nat-transit" ]] || return 1
            for other in $(profile_ids); do
                [[ "$other" == "$profile_id" ]] && continue
                while IFS= read -r value; do
                    [[ -n "$value" ]] || continue
                    [[ "$value" == "$port" ]] && return 0
                done < <(profile_forward_transit_ports_for_conflict "$other")
            done
            ;;
        nat-public)
            [[ "${ROLE:-}" == "nat-transit" && "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]] || return 1
            ;;
    esac
    return 1
}

check_rule_port_conflicts_for_save() {
    local profile_id="$1" rule_id="$2" owner
    [[ "${RULE_ENABLED:-true}" == "true" ]] || return 0
    if [[ -n "${CLIENT_PORT:-}" ]] && profile_uses_rule_port_for_conflict "$profile_id" client "$CLIENT_PORT" "$rule_id"; then
        owner="$(format_rule_port_conflict_owner "$profile_id" client "$CLIENT_PORT" "$rule_id" 2>/dev/null || true)"
        if [[ -n "$owner" ]]; then
            die_user "端口 ${CLIENT_PORT} 已被${owner} 使用。"
        fi
        die_user "不允许两条规则共用一个 CLIENT_PORT：${CLIENT_PORT}"
    fi
    if [[ -n "${TRANSIT_PORT:-}" ]] && profile_uses_rule_port_for_conflict "$profile_id" transit "$TRANSIT_PORT" "$rule_id"; then
        owner="$(format_rule_port_conflict_owner "$profile_id" transit "$TRANSIT_PORT" "$rule_id" 2>/dev/null || true)"
        if [[ -n "$owner" ]]; then
            die_user "端口 ${TRANSIT_PORT} 已被${owner} 使用。"
        fi
        die_user "不允许两条规则共用一个 TRANSIT_PORT：${TRANSIT_PORT}"
    fi
    if [[ "${ROLE:-}" == "nat-transit" && "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
        local nat_public
        nat_public="$(rule_nat_public_port_value 2>/dev/null || true)"
        if [[ -n "$nat_public" ]] && profile_uses_rule_port_for_conflict "$profile_id" nat-public "$nat_public" "$rule_id"; then
            owner="$(format_rule_port_conflict_owner "$profile_id" nat-public "$nat_public" "$rule_id" 2>/dev/null || true)"
            if [[ -n "$owner" ]]; then
                die_user "端口 ${nat_public} 已被${owner} 使用。"
            fi
            die_user "不允许两条规则共用一个 NAT_PUBLIC_PORT：${nat_public}"
        fi
    fi
}

profile_hint_line() {
    local id="$1" role role_label
    if load_profile "$id" >/dev/null 2>&1; then
        case "${ROLE:-}" in
            nat-transit) role_label="nat-transit" ;;
            nat-ingress) role_label="nat-ingress" ;;
            *) role_label="${ROLE:-unknown}" ;;
        esac
    else
        role_label="unreadable"
    fi
    printf '  - %s %s\n' "$id" "$role_label" >&2
}

print_profile_selection_hint() {
    local requested="${1:-}" verb="${2:-health}" count id first_id=""
    count="$(profile_count)"
    if [[ -n "$requested" ]]; then
        printf '[ERROR] 未找到 Profile：%s\n' "$requested" >&2
    fi
    if [[ "$count" -gt 0 ]]; then
        printf '当前机器已有 Profile：\n' >&2
        for id in $(profile_ids); do
            [[ -n "$first_id" ]] || first_id="$id"
            profile_hint_line "$id"
        done
        printf '你可能想运行：\n' >&2
        printf '  bash install.sh %s %s\n' "$verb" "$first_id" >&2
        printf '也可以先运行：bash install.sh list-profiles\n' >&2
    else
        printf '当前机器没有任何 Profile。请先创建落地或入口 Profile。\n' >&2
        printf '可先运行：bash install.sh list-profiles\n' >&2
    fi
}

resolve_profile_id_for_cmd() {
    local requested="${1:-}" verb="${2:-health}" count only path
    if [[ -n "$requested" ]]; then
        if ! validate_profile_id "$requested"; then
            printf '[ERROR] PROFILE_ID 格式不正确：%s\n' "$requested" >&2
            return 2
        fi
        path="$(profile_env_path "$requested")" || return 2
        if [[ ! -f "$path" ]]; then
            print_profile_selection_hint "$requested" "$verb"
            return 2
        fi
        printf '%s\n' "$requested"
        return 0
    fi
    count="$(profile_count)"
    if [[ "$count" == "1" ]]; then
        only="$(profile_ids | head -n 1)"
        printf '%s\n' "$only"
        return 0
    fi
    if [[ "$count" == "0" && -f "$ENV_FILE" ]]; then
        printf 'default\n'
        return 0
    fi
    print_profile_selection_hint "" "$verb"
    return 2
}

resolve_profile_id() {
    local requested="${1:-}" count only
    if [[ -n "$requested" ]]; then
        validate_profile_id "$requested" || die_user "PROFILE_ID 格式不正确：${requested}"
        [[ -f "$(profile_env_path "$requested")" ]] || die_user "未找到 Profile：${requested}"
        printf '%s\n' "$requested"
        return 0
    fi
    count="$(profile_count)"
    if [[ "$count" == "1" ]]; then
        only="$(profile_ids | head -n 1)"
        printf '%s\n' "$only"
        return 0
    fi
    if [[ "$count" == "0" && -f "$ENV_FILE" ]]; then
        printf 'default\n'
        return 0
    fi
    printf '已有 Profile：\n' >&2
    profile_ids | sed 's/^/  - /' >&2
    die_user "请指定 PROFILE_ID。"
}

generate_secret() {
    if command_exists openssl; then
        openssl rand -hex 24
    elif [[ -r /dev/urandom ]]; then
        od -An -N24 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n'
    else
        printf 'ixtf%s%s\n' "$(date +%s)" "$$"
    fi
}

random_port() {
    local min="${1:-20000}"
    local max="${2:-60000}"
    local span=$((max - min + 1))
    local n
    if command_exists shuf; then
        shuf -i "${min}-${max}" -n 1
        return 0
    fi
    n=$((0x$(random_hex 2) % span + min))
    printf '%s\n' "$n"
}

is_port_reserved() {
    case "$1" in
        22|25|53|80|110|143|443|465|587|993|995|3306|5432|6379|8080|8443|3389|5900|11211|27017|9200|9300|51820|11010|11011|11012)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_easytier_common_port() {
    case "$1" in
        11010|11011|11012) return 0 ;;
        *) return 1 ;;
    esac
}

is_common_system_port() {
    case "$1" in
        22|25|53|80|110|143|443|465|587|993|995|3306|5432|6379|8080|8443|3389|5900|11211|27017|9200|9300|51820)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_port_in_use() {
    local port="$1"
    command_exists ss || return 1
    { ss -lntup 2>/dev/null || true; ss -lnuap 2>/dev/null || true; } | grep -Eq "[:.]${port}[[:space:]]"
}

is_tcp_port_listening() {
    local port="$1"
    command_exists ss || return 1
    ss -lntup 2>/dev/null | grep -Eq "[:.]${port}[[:space:]]"
}

is_udp_port_listening() {
    local port="$1"
    command_exists ss || return 1
    ss -lnuap 2>/dev/null | grep -Eq "[:.]${port}[[:space:]]"
}

show_port_owner() {
    local port="$1"
    if ! command_exists ss; then
        printf '[WARN] 未找到 ss 命令，无法显示端口占用进程。\n'
        return 0
    fi

    { ss -lntup 2>/dev/null || true; ss -lnuap 2>/dev/null || true; } | grep -E "[:.]${port}[[:space:]]" || true
}

validate_listener_port_available() {
    local proto="$1"
    local port="$2"
    local occupied="false" normalized list

    validate_port "$port" || return 1
    normalized="$(normalize_listener_proto "$proto" "both" 2>/dev/null || printf '%s\n' "$proto")"
    list="$(normalize_listener_protos "$normalized" "both" 2>/dev/null || printf '%s\n' "$normalized")"
    case "$normalized" in
        tcp)
            is_tcp_port_listening "$port" && occupied="true"
            ;;
        udp)
            is_udp_port_listening "$port" && occupied="true"
            ;;
        both|all)
            if is_tcp_port_listening "$port" || is_udp_port_listening "$port"; then
                occupied="true"
            fi
            ;;
        ws|wss)
            is_tcp_port_listening "$port" && occupied="true"
            ;;
        quic|wg)
            is_udp_port_listening "$port" && occupied="true"
            ;;
        *)
            return 1
            ;;
    esac

    if [[ "$occupied" == "true" ]]; then
        printf '[WARN] 当前端口已被占用，不能作为 EasyTier listener：%s/%s\n' "$(proto_list_display "$list")" "$port" >&2
        show_port_owner "$port" >&2
        return 1
    fi
    return 0
}

pick_random_port_excluding_listeners() {
    local proto="${1:-both}"
    local port tries=0
    while (( tries < 30 )); do
        port="$(random_port 20000 60000)"
        if ! is_port_reserved "$port" && validate_listener_port_available "$proto" "$port" >/dev/null 2>&1; then
            printf '%s\n' "$port"
            return 0
        fi
        tries=$((tries + 1))
    done
    return 1
}

pick_random_port() {
    local port tries=0
    while (( tries < 30 )); do
        port="$(random_port 20000 60000)"
        if ! is_port_reserved "$port" && ! is_port_in_use "$port"; then
            printf '%s\n' "$port"
            return 0
        fi
        tries=$((tries + 1))
    done
    return 1
}

proto_input_normalize() {
    local value="$1"
    value="$(trim_space "$value")"
    value="${value,,}"
    value="${value//+/ }"
    value="${value//\// }"
    value="${value//,/ }"
    value="$(printf '%s\n' "$value" | tr -s '[:space:]' ' ')"
    trim_space "$value"
}

is_supported_tunnel_proto() {
    case "${1:-}" in
        tcp|udp|ws|wss|quic|wg) return 0 ;;
        *) return 1 ;;
    esac
}

normalize_tunnel_proto() {
    local value="${1:-}"
    local default="${2:-both}"
    value="$(proto_input_normalize "$value")"
    [[ -n "$value" ]] || value="$default"

    case "$value" in
        tcp|udp|ws|wss|quic|wg) printf '%s\n' "$value" ;;
        both|"tcp udp"|"udp tcp") printf 'both\n' ;;
        all|"tcp udp ws wss quic wg"|"udp tcp ws wss quic wg") printf 'all\n' ;;
        *) return 1 ;;
    esac
}

normalize_proto_list() {
    local value="${1:-}" default="${2:-both}" normalized token seen=" " out=()
    normalized="$(normalize_tunnel_proto "$value" "$default")" || return 1
    case "$normalized" in
        both)
            printf 'tcp udp\n'
            ;;
        all)
            printf 'tcp udp ws wss quic wg\n'
            ;;
        *)
            for token in $normalized; do
                is_supported_tunnel_proto "$token" || return 1
                if [[ "$seen" != *" ${token} "* ]]; then
                    out+=("$token")
                    seen="${seen}${token} "
                fi
            done
            (IFS=' '; printf '%s\n' "${out[*]}")
            ;;
    esac
}

proto_list_to_value() {
    local list="$1"
    list="$(proto_input_normalize "$list")"
    case "$list" in
        "tcp udp"|"udp tcp") printf 'both\n' ;;
        "tcp udp ws wss quic wg") printf 'all\n' ;;
        *) printf '%s\n' "$list" ;;
    esac
}

normalize_listener_proto() {
    normalize_tunnel_proto "${1:-}" "${2:-both}"
}

normalize_listener_protos() {
    normalize_proto_list "${1:-}" "${2:-both}"
}

normalize_entry_proto() {
    normalize_tunnel_proto "${1:-}" "${2:-both}"
}

normalize_peer_protos() {
    normalize_proto_list "${1:-}" "${2:-both}"
}

normalize_forward_proto() {
    local value="${1:-}"
    local default="${2:-both}"
    value="$(proto_input_normalize "$value")"
    [[ -n "$value" ]] || value="$default"

    case "$value" in
        tcp|udp) printf '%s\n' "$value" ;;
        both|all|"tcp udp"|"udp tcp") printf 'both\n' ;;
        *) return 1 ;;
    esac
}

proto_display() {
    case "${1:-}" in
        tcp) printf 'TCP\n' ;;
        udp) printf 'UDP\n' ;;
        ws) printf 'WS\n' ;;
        wss) printf 'WSS\n' ;;
        quic) printf 'QUIC\n' ;;
        wg) printf 'WG\n' ;;
        both) printf 'TCP/UDP\n' ;;
        all) printf 'TCP/UDP/WS/WSS/QUIC/WG\n' ;;
        *) printf '%s\n' "${1:-未知}" ;;
    esac
}

proto_display_user() {
    case "${1:-}" in
        tcp) printf 'TCP' ;;
        udp) printf 'UDP' ;;
        ws) printf 'WebSocket' ;;
        wss) printf 'WebSocket TLS' ;;
        quic) printf 'QUIC' ;;
        wg) printf 'WireGuard' ;;
        both) printf 'TCP/UDP' ;;
        all) printf 'ALL' ;;
        *) printf '%s' "${1:-未知}" ;;
    esac
}

proto_list_display() {
    local value="${1:-}" list proto labels=()
    list="$(normalize_proto_list "$value" "both" 2>/dev/null || printf '%s\n' "$value")"
    for proto in $list; do
        labels+=("$(proto_display "$proto")")
    done
    (IFS='/'; printf '%s\n' "${labels[*]}")
}

easytier_supports_proto() {
    local proto="$1"
    is_supported_tunnel_proto "$proto"
}

render_listener_args() {
    local proto="$1" port="$2"
    easytier_supports_proto "$proto" || return 1
    printf '%s://0.0.0.0:%s\n' "$proto" "$port"
}

render_peer_args() {
    local proto="$1" host="$2" port="$3"
    easytier_supports_proto "$proto" || return 1
    printf '%s://%s:%s\n' "$proto" "$host" "$port"
}

listener_urls_value() {
    local proto="$1"
    local port="$2"
    local list item out=()
    list="$(normalize_listener_protos "$proto" "both")" || return 1
    for item in $list; do
        out+=("$(render_listener_args "$item" "$port")")
    done
    (IFS=' '; printf '%s\n' "${out[*]}")
}

peer_urls_value() {
    local proto="$1"
    local host="$2"
    local port="$3"
    local list item out=()
    list="$(normalize_peer_protos "$proto" "both")" || return 1
    for item in $list; do
        out+=("$(render_peer_args "$item" "$host" "$port")")
    done
    (IFS=' '; printf '%s\n' "${out[*]}")
}

normalize_nat_public_ports_input() {
    local raw="$1" token start end port seen=" " out=()
    local -a tokens
    raw="${raw//，/,}"
    raw="${raw//[[:space:]]/}"
    [[ -n "$raw" ]] || return 1
    IFS=',' read -r -a tokens <<<"$raw"
    for token in "${tokens[@]}"; do
        [[ -n "$token" ]] || return 1
        if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            start="${BASH_REMATCH[1]}"
            end="${BASH_REMATCH[2]}"
            validate_port "$start" || return 1
            validate_port "$end" || return 1
            [[ "$start" -le "$end" ]] || return 1
            for ((port=start; port<=end; port++)); do
                if [[ "$seen" != *" ${port} "* ]]; then
                    seen="${seen}${port} "
                    out+=("$port")
                fi
            done
        else
            validate_port "$token" || return 1
            if [[ "$seen" != *" ${token} "* ]]; then
                seen="${seen}${token} "
                out+=("$token")
            fi
        fi
    done
    [[ "${#out[@]}" -gt 0 ]] || return 1
    (IFS=','; printf '%s\n' "${out[*]}")
}

nat_public_port_mode_for_input() {
    local raw="$1"
    raw="${raw//，/,}"
    raw="${raw//[[:space:]]/}"
    if [[ "$raw" == *","* ]]; then
        printf 'list\n'
    elif [[ "$raw" =~ ^[0-9]+-[0-9]+$ ]]; then
        printf 'range\n'
    else
        printf 'single\n'
    fi
}

code_rules_nat_public_ports_csv() {
    local line rule_id note enabled nat_public_port transit_port landing_host landing_port forward_proto seen=" " out=()
    while IFS=$'\t' read -r rule_id note enabled nat_public_port transit_port landing_host landing_port forward_proto || [[ -n "${rule_id:-}" ]]; do
        [[ -n "${rule_id:-}" ]] || continue
        [[ "${enabled:-true}" == "true" ]] || continue
        [[ -n "${nat_public_port:-}" ]] || continue
        if [[ "$seen" != *" ${nat_public_port} "* ]]; then
            seen="${seen}${nat_public_port} "
            out+=("$nat_public_port")
        fi
    done <<<"${CODE_RULES_TSV:-}"
    [[ "${#out[@]}" -gt 0 ]] || return 1
    (IFS=','; printf '%s\n' "${out[*]}")
}

nat_public_port_spec_for_code() {
    if [[ -n "${NAT_PUBLIC_PORT_SPEC:-}" ]]; then
        printf '%s\n' "$NAT_PUBLIC_PORT_SPEC"
        return 0
    fi
    case "${NAT_PUBLIC_PORT_MODE:-single}" in
        range)
            local first last
            first="$(first_nat_public_port "${NAT_PUBLIC_PORTS:-${NAT_LISTENER_PORT:-}}" 2>/dev/null || true)"
            last="$(nat_public_ports_to_words "${NAT_PUBLIC_PORTS:-}" | tail -n 1)"
            if [[ -n "$first" && -n "$last" && "$first" != "$last" ]]; then
                printf '%s-%s\n' "$first" "$last"
                return 0
            fi
            ;;
    esac
    [[ -n "${NAT_LISTENER_PORT:-}" ]] && printf '%s\n' "$NAT_LISTENER_PORT" && return 0
    first_nat_public_port "${NAT_PUBLIC_PORTS:-}" 2>/dev/null
}

nat_public_ports_for_code_json() {
    case "${NAT_PUBLIC_PORT_MODE:-single}" in
        range) return 1 ;;
        single)
            [[ -n "${NAT_LISTENER_PORT:-}" ]] || NAT_LISTENER_PORT="$(first_nat_public_port "${NAT_PUBLIC_PORTS:-}" 2>/dev/null || true)"
            [[ -n "${NAT_LISTENER_PORT:-}" ]] || return 1
            printf '%s\n' "$NAT_LISTENER_PORT"
            ;;
        list)
            local count
            count="$(nat_public_ports_to_words "${NAT_PUBLIC_PORTS:-}" | awk 'NF{c++} END{print c+0}')"
            [[ "$count" -le 5 ]] || return 1
            printf '%s\n' "${NAT_PUBLIC_PORTS:-}"
            ;;
        *) return 1 ;;
    esac
}

et_peer_ports_csv() {
    local peers="${1:-${ET_PEERS:-}}" url port seen=" " out=()
    for url in $peers; do
        [[ -n "$url" ]] || continue
        port="${url##*:}"
        port="${port%%/*}"
        [[ -n "$port" ]] || continue
        validate_port "$port" 2>/dev/null || continue
        if [[ "$seen" != *" ${port} "* ]]; then
            seen="${seen}${port} "
            out+=("$port")
        fi
    done
    [[ "${#out[@]}" -gt 0 ]] || return 1
    (IFS=','; printf '%s\n' "${out[*]}")
}

et_peer_contains_port() {
    local want="$1" port
    while IFS= read -r port; do
        [[ "$port" == "$want" ]] && return 0
    done < <(nat_public_ports_to_words "$(et_peer_ports_csv 2>/dev/null || true)")
    return 1
}

easytier_urls_contain_port() {
    local want="$1" urls="${2:-}" url port
    for url in $urls; do
        [[ -n "$url" ]] || continue
        port="${url##*:}"
        port="${port%%/*}"
        [[ "$port" == "$want" ]] && return 0
    done
    return 1
}

easytier_url_list_count() {
    local urls="${1:-}" item count=0
    for item in $urls; do
        [[ -n "$item" ]] && count=$((count + 1))
    done
    printf '%s\n' "$count"
}

print_easytier_url_list() {
    local urls="${1:-}" item
    for item in $urls; do
        [[ -n "$item" ]] || continue
        printf '  %s\n' "$item"
    done
}

first_nat_public_port() {
    local ports="${1:-${NAT_PUBLIC_PORTS:-${NAT_LISTENER_PORT:-}}}" first
    ports="${ports//[[:space:]]/}"
    first="${ports%%,*}"
    [[ -n "$first" ]] || return 1
    printf '%s\n' "$first"
}

nat_public_ports_to_words() {
    local ports="${1:-}" port
    local -a port_list
    ports="${ports//[[:space:]]/}"
    IFS=',' read -r -a port_list <<<"$ports"
    for port in "${port_list[@]}"; do
        [[ -n "$port" ]] || continue
        printf '%s\n' "$port"
    done
}

listener_urls_for_ports_value() {
    local proto="$1" ports="$2" port urls url seen=" " out=()
    while IFS= read -r port; do
        validate_port "$port" || return 1
        urls="$(listener_urls_value "$proto" "$port")" || return 1
        for url in $urls; do
            if [[ "$seen" != *" ${url} "* ]]; then
                seen="${seen}${url} "
                out+=("$url")
            fi
        done
    done < <(nat_public_ports_to_words "$ports")
    [[ "${#out[@]}" -gt 0 ]] || return 1
    (IFS=' '; printf '%s\n' "${out[*]}")
}

peer_urls_for_ports_value() {
    local proto="$1" host="$2" ports="$3" port urls url seen=" " out=()
    while IFS= read -r port; do
        validate_port "$port" || return 1
        urls="$(peer_urls_value "$proto" "$host" "$port")" || return 1
        for url in $urls; do
            if [[ "$seen" != *" ${url} "* ]]; then
                seen="${seen}${url} "
                out+=("$url")
            fi
        done
    done < <(nat_public_ports_to_words "$ports")
    [[ "${#out[@]}" -gt 0 ]] || return 1
    (IFS=' '; printf '%s\n' "${out[*]}")
}

prompt_nat_public_ports() {
    local label="$1" default="${2:-}" value normalized
    require_tty
    PROMPT_NAT_PUBLIC_PORTS_NORMALIZED=""
    PROMPT_NAT_PUBLIC_PORT_RAW=""
    PROMPT_NAT_PUBLIC_PORT_MODE=""
    while true; do
        if [[ -n "$default" ]]; then
            printf '%s（可填单端口、端口段或逗号列表，默认 %s）：' "$label" "$default" >&2
        else
            printf '%s（可填单端口、端口段或逗号列表，例如 20000、20000-20010、20000,20002）：' "$label" >&2
        fi
        IFS= read -r value || return 1
        value="$(trim_space "${value%$'\r'}")"
        value="${value:-$default}"
        if normalized="$(normalize_nat_public_ports_input "$value")"; then
            PROMPT_NAT_PUBLIC_PORT_RAW="$value"
            PROMPT_NAT_PUBLIC_PORT_MODE="$(nat_public_port_mode_for_input "$value")"
            PROMPT_NAT_PUBLIC_PORTS_NORMALIZED="$normalized"
            return 0
        fi
        log_warn "商家入口端口必须是 1-65535 的单端口、端口段或逗号列表。"
    done
}

listener_protos_json() {
    local list proto first="true"
    list="$(normalize_listener_protos "${1:-}" "both")" || return 1
    printf '['
    for proto in $list; do
        [[ "$first" == "true" ]] || printf ','
        printf '"%s"' "$proto"
        first="false"
    done
    printf ']\n'
}

normalize_nat_direction() {
    case "${1:-ingress-listener}" in
        ingress-listener|"") printf 'ingress-listener\n' ;;
        nat-listener) printf 'nat-listener\n' ;;
        *) return 1 ;;
    esac
}

profile_uses_easytier_listener() {
    case "${ROLE:-}" in
        nat-transit)
            return 0
            ;;
        nat-ingress)
            [[ "${NAT_DIRECTION:-ingress-listener}" == "ingress-listener" ]]
            ;;
        nat-transit)
            [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

nat_direction_label() {
    case "${1:-ingress-listener}" in
        nat-listener) printf '推荐模式：NAT IX 机器监听，公网入口机连接 NAT IX\n' ;;
        *) printf '兼容旧模式：公网入口机监听，NAT IX 机器连接公网入口机\n' ;;
    esac
}

prompt_required() {
    local label="$1"
    local default="${2:-}"
    local value

    require_tty
    while true; do
        if [[ -n "$default" ]]; then
            printf '%s（默认 %s）：' "$label" "$default" >&2
        else
            printf '%s：' "$label" >&2
        fi
        IFS= read -r value || return 1
        value="${value:-$default}"
        if [[ -n "$value" ]]; then
            printf '%s\n' "$value"
            return 0
        fi
        log_warn "该项不能为空。"
    done
}

prompt_optional_text() {
    local label="$1" default="${2:-}" value
    require_tty
    if [[ -n "$default" ]]; then
        printf '%s（默认 %s，可留空）：' "$label" "$default" >&2
    else
        printf '%s（可留空）：' "$label" >&2
    fi
    IFS= read -r value || return 1
    value="${value:-$default}"
    printf '%s\n' "$value"
}

prompt_validated() {
    local label="$1"
    local default="$2"
    local validator="$3"
    local error_message="$4"
    local value

    while true; do
        value="$(prompt_required "$label" "$default")" || return 1
        if "$validator" "$value"; then
            printf '%s\n' "$value"
            return 0
        fi
        log_warn "$error_message"
    done
}

prompt_secret() {
    local first second

    require_tty
    while true; do
        printf '请输入 EasyTier 网络密钥（不会显示）：' >&2
        IFS= read -r -s first || return 1
        printf '\n' >&2
        printf '请再次输入 EasyTier 网络密钥：' >&2
        IFS= read -r -s second || return 1
        printf '\n' >&2

        if [[ "$first" != "$second" ]]; then
            log_warn "两次输入的网络密钥不一致。"
            continue
        fi
        if ! validate_secret "$first"; then
            log_warn "网络密钥至少 12 位，且只能包含字母、数字和 . _ ~ : @ % + = , / -。"
            continue
        fi
        printf '%s\n' "$first"
        return 0
    done
}

prompt_secret_default() {
    local generated="$1"
    local custom first second

    require_tty add-nat-listener-profile
    custom="$(prompt_yes_no "是否自定义 EasyTier 网络密钥" "false")" || return 1
    if [[ "$custom" != "true" ]]; then
        printf '%s\n' "$generated"
        return 0
    fi

    while true; do
        printf '请输入 EasyTier 网络密钥（不会显示）：' >&2
        IFS= read -r -s first || return 1
        printf '\n' >&2
        printf '请再次输入 EasyTier 网络密钥：' >&2
        IFS= read -r -s second || return 1
        printf '\n' >&2

        if [[ "$first" != "$second" ]]; then
            log_warn "两次输入的网络密钥不一致。"
            continue
        fi
        if ! validate_secret "$first"; then
            log_warn "网络密钥至少 12 位，且只能包含字母、数字和 . _ ~ : @ % + = , / -。"
            continue
        fi
        printf '%s\n' "$first"
        return 0
    done
}

prompt_port() {
    local label="$1"
    local default="${2:-}"
    prompt_validated "$label" "$default" validate_port "端口必须是 1-65535 之间的整数。"
}

prompt_random_port() {
    local label="$1"
    local default_port="${2:-}"

    if [[ -z "$default_port" ]]; then
        if ! default_port="$(pick_random_port)"; then
            log_warn "随机端口连续 30 次未找到可用值，请手动输入。"
            default_port=""
        fi
    fi

    if [[ -n "$default_port" ]]; then
        prompt_port "${label}（直接回车将使用随机未占用高端口）" "$default_port"
    else
        prompt_port "${label}（请手动输入 20000-60000 范围内未占用端口）" ""
    fi
}

prompt_listener_port() {
    local label="$1"
    local proto="$2"
    local default_port="${3:-}"
    local value generated_default="false"

    if [[ -z "$default_port" ]]; then
        if ! default_port="$(pick_random_port_excluding_listeners "$proto")"; then
            log_warn "随机 listener 端口连续 30 次未找到可用值，请手动输入。"
            default_port=""
        fi
        generated_default="true"
    fi

    require_tty
    while true; do
        if [[ -n "$default_port" ]]; then
            printf '%s（直接回车将使用随机未占用高端口，默认 %s）：' "$label" "$default_port" >&2
        else
            printf '%s（请手动输入 20000-60000 范围内未占用端口）：' "$label" >&2
        fi
        IFS= read -r value || return 1
        if [[ -z "$value" ]]; then
            if [[ -z "$default_port" ]]; then
                log_warn "端口不能为空。"
                continue
            fi
            value="$default_port"
        fi
        if ! validate_port "$value"; then
            log_warn "端口必须是 1-65535 之间的整数。"
            continue
        fi
        if validate_listener_port_available "$proto" "$value"; then
            printf '%s\n' "$value"
            return 0
        fi
        if [[ "$generated_default" == "true" && "$value" == "$default_port" ]]; then
            if default_port="$(pick_random_port_excluding_listeners "$proto")"; then
                log_warn "默认 listener 端口刚被占用，已重新选择：${default_port}"
                continue
            fi
        fi
        log_warn "当前端口已被占用，不能作为 EasyTier listener。请换一个端口。"
    done
}

prompt_optional_port() {
    local label="$1"
    local value

    require_tty
    while true; do
        printf '%s：' "$label" >&2
        IFS= read -r value || return 1
        if [[ -z "$value" ]]; then
            printf '\n'
            return 0
        fi
        if validate_port "$value"; then
            printf '%s\n' "$value"
            return 0
        fi
        log_warn "端口必须是 1-65535 之间的整数；留空表示跳过。"
    done
}

warn_if_remote_port_looks_like_tunnel_port() {
    local remote_port="$1"
    local listener_port="${2:-}"
    local cnix_entry_port="${3:-}"
    local local_port="${4:-}"
    local needs_confirm="false"

    if [[ -n "$listener_port" ]] && ports_equal "$remote_port" "$listener_port"; then
        cat >&2 <<EOF
[WARN] 你输入的是 EasyTier listener 端口，不是业务端口。
[WARN] REMOTE_PORT 是香港业务服务端口，例如 Xray/sing-box/Web 监听端口。
[WARN] 它不是 EasyTier listener 端口，也不是 CNIX 面板入口端口。
EOF
        needs_confirm="true"
    fi

    if [[ -n "$cnix_entry_port" ]] && ports_equal "$remote_port" "$cnix_entry_port"; then
        cat >&2 <<EOF
[WARN] 你输入的是 CNIX 商家入口端口，不是落地机业务端口。
[WARN] REMOTE_PORT 是香港业务服务端口，例如 Xray/sing-box/Web 监听端口。
[WARN] 它不是 EasyTier listener 端口，也不是 CNIX 面板入口端口。
EOF
        needs_confirm="true"
    fi

    if is_easytier_common_port "$remote_port"; then
        cat >&2 <<EOF
[WARN] 这个端口是 EasyTier 常见端口，请确认它确实是落地机业务服务端口。
EOF
        needs_confirm="true"
    fi

    if [[ -n "$local_port" ]] && ports_equal "$remote_port" "$local_port"; then
        cat >&2 <<EOF
[WARN] REMOTE_PORT 与入口机 LOCAL_PORT 相同。
[WARN] 这有时是刻意配置，但请确认 REMOTE_PORT 确实是香港业务服务端口。
EOF
    fi

    if is_common_system_port "$remote_port"; then
        cat >&2 <<EOF
[WARN] REMOTE_PORT 是常见系统/服务端口，请确认香港业务服务确实监听在该端口。
EOF
    fi

    [[ "$needs_confirm" == "true" ]]
}

print_remote_port_context() {
    local landing_et_ip="${1:-LANDING_ET_IP}"
    local listener_port="${2:-LISTENER_PORT}"
    cat >&2 <<EOF
REMOTE_PORT 是落地机业务服务端口。
它只用于入口机通过 EasyTier 虚拟 IP 访问：
${landing_et_ip}:REMOTE_PORT

CNIX 面板出口端口应该填写：
${listener_port}

不要把 REMOTE_PORT 填到 CNIX 面板出口。
EOF
}

print_four_port_reminder() {
    cat >&2 <<EOF
四端口提醒：
- LOCAL_PORT：客户端连接公网入口 VPS 的端口。
- CNIX_ENTRY_PORT：CNIX 商家入口端口。
- LISTENER_PORT：落地机 EasyTier listener，填写到 CNIX 面板出口。
- REMOTE_PORT：落地业务服务端口，不是 CNIX 面板出口。

EOF
}

print_remote_port_short_hint() {
    printf 'REMOTE_PORT 是业务服务端口，不是 CNIX 面板出口端口。\n' >&2
}

validate_remote_port_with_context() {
    local remote_port="$1"
    local listener_port="${2:-}"
    local cnix_entry_port="${3:-}"
    local local_port="${4:-}"
    local answer

    validate_port "$remote_port" || return 1
    if warn_if_remote_port_looks_like_tunnel_port "$remote_port" "$listener_port" "$cnix_entry_port" "$local_port"; then
        answer="$(prompt_yes_no "是否确认继续使用这个 REMOTE_PORT" "false")" || return 1
        [[ "$answer" == "true" ]] || return 2
    fi
    return 0
}

prompt_remote_port_with_context() {
    local label="$1"
    local default="${2:-}"
    local listener_port="${3:-}"
    local cnix_entry_port="${4:-}"
    local local_port="${5:-}"
    local value rc

    require_tty
    while true; do
        if [[ -n "$default" ]]; then
            printf '%s（默认 %s）：' "$label" "$default" >&2
        else
            printf '%s：' "$label" >&2
        fi
        IFS= read -r value || return 1
        value="${value:-$default}"
        if [[ -z "$value" ]]; then
            return 3
        fi

        set +e
        validate_remote_port_with_context "$value" "$listener_port" "$cnix_entry_port" "$local_port"
        rc=$?
        set -e
        case "$rc" in
            0) printf '%s\n' "$value"; return 0 ;;
            1) log_warn "REMOTE_PORT 必须是 1-65535 之间的整数。" ;;
            2) log_warn "已取消使用该 REMOTE_PORT，请重新输入。" ;;
        esac
    done
}

ask_forward_later() {
    local answer
    cat >&2 <<EOF
尚未配置落地机业务端口，无法生成业务转发规则。
你可以：
1) 输入业务端口
2) 暂时只配置 EasyTier，不应用 nftables 转发
EOF
    answer="$(prompt_required "请选择" "1")" || return 1
    case "$answer" in
        1) return 1 ;;
        2) return 0 ;;
        *) log_warn "请输入 1 或 2。默认建议 1。"; return 1 ;;
    esac
}

prompt_listener_proto() {
    local label="$1"
    local default="${2:-both}"
    local value normalized

    require_tty
    while true; do
        printf '%s（默认 %s）：' "$label" "$(proto_display "$default")" >&2
        IFS= read -r value || return 1
        if normalized="$(normalize_listener_proto "$value" "$default")"; then
            printf '%s\n' "$normalized"
            return 0
        fi
        log_warn "EasyTier 监听协议支持 tcp、udp、tcp+udp、both、ws、wss、quic、wg 或 all。直接回车默认 TCP/UDP。"
    done
}

prompt_easytier_protocol_choice() {
    local value default="${1:-1}" normalized
    require_tty
    cat >&2 <<'EOF'
请选择 EasyTier 组网协议：

1. TCP/UDP（推荐）
2. UDP
3. TCP
4. WebSocket
5. WebSocket TLS
6. QUIC
7. WireGuard
8. ALL
EOF
    while true; do
        printf '请选择 [1-8]，默认 %s：' "$default" >&2
        IFS= read -r value || return 1
        value="${value:-$default}"
        case "$value" in
            1) printf 'both\n'; return 0 ;;
            2) printf 'udp\n'; return 0 ;;
            3) printf 'tcp\n'; return 0 ;;
            4) printf 'ws\n'; return 0 ;;
            5) printf 'wss\n'; return 0 ;;
            6) printf 'quic\n'; return 0 ;;
            7) printf 'wg\n'; return 0 ;;
            8) printf 'all\n'; return 0 ;;
            tcp|udp|both|ws|wss|quic|wg|all)
                normalized="$(normalize_listener_proto "$value" "both")" || true
                [[ -n "$normalized" ]] && printf '%s\n' "$normalized" && return 0
                ;;
            *) ;;
        esac
        log_warn "请选择 1-8。"
    done
}

prompt_entry_proto() {
    local label="$1"
    local default="${2:-both}"
    local value normalized

    require_tty
    while true; do
        printf '%s（默认 %s）：' "$label" "$(proto_display "$default")" >&2
        IFS= read -r value || return 1
        if normalized="$(normalize_entry_proto "$value" "$default")"; then
            printf '%s\n' "$normalized"
            return 0
        fi
        log_warn "CNIX 入口协议支持 tcp、udp、tcp+udp、both、ws、wss、quic、wg 或 all。直接回车默认 TCP/UDP；如果 CNIX 只开单协议，请按实际协议输入。"
    done
}

prompt_forward_proto() {
    local label="$1"
    local default="${2:-both}"
    local value normalized

    require_tty
    while true; do
        printf '%s（默认 %s）：' "$label" "$(proto_display "$default")" >&2
        IFS= read -r value || return 1
        if normalized="$(normalize_forward_proto "$value" "$default")"; then
            printf '%s\n' "$normalized"
            return 0
        fi
        log_warn "转发协议支持 tcp、udp、both、tcp/udp、tcp udp 或 all。直接回车默认 TCP/UDP。"
    done
}

prompt_yes_no() {
    local label="$1"
    local default_bool="$2"
    local suffix answer normalized

    require_tty
    if [[ "$default_bool" == "true" ]]; then
        suffix="Y/n"
    else
        suffix="y/N"
    fi

    while true; do
        printf '%s [%s]：' "$label" "$suffix" >&2
        IFS= read -r answer || return 1
        answer="${answer%$'\r'}"
        if [[ -z "$answer" ]]; then
            printf '%s\n' "$default_bool"
            return 0
        fi
        normalized="${answer,,}"
        case "$normalized" in
            y|yes) printf 'true\n'; return 0 ;;
            n|no) printf 'false\n'; return 0 ;;
            *) log_warn "请输入 yes 或 no。" ;;
        esac
    done
}

confirm_recommended_nat_listener_role() {
    cat >&2 <<'EOF'
创建 NAT IX 中转线路

请在 NAT IX 机器上执行本步骤。
该机器负责监听商家分配的 NAT/IX 入口，并把流量转发到落地机。
EOF
    return 0
}

confirm_recommended_ingress_import_role() {
    cat >&2 <<'EOF'
公网入口机导入接入码

请在公网入口机上执行本步骤。
该机器负责接收客户端连接，并通过 EasyTier 转发到 NAT IX 机器。
EOF
    return 0
}

assign_auto_profile_identity() {
    local role_prefix="$1" id
    id="$(generate_unique_profile_id "$role_prefix")" || die_user "无法自动生成未占用的线路 ID，请稍后重试。"
    PROFILE_ID="$id"
    PROFILE_NAME="$id"
    ENABLED="true"
}

prompt_virtual_transit_port() {
    local default_port="${1:-}" answer
    if [[ -z "$default_port" ]]; then
        default_port="$(pick_random_port || true)"
    fi
    cat >&2 <<'EOF'
虚拟网中转端口用于 EasyTier 虚拟网内部转发，不需要公网放行。
通常保持自动随机即可。
EOF
    answer="$(prompt_yes_no "是否自定义虚拟网中转端口" "false")" || return 1
    if [[ "$answer" == "true" ]]; then
        prompt_port "请输入虚拟网中转端口（仅 EasyTier 虚拟网内部使用，不是商家入口端口）" "$default_port"
    else
        printf '%s\n' "$default_port"
    fi
}

mask_secret() {
    local secret="${1:-}"
    local length="${#secret}"
    if (( length <= 6 )); then
        printf '****\n'
    else
        printf '%s****%s\n' "${secret:0:3}" "${secret: -3}"
    fi
}

strip_optional_quotes() {
    local value="$1"
    if [[ "$value" == \"*\" && "$value" == *\" ]]; then
        value="${value#\"}"
        value="${value%\"}"
    elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
        value="${value#\'}"
        value="${value%\'}"
    fi
    printf '%s\n' "$value"
}

quote_env_value() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//\$/\\\$}"
    value="${value//\`/\\\`}"
    printf '"%s"\n' "$value"
}

json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s\n' "$value"
}

base64url_encode() {
    base64 | tr -d '\n' | tr '+/' '-_' | tr -d '='
}

base64url_decode() {
    local data="$1"
    local pad
    data="${data//-/+}"
    data="${data//_//}"
    case $((${#data} % 4)) in
        2) pad="==" ;;
        3) pad="=" ;;
        0) pad="" ;;
        *) return 1 ;;
    esac
    printf '%s%s' "$data" "$pad" | base64 -d 2>/dev/null
}

json_get_string() {
    local json="$1"
    local key="$2"
    printf '%s\n' "$json" | sed -nE 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' | head -n 1
}

json_get_number() {
    local json="$1"
    local key="$2"
    printf '%s\n' "$json" | sed -nE 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/p' | head -n 1
}

json_get_string_array_as_words() {
    local json="$1"
    local key="$2"
    local raw
    raw="$(printf '%s\n' "$json" | sed -nE 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*\[([^]]*)\].*/\1/p' | head -n 1)"
    [[ -n "$raw" ]] || return 1
    printf '%s\n' "$raw" | tr ',' '\n' | sed -nE 's/^[[:space:]]*"([^"]*)"[[:space:]]*$/\1/p' | tr '\n' ' ' | sed 's/[[:space:]]*$//'
}

clear_config_vars() {
    local key
    for key in PROFILE_ID PROFILE_NAME ENABLED LANDING_PUBLIC_HOST EASYTIER_VERSION CREATED_AT UPDATED_AT REMARK \
        LINE_GROUP LINE_ROLE LINE_PRIORITY HEALTH_CHECK_ENABLED HEALTH_STATUS LAST_HEALTH_CHECK_AT LAST_HEALTH_REASON LAST_SWITCH_AT SWITCH_NOTE \
        ROLE NAT_DIRECTION ET_NETWORK_NAME ET_NETWORK_SECRET ET_HOSTNAME ET_IPV4 ET_SUBNET \
        ET_LISTENER_PROTO ET_LISTENER_PORT ET_LISTENERS ET_MAPPED_LISTENERS ET_PEERS ET_NO_LISTENER \
        LISTENER_PROTOS LISTENER_PORT CNIX_ENTRY_PROTOS \
        ET_PRIVATE_MODE ET_EXPLICIT_ONLY IXTF_EXPLICIT_ONLY CNIX_ENTRY_PROTO CNIX_ENTRY_HOST CNIX_ENTRY_PORT \
        LOCAL_PORT LANDING_ET_IP REMOTE_PORT FORWARD_PROTO SERVICE_PORT CODE_LISTENER_PORT \
        INGRESS_ET_IP INGRESS_ET_CIDR NAT_ET_IP NAT_ET_CIDR INGRESS_PUBLIC_HOST INGRESS_HOSTNAME \
        INGRESS_LISTENER_PROTO INGRESS_LISTENER_PROTOS INGRESS_LISTENER_PORT TRANSIT_PORT \
        NAT_PUBLIC_HOST NAT_PUBLIC_PORTS NAT_PUBLIC_PORT_SPEC NAT_PUBLIC_PORT_MODE NAT_LISTENER_PROTO NAT_LISTENER_PROTOS NAT_LISTENER_PORT \
        REMOTE_NAT_PROFILE_ID REMOTE_NAT_PUBLIC_HOST \
        LANDING_HOST LANDING_PORT LANDING_IP NAT_PUBLIC_IP INGRESS_PUBLIC_IP \
        FORWARD_ENABLED LANDING_EASYTIER_VERSION CODE_EASYTIER_VERSION CODE_TUNNEL_PROTOS \
        CODE_LANDING_ET_CIDR CODE_SUGGESTED_INGRESS_ET_IP CODE_SUGGESTED_INGRESS_ET_CIDR \
        CODE_PROFILE_ID CODE_PROFILE_NAME CODE_SUGGESTED_INGRESS_PROFILE_ID CODE_LANDING_PUBLIC_HINT CODE_REMARK \
        CODE_INGRESS_HOSTNAME CODE_INGRESS_PUBLIC_HOST CODE_INGRESS_ET_IP CODE_INGRESS_ET_CIDR \
        CODE_INGRESS_LISTENER_PROTO CODE_INGRESS_LISTENER_PROTOS CODE_INGRESS_LISTENER_PORT \
        CODE_NAT_DIRECTION CODE_NAT_PUBLIC_HOST CODE_NAT_PUBLIC_PORTS CODE_NAT_PUBLIC_PORT_SPEC CODE_NAT_PUBLIC_PORT_MODE CODE_NAT_LISTENER_PROTO CODE_NAT_LISTENER_PROTOS CODE_NAT_LISTENER_PORT \
        CODE_NAT_ET_IP CODE_NAT_ET_CIDR CODE_TRANSIT_PORT CODE_LOCAL_PORT CODE_FORWARD_PROTO \
        CODE_LANDING_HOST CODE_LANDING_PORT CODE_RULES_TSV CODE_RULE_COUNT CODE_RULES_B64 CODE_RULES_COMPAT_NAT_PORT CODE_CODE_SCHEMA; do
        unset "$key" 2>/dev/null || true
    done
}

load_env_from_path() {
    local path="$1"
    clear_config_vars
    [[ -f "$path" && -r "$path" ]] || return 1

    local line key value mode
    mode="$(stat -c '%a' "$path" 2>/dev/null || printf '未知')"
    if [[ "$mode" != "600" && "$mode" != "400" && "$mode" != "700" ]]; then
        log_warn "env 文件权限可能过宽：${path} 当前权限 ${mode}，建议 chmod 600。"
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
        [[ "$line" == *=* ]] || continue
        key="$(trim_space "${line%%=*}")"
        value="$(trim_space "${line#*=}")"
        value="$(strip_optional_quotes "$value")"
        case "$key" in
            PROFILE_ID|PROFILE_NAME|ENABLED|LANDING_PUBLIC_HOST|EASYTIER_VERSION|CREATED_AT|UPDATED_AT|REMARK|\
            LINE_GROUP|LINE_ROLE|LINE_PRIORITY|HEALTH_CHECK_ENABLED|HEALTH_STATUS|LAST_HEALTH_CHECK_AT|LAST_HEALTH_REASON|LAST_SWITCH_AT|SWITCH_NOTE|\
            ROLE|NAT_DIRECTION|ET_NETWORK_NAME|ET_NETWORK_SECRET|ET_HOSTNAME|ET_IPV4|ET_SUBNET|\
            ET_LISTENER_PROTO|ET_LISTENER_PORT|ET_LISTENERS|ET_MAPPED_LISTENERS|ET_PEERS|\
            LISTENER_PROTOS|LISTENER_PORT|CNIX_ENTRY_PROTOS|\
            ET_NO_LISTENER|ET_PRIVATE_MODE|ET_EXPLICIT_ONLY|IXTF_EXPLICIT_ONLY|CNIX_ENTRY_PROTO|CNIX_ENTRY_HOST|\
            CNIX_ENTRY_PORT|LOCAL_PORT|LANDING_ET_IP|REMOTE_PORT|FORWARD_PROTO|\
            INGRESS_ET_IP|INGRESS_ET_CIDR|NAT_ET_IP|NAT_ET_CIDR|INGRESS_PUBLIC_HOST|INGRESS_HOSTNAME|\
            INGRESS_LISTENER_PROTO|INGRESS_LISTENER_PROTOS|INGRESS_LISTENER_PORT|TRANSIT_PORT|\
            NAT_PUBLIC_HOST|NAT_PUBLIC_PORTS|NAT_PUBLIC_PORT_SPEC|NAT_PUBLIC_PORT_MODE|NAT_LISTENER_PROTO|NAT_LISTENER_PROTOS|NAT_LISTENER_PORT|\
            REMOTE_NAT_PROFILE_ID|REMOTE_NAT_PUBLIC_HOST|\
            LANDING_HOST|LANDING_PORT|LANDING_IP|NAT_PUBLIC_IP|INGRESS_PUBLIC_IP|\
            SERVICE_PORT|CODE_LISTENER_PORT|FORWARD_ENABLED|LANDING_EASYTIER_VERSION|CODE_EASYTIER_VERSION|\
            CODE_TUNNEL_PROTOS|CODE_LANDING_ET_CIDR|CODE_SUGGESTED_INGRESS_ET_IP|CODE_SUGGESTED_INGRESS_ET_CIDR)
                printf -v "$key" '%s' "$value"
                ;;
        esac
    done <"$path"
}

load_env() {
    load_env_from_path "$ENV_FILE"
}

profile_env_value_from_path() {
    local path="$1" wanted="$2" line key value
    [[ -f "$path" && -r "$path" ]] || return 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
        [[ "$line" == *=* ]] || continue
        key="$(trim_space "${line%%=*}")"
        [[ "$key" == "$wanted" ]] || continue
        value="$(trim_space "${line#*=}")"
        strip_optional_quotes "$value"
        return 0
    done <"$path"
    return 1
}

profile_path_enabled() {
    local path="$1" enabled
    enabled="$(profile_env_value_from_path "$path" ENABLED 2>/dev/null || true)"
    [[ "${enabled:-true}" == "true" ]]
}

profile_subnet_from_path() {
    local path="$1" subnet et_ipv4
    subnet="$(profile_env_value_from_path "$path" ET_SUBNET 2>/dev/null || true)"
    if [[ -n "$subnet" ]]; then
        printf '%s\n' "$subnet"
        return 0
    fi
    et_ipv4="$(profile_env_value_from_path "$path" ET_IPV4 2>/dev/null || true)"
    [[ -n "$et_ipv4" ]] || return 1
    cidr_network24 "$et_ipv4"
}

profile_et_ip_addr_from_path() {
    local path="$1" et_ipv4
    et_ipv4="$(profile_env_value_from_path "$path" ET_IPV4 2>/dev/null || true)"
    [[ -n "$et_ipv4" ]] || return 1
    printf '%s\n' "${et_ipv4%%/*}"
}

normalize_profile_compat_vars() {
    reject_legacy_panel_role
    case "${ROLE:-}" in
        nat-ingress)
            NAT_DIRECTION="$(normalize_nat_direction "${NAT_DIRECTION:-ingress-listener}" 2>/dev/null || printf 'ingress-listener\n')"
            [[ -n "${INGRESS_ET_CIDR:-}" ]] || INGRESS_ET_CIDR="${ET_IPV4:-}"
            [[ -n "${INGRESS_ET_IP:-}" ]] || INGRESS_ET_IP="${INGRESS_ET_CIDR%%/*}"
            [[ -n "${NAT_ET_CIDR:-}" && -z "${NAT_ET_IP:-}" ]] && NAT_ET_IP="${NAT_ET_CIDR%%/*}"
            if [[ "$NAT_DIRECTION" == "nat-listener" ]]; then
                if [[ -n "${NAT_LISTENER_PROTOS:-}" ]]; then
                    NAT_LISTENER_PROTO="$(proto_list_to_value "$NAT_LISTENER_PROTOS")"
                fi
                if [[ -z "${NAT_LISTENER_PROTOS:-}" && -n "${NAT_LISTENER_PROTO:-}" ]]; then
                    NAT_LISTENER_PROTOS="$(normalize_peer_protos "$NAT_LISTENER_PROTO" "both" 2>/dev/null || printf '%s' "$NAT_LISTENER_PROTO")"
                fi
                if [[ -z "${NAT_PUBLIC_PORTS:-}" && -n "${NAT_LISTENER_PORT:-}" ]]; then
                    NAT_PUBLIC_PORTS="$NAT_LISTENER_PORT"
                    NAT_PUBLIC_PORT_MODE="${NAT_PUBLIC_PORT_MODE:-single}"
                fi
                if [[ -z "${NAT_LISTENER_PORT:-}" && -n "${NAT_PUBLIC_PORTS:-}" ]]; then
                    NAT_LISTENER_PORT="$(first_nat_public_port "$NAT_PUBLIC_PORTS" 2>/dev/null || true)"
                fi
                NAT_PUBLIC_PORT_MODE="${NAT_PUBLIC_PORT_MODE:-single}"
                if [[ -n "${NAT_PUBLIC_HOST:-}" && -n "${NAT_PUBLIC_PORTS:-${NAT_LISTENER_PORT:-}}" ]]; then
                    refresh_nat_public_endpoints_for_profile "${PROFILE_ID:-default}"
                fi
                ET_NO_LISTENER="${ET_NO_LISTENER:-true}"
            else
                if [[ -n "${INGRESS_LISTENER_PROTOS:-}" ]]; then
                    INGRESS_LISTENER_PROTO="$(proto_list_to_value "$INGRESS_LISTENER_PROTOS")"
                fi
                if [[ -z "${INGRESS_LISTENER_PROTOS:-}" && -n "${INGRESS_LISTENER_PROTO:-}" ]]; then
                    INGRESS_LISTENER_PROTOS="$(normalize_listener_protos "$INGRESS_LISTENER_PROTO" "both" 2>/dev/null || printf '%s' "$INGRESS_LISTENER_PROTO")"
                fi
                [[ -n "${ET_LISTENER_PROTO:-}" ]] || ET_LISTENER_PROTO="${INGRESS_LISTENER_PROTO:-both}"
                [[ -n "${ET_LISTENER_PORT:-}" ]] || ET_LISTENER_PORT="${INGRESS_LISTENER_PORT:-}"
                [[ -n "${INGRESS_LISTENER_PROTO:-}" ]] || INGRESS_LISTENER_PROTO="${ET_LISTENER_PROTO:-both}"
                [[ -n "${INGRESS_LISTENER_PORT:-}" ]] || INGRESS_LISTENER_PORT="${ET_LISTENER_PORT:-}"
                [[ -n "${ET_LISTENERS:-}" || -z "${INGRESS_LISTENER_PORT:-}" ]] || ET_LISTENERS="$(listener_urls_value "${INGRESS_LISTENER_PROTO:-both}" "$INGRESS_LISTENER_PORT" 2>/dev/null || true)"
            fi
            ;;
        nat-transit)
            NAT_DIRECTION="$(normalize_nat_direction "${NAT_DIRECTION:-ingress-listener}" 2>/dev/null || printf 'ingress-listener\n')"
            [[ -n "${NAT_ET_CIDR:-}" ]] || NAT_ET_CIDR="${ET_IPV4:-}"
            [[ -n "${NAT_ET_IP:-}" ]] || NAT_ET_IP="${NAT_ET_CIDR%%/*}"
            [[ -n "${INGRESS_ET_CIDR:-}" && -z "${INGRESS_ET_IP:-}" ]] && INGRESS_ET_IP="${INGRESS_ET_CIDR%%/*}"
            if [[ "$NAT_DIRECTION" == "nat-listener" ]]; then
                if [[ -n "${NAT_LISTENER_PROTOS:-}" ]]; then
                    NAT_LISTENER_PROTO="$(proto_list_to_value "$NAT_LISTENER_PROTOS")"
                fi
                if [[ -z "${NAT_LISTENER_PROTOS:-}" && -n "${NAT_LISTENER_PROTO:-}" ]]; then
                    NAT_LISTENER_PROTOS="$(normalize_listener_protos "$NAT_LISTENER_PROTO" "both" 2>/dev/null || printf '%s' "$NAT_LISTENER_PROTO")"
                fi
                if [[ -z "${NAT_PUBLIC_PORTS:-}" && -n "${NAT_LISTENER_PORT:-}" ]]; then
                    NAT_PUBLIC_PORTS="$NAT_LISTENER_PORT"
                    NAT_PUBLIC_PORT_MODE="${NAT_PUBLIC_PORT_MODE:-single}"
                fi
                if [[ -z "${NAT_LISTENER_PORT:-}" && -n "${NAT_PUBLIC_PORTS:-}" ]]; then
                    NAT_LISTENER_PORT="$(first_nat_public_port "$NAT_PUBLIC_PORTS" 2>/dev/null || true)"
                fi
                NAT_PUBLIC_PORT_MODE="${NAT_PUBLIC_PORT_MODE:-single}"
                [[ -n "${ET_LISTENER_PROTO:-}" ]] || ET_LISTENER_PROTO="${NAT_LISTENER_PROTO:-both}"
                [[ -n "${ET_LISTENER_PORT:-}" ]] || ET_LISTENER_PORT="${NAT_LISTENER_PORT:-}"
                [[ -n "${NAT_LISTENER_PROTO:-}" ]] || NAT_LISTENER_PROTO="${ET_LISTENER_PROTO:-both}"
                [[ -n "${NAT_LISTENER_PORT:-}" ]] || NAT_LISTENER_PORT="${ET_LISTENER_PORT:-}"
                refresh_nat_public_endpoints_for_profile "${PROFILE_ID:-default}"
                ET_NO_LISTENER="${ET_NO_LISTENER:-false}"
            else
                if [[ -n "${INGRESS_LISTENER_PROTOS:-}" ]]; then
                    INGRESS_LISTENER_PROTO="$(proto_list_to_value "$INGRESS_LISTENER_PROTOS")"
                fi
                if [[ -z "${INGRESS_LISTENER_PROTOS:-}" && -n "${INGRESS_LISTENER_PROTO:-}" ]]; then
                    INGRESS_LISTENER_PROTOS="$(normalize_listener_protos "$INGRESS_LISTENER_PROTO" "both" 2>/dev/null || printf '%s' "$INGRESS_LISTENER_PROTO")"
                fi
                if [[ -n "${INGRESS_PUBLIC_HOST:-}" && -n "${INGRESS_LISTENER_PORT:-}" ]]; then
                    ET_PEERS="${ET_PEERS:-$(peer_urls_value "${INGRESS_LISTENER_PROTO:-both}" "$INGRESS_PUBLIC_HOST" "$INGRESS_LISTENER_PORT" 2>/dev/null || true)}"
                fi
                ET_NO_LISTENER="${ET_NO_LISTENER:-true}"
            fi
            ;;
    esac
    if [[ -n "${LISTENER_PROTOS:-}" ]]; then
        ET_LISTENER_PROTO="$(proto_list_to_value "$LISTENER_PROTOS")"
    fi
    if [[ -z "${LISTENER_PROTOS:-}" && -n "${ET_LISTENER_PROTO:-}" ]]; then
        LISTENER_PROTOS="$(normalize_listener_protos "$ET_LISTENER_PROTO" "both" 2>/dev/null || printf '%s' "$ET_LISTENER_PROTO")"
    fi
    if [[ -n "${LISTENER_PORT:-}" ]]; then
        ET_LISTENER_PORT="$LISTENER_PORT"
    fi
    if [[ -z "${LISTENER_PORT:-}" && -n "${ET_LISTENER_PORT:-}" ]]; then
        LISTENER_PORT="$ET_LISTENER_PORT"
    fi
    if [[ -n "${CNIX_ENTRY_PROTOS:-}" ]]; then
        CNIX_ENTRY_PROTO="$(proto_list_to_value "$CNIX_ENTRY_PROTOS")"
    fi
    if [[ -z "${CNIX_ENTRY_PROTOS:-}" && -n "${CNIX_ENTRY_PROTO:-}" ]]; then
        CNIX_ENTRY_PROTOS="$(normalize_peer_protos "$CNIX_ENTRY_PROTO" "both" 2>/dev/null || printf '%s' "$CNIX_ENTRY_PROTO")"
    fi
    ENABLED="${ENABLED:-true}"
    FORWARD_ENABLED="${FORWARD_ENABLED:-true}"
    LINE_ROLE="${LINE_ROLE:-standalone}"
    LINE_PRIORITY="${LINE_PRIORITY:-100}"
    HEALTH_CHECK_ENABLED="${HEALTH_CHECK_ENABLED:-true}"
    HEALTH_STATUS="${HEALTH_STATUS:-unknown}"
    PROFILE_ID="${PROFILE_ID:-default}"
    PROFILE_NAME="${PROFILE_NAME:-$PROFILE_ID}"
}

load_profile() {
    local profile_id="$1" path
    if [[ "$profile_id" == "default" && ! -f "$(profile_env_path default 2>/dev/null || printf /nonexistent)" && -f "$ENV_FILE" ]]; then
        load_env || return 1
        PROFILE_ID="default"
        PROFILE_NAME="${PROFILE_NAME:-default}"
        ENABLED="${ENABLED:-true}"
        normalize_profile_compat_vars
        return 0
    fi
    path="$(profile_env_path "$profile_id")" || return 1
    load_env_from_path "$path" || return 1
    normalize_profile_compat_vars
}

load_profile_or_die() {
    local profile_id="$1"
    load_profile "$profile_id" || die_user "无法读取线路：${profile_id}"
}

save_profile_env() {
    local profile_id="${1:-${PROFILE_ID:-}}" path tmp now listener_protos listener_proto listener_port cnix_protos nat_direction nat_listener_protos
    validate_profile_id "$profile_id" || die_user "PROFILE_ID 格式不正确：${profile_id}"
    ensure_profile_dirs
    path="$(profile_env_path "$profile_id")"
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    CREATED_AT="${CREATED_AT:-$now}"
    UPDATED_AT="$now"
    ENABLED="${ENABLED:-true}"
    FORWARD_ENABLED="${FORWARD_ENABLED:-true}"
    LINE_ROLE="${LINE_ROLE:-standalone}"
    LINE_PRIORITY="${LINE_PRIORITY:-100}"
    HEALTH_CHECK_ENABLED="${HEALTH_CHECK_ENABLED:-true}"
    HEALTH_STATUS="${HEALTH_STATUS:-unknown}"
    PROFILE_NAME="${PROFILE_NAME:-$profile_id}"
    PROFILE_ID="$profile_id"
    normalize_profile_compat_vars
    refresh_nat_public_endpoints_for_profile "$profile_id"
    ddns_seed_profile_resolved_ips "$profile_id"
    nat_direction="${NAT_DIRECTION:-}"
    listener_proto="${ET_LISTENER_PROTO:-${LISTENER_PROTOS:-both}}"
    listener_port="${LISTENER_PORT:-${ET_LISTENER_PORT:-}}"
    listener_protos="${LISTENER_PROTOS:-$(normalize_listener_protos "$listener_proto" "both" 2>/dev/null || true)}"
    cnix_protos="${CNIX_ENTRY_PROTOS:-$(normalize_peer_protos "${CNIX_ENTRY_PROTO:-both}" "both" 2>/dev/null || true)}"
    nat_listener_protos="${NAT_LISTENER_PROTOS:-$(normalize_listener_protos "${NAT_LISTENER_PROTO:-both}" "both" 2>/dev/null || true)}"
    tmp="$(make_tmp_file "ix-transit-fabric.profile")"
    chmod 600 "$tmp"
    {
        printf '# Managed by ix-transit-fabric profile. Do not share this file.\n'
        printf 'PROFILE_ID=%s\n' "$PROFILE_ID"
        printf 'PROFILE_NAME=%s\n' "$(quote_env_value "$PROFILE_NAME")"
        printf 'ROLE=%s\n' "$ROLE"
        printf 'ENABLED=%s\n' "$ENABLED"
        [[ -n "${LINE_GROUP:-}" ]] && printf 'LINE_GROUP=%s\n' "$(quote_env_value "$LINE_GROUP")"
        printf 'LINE_ROLE=%s\n' "$LINE_ROLE"
        printf 'LINE_PRIORITY=%s\n' "$LINE_PRIORITY"
        printf 'HEALTH_CHECK_ENABLED=%s\n' "$HEALTH_CHECK_ENABLED"
        printf 'HEALTH_STATUS=%s\n' "$HEALTH_STATUS"
        [[ -n "${LAST_HEALTH_CHECK_AT:-}" ]] && printf 'LAST_HEALTH_CHECK_AT=%s\n' "$(quote_env_value "$LAST_HEALTH_CHECK_AT")"
        [[ -n "${LAST_HEALTH_REASON:-}" ]] && printf 'LAST_HEALTH_REASON=%s\n' "$(quote_env_value "$LAST_HEALTH_REASON")"
        [[ -n "${LAST_SWITCH_AT:-}" ]] && printf 'LAST_SWITCH_AT=%s\n' "$(quote_env_value "$LAST_SWITCH_AT")"
        [[ -n "${SWITCH_NOTE:-}" ]] && printf 'SWITCH_NOTE=%s\n' "$(quote_env_value "$SWITCH_NOTE")"
        printf 'ET_NETWORK_NAME=%s\n' "$ET_NETWORK_NAME"
        printf 'ET_NETWORK_SECRET=%s\n' "$ET_NETWORK_SECRET"
        printf 'ET_SUBNET=%s\n' "${ET_SUBNET:-}"
        printf 'ET_HOSTNAME=%s\n' "$ET_HOSTNAME"
        printf 'ET_IPV4=%s\n' "$ET_IPV4"
        printf 'ET_PRIVATE_MODE=true\n'
        printf 'ET_EXPLICIT_ONLY=true\n'
        printf 'IXTF_EXPLICIT_ONLY=true\n'
        printf 'CREATED_AT=%s\n' "$CREATED_AT"
        printf 'UPDATED_AT=%s\n' "$UPDATED_AT"
        [[ -n "${LANDING_PUBLIC_HOST:-}" ]] && printf 'LANDING_PUBLIC_HOST=%s\n' "$(quote_env_value "$LANDING_PUBLIC_HOST")"
        [[ -n "${EASYTIER_VERSION:-}" ]] && printf 'EASYTIER_VERSION=%s\n' "$(quote_env_value "$EASYTIER_VERSION")"
        [[ -n "${REMARK:-}" ]] && printf 'REMARK=%s\n' "$(quote_env_value "$REMARK")"
        case "$ROLE" in
            nat-ingress)
                nat_direction="${nat_direction:-ingress-listener}"
                printf 'NAT_DIRECTION=%s\n' "$nat_direction"
                printf 'INGRESS_ET_IP=%s\n' "${INGRESS_ET_IP:-${ET_IPV4%%/*}}"
                printf 'INGRESS_ET_CIDR=%s\n' "${INGRESS_ET_CIDR:-$ET_IPV4}"
                printf 'NAT_ET_IP=%s\n' "$NAT_ET_IP"
                [[ -n "${NAT_ET_CIDR:-}" ]] && printf 'NAT_ET_CIDR=%s\n' "$NAT_ET_CIDR"
                [[ -n "${INGRESS_PUBLIC_HOST:-}" ]] && printf 'INGRESS_PUBLIC_HOST=%s\n' "$(quote_env_value "$INGRESS_PUBLIC_HOST")"
                [[ -n "${INGRESS_PUBLIC_IP:-}" ]] && printf 'INGRESS_PUBLIC_IP=%s\n' "$INGRESS_PUBLIC_IP"
                printf 'INGRESS_HOSTNAME=%s\n' "$(quote_env_value "${INGRESS_HOSTNAME:-$ET_HOSTNAME}")"
                if [[ "$nat_direction" == "nat-listener" ]]; then
                    printf 'NAT_PUBLIC_HOST=%s\n' "$(quote_env_value "$NAT_PUBLIC_HOST")"
                    [[ -n "${NAT_PUBLIC_IP:-}" ]] && printf 'NAT_PUBLIC_IP=%s\n' "$NAT_PUBLIC_IP"
                    printf 'NAT_PUBLIC_PORTS=%s\n' "$(quote_env_value "${NAT_PUBLIC_PORTS:-${NAT_LISTENER_PORT:-}}")"
                    [[ -n "${NAT_PUBLIC_PORT_SPEC:-}" ]] && printf 'NAT_PUBLIC_PORT_SPEC=%s\n' "$(quote_env_value "$NAT_PUBLIC_PORT_SPEC")"
                    printf 'NAT_PUBLIC_PORT_MODE=%s\n' "${NAT_PUBLIC_PORT_MODE:-single}"
                    printf 'NAT_LISTENER_PROTO=%s\n' "$NAT_LISTENER_PROTO"
                    printf 'NAT_LISTENER_PROTOS=%s\n' "$(quote_env_value "$nat_listener_protos")"
                    printf 'NAT_LISTENER_PORT=%s\n' "$NAT_LISTENER_PORT"
                    [[ -n "${REMOTE_NAT_PROFILE_ID:-}" ]] && printf 'REMOTE_NAT_PROFILE_ID=%s\n' "$(quote_env_value "$REMOTE_NAT_PROFILE_ID")"
                    [[ -n "${REMOTE_NAT_PUBLIC_HOST:-}" ]] && printf 'REMOTE_NAT_PUBLIC_HOST=%s\n' "$(quote_env_value "$REMOTE_NAT_PUBLIC_HOST")"
                    printf 'ET_PEERS=%s\n' "$(quote_env_value "${ET_PEERS:-$(peer_urls_for_ports_value "$NAT_LISTENER_PROTO" "$NAT_PUBLIC_HOST" "${NAT_PUBLIC_PORTS:-$NAT_LISTENER_PORT}" 2>/dev/null || true)}")"
                    printf 'ET_NO_LISTENER=%s\n' "${ET_NO_LISTENER:-true}"
                    [[ -n "${LANDING_HOST:-}" ]] && printf 'LANDING_HOST=%s\n' "$(quote_env_value "$LANDING_HOST")"
                    [[ -n "${LANDING_PORT:-}" ]] && printf 'LANDING_PORT=%s\n' "$LANDING_PORT"
                else
                    printf 'INGRESS_LISTENER_PROTO=%s\n' "$INGRESS_LISTENER_PROTO"
                    printf 'INGRESS_LISTENER_PROTOS=%s\n' "$(quote_env_value "${INGRESS_LISTENER_PROTOS:-$(normalize_listener_protos "$INGRESS_LISTENER_PROTO" "both")}")"
                    printf 'INGRESS_LISTENER_PORT=%s\n' "$INGRESS_LISTENER_PORT"
                    printf 'ET_LISTENER_PROTO=%s\n' "$INGRESS_LISTENER_PROTO"
                    printf 'ET_LISTENER_PORT=%s\n' "$INGRESS_LISTENER_PORT"
                    printf 'ET_LISTENERS=%s\n' "$(quote_env_value "${ET_LISTENERS:-$(listener_urls_value "$INGRESS_LISTENER_PROTO" "$INGRESS_LISTENER_PORT" 2>/dev/null || true)}")"
                fi
                printf 'FORWARD_ENABLED=%s\n' "${FORWARD_ENABLED:-true}"
                printf 'LOCAL_PORT=%s\n' "$LOCAL_PORT"
                printf 'TRANSIT_PORT=%s\n' "$TRANSIT_PORT"
                printf 'FORWARD_PROTO=%s\n' "$FORWARD_PROTO"
                ;;
            nat-transit)
                nat_direction="${nat_direction:-ingress-listener}"
                printf 'NAT_DIRECTION=%s\n' "$nat_direction"
                printf 'INGRESS_ET_IP=%s\n' "$INGRESS_ET_IP"
                [[ -n "${INGRESS_ET_CIDR:-}" ]] && printf 'INGRESS_ET_CIDR=%s\n' "$INGRESS_ET_CIDR"
                printf 'NAT_ET_IP=%s\n' "${NAT_ET_IP:-${ET_IPV4%%/*}}"
                printf 'NAT_ET_CIDR=%s\n' "${NAT_ET_CIDR:-$ET_IPV4}"
                [[ -n "${INGRESS_HOSTNAME:-}" ]] && printf 'INGRESS_HOSTNAME=%s\n' "$(quote_env_value "$INGRESS_HOSTNAME")"
                if [[ "$nat_direction" == "nat-listener" ]]; then
                    [[ -n "${INGRESS_PUBLIC_HOST:-}" ]] && printf 'INGRESS_PUBLIC_HOST=%s\n' "$(quote_env_value "$INGRESS_PUBLIC_HOST")"
                    [[ -n "${INGRESS_PUBLIC_IP:-}" ]] && printf 'INGRESS_PUBLIC_IP=%s\n' "$INGRESS_PUBLIC_IP"
                    printf 'NAT_PUBLIC_HOST=%s\n' "$(quote_env_value "$NAT_PUBLIC_HOST")"
                    [[ -n "${NAT_PUBLIC_IP:-}" ]] && printf 'NAT_PUBLIC_IP=%s\n' "$NAT_PUBLIC_IP"
                    printf 'NAT_PUBLIC_PORTS=%s\n' "$(quote_env_value "${NAT_PUBLIC_PORTS:-${NAT_LISTENER_PORT:-}}")"
                    [[ -n "${NAT_PUBLIC_PORT_SPEC:-}" ]] && printf 'NAT_PUBLIC_PORT_SPEC=%s\n' "$(quote_env_value "$NAT_PUBLIC_PORT_SPEC")"
                    printf 'NAT_PUBLIC_PORT_MODE=%s\n' "${NAT_PUBLIC_PORT_MODE:-single}"
                    printf 'NAT_LISTENER_PROTO=%s\n' "$NAT_LISTENER_PROTO"
                    printf 'NAT_LISTENER_PROTOS=%s\n' "$(quote_env_value "$nat_listener_protos")"
                    printf 'NAT_LISTENER_PORT=%s\n' "$NAT_LISTENER_PORT"
                    printf 'ET_LISTENER_PROTO=%s\n' "$NAT_LISTENER_PROTO"
                    printf 'ET_LISTENER_PORT=%s\n' "$NAT_LISTENER_PORT"
                    printf 'ET_LISTENERS=%s\n' "$(quote_env_value "${ET_LISTENERS:-$(listener_urls_for_ports_value "$NAT_LISTENER_PROTO" "${NAT_PUBLIC_PORTS:-$NAT_LISTENER_PORT}" 2>/dev/null || true)}")"
                    [[ -n "${ET_MAPPED_LISTENERS:-}" ]] && printf 'ET_MAPPED_LISTENERS=%s\n' "$(quote_env_value "$ET_MAPPED_LISTENERS")"
                    printf 'ET_NO_LISTENER=%s\n' "${ET_NO_LISTENER:-false}"
                else
                    printf 'INGRESS_PUBLIC_HOST=%s\n' "$(quote_env_value "$INGRESS_PUBLIC_HOST")"
                    [[ -n "${INGRESS_PUBLIC_IP:-}" ]] && printf 'INGRESS_PUBLIC_IP=%s\n' "$INGRESS_PUBLIC_IP"
                    printf 'INGRESS_LISTENER_PROTO=%s\n' "$INGRESS_LISTENER_PROTO"
                    printf 'INGRESS_LISTENER_PROTOS=%s\n' "$(quote_env_value "${INGRESS_LISTENER_PROTOS:-$(normalize_listener_protos "$INGRESS_LISTENER_PROTO" "both")}")"
                    printf 'INGRESS_LISTENER_PORT=%s\n' "$INGRESS_LISTENER_PORT"
                    printf 'ET_PEERS=%s\n' "$(quote_env_value "$ET_PEERS")"
                    printf 'ET_NO_LISTENER=%s\n' "${ET_NO_LISTENER:-true}"
                fi
                printf 'FORWARD_ENABLED=%s\n' "${FORWARD_ENABLED:-true}"
                [[ -n "${LOCAL_PORT:-}" ]] && printf 'LOCAL_PORT=%s\n' "$LOCAL_PORT"
                printf 'TRANSIT_PORT=%s\n' "$TRANSIT_PORT"
                printf 'LANDING_HOST=%s\n' "$(quote_env_value "$LANDING_HOST")"
                printf 'LANDING_PORT=%s\n' "$LANDING_PORT"
                [[ -n "${LANDING_IP:-}" ]] && printf 'LANDING_IP=%s\n' "$LANDING_IP"
                printf 'FORWARD_PROTO=%s\n' "$FORWARD_PROTO"
                ;;
        esac
    } >"$tmp"
    backup_file "$path"
    mv -f -- "$tmp" "$path"
    chmod 600 "$path"
    log_debug "已写入线路配置：${path}"
    ensure_default_rule_for_profile "$profile_id" || true
}

save_profile_runtime_state() {
    local profile_id="$1" path tmp found_status=0 found_at=0 found_reason=0
    validate_profile_id "$profile_id" || return 1
    path="$(profile_env_path "$profile_id")" || return 1
    [[ -f "$path" ]] || return 1
    tmp="$(make_tmp_file "ix-transit-fabric.profile-runtime")"
    chmod 600 "$tmp"
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            HEALTH_STATUS=*)
                printf 'HEALTH_STATUS=%s\n' "${HEALTH_STATUS:-unknown}" >>"$tmp"
                found_status=1
                ;;
            LAST_HEALTH_CHECK_AT=*)
                printf 'LAST_HEALTH_CHECK_AT=%s\n' "${LAST_HEALTH_CHECK_AT:-}" >>"$tmp"
                found_at=1
                ;;
            LAST_HEALTH_REASON=*)
                printf 'LAST_HEALTH_REASON=%s\n' "$(quote_env_value "${LAST_HEALTH_REASON:-未检查}")" >>"$tmp"
                found_reason=1
                ;;
            *)
                printf '%s\n' "$line" >>"$tmp"
                ;;
        esac
    done <"$path"
    [[ "$found_status" -eq 1 ]] || printf 'HEALTH_STATUS=%s\n' "${HEALTH_STATUS:-unknown}" >>"$tmp"
    [[ "$found_at" -eq 1 ]] || printf 'LAST_HEALTH_CHECK_AT=%s\n' "${LAST_HEALTH_CHECK_AT:-}" >>"$tmp"
    [[ "$found_reason" -eq 1 ]] || printf 'LAST_HEALTH_REASON=%s\n' "$(quote_env_value "${LAST_HEALTH_REASON:-未检查}")" >>"$tmp"
    install -m 600 "$tmp" "$path"
    rm -f -- "$tmp"
    return 0
}

save_profile_code_file() {
    local profile_id="$1" code="$2" path
    ensure_profile_dirs
    path="$(profile_code_path "$profile_id")"
    printf '%s\n' "$code" >"$path"
    chmod 600 "$path"
}

save_env() {
    ensure_config_dir
    local tmp
    tmp="$(make_tmp_file "ix-transit-fabric.env")"
    chmod 600 "$tmp"

    {
        printf '# Managed by ix-transit-fabric. Do not share this file.\n'
        printf 'ROLE=%s\n' "$ROLE"
        printf 'ET_NETWORK_NAME=%s\n' "$ET_NETWORK_NAME"
        printf 'ET_NETWORK_SECRET=%s\n' "$ET_NETWORK_SECRET"
        printf 'ET_HOSTNAME=%s\n' "$ET_HOSTNAME"
        printf 'ET_IPV4=%s\n' "$ET_IPV4"
        [[ -n "${ET_SUBNET:-}" ]] && printf 'ET_SUBNET=%s\n' "$ET_SUBNET"
        printf 'ET_PRIVATE_MODE=true\n'
        printf 'ET_EXPLICIT_ONLY=true\n'
        printf 'IXTF_EXPLICIT_ONLY=true\n'

        if [[ "$ROLE" == "nat-transit" ]]; then
            printf 'LISTENER_PROTOS=%s\n' "$(quote_env_value "$(normalize_listener_protos "${ET_LISTENER_PROTO:-both}" "both" 2>/dev/null || printf '%s' "${ET_LISTENER_PROTO:-both}")")"
            printf 'LISTENER_PORT=%s\n' "$ET_LISTENER_PORT"
            printf 'ET_LISTENER_PROTO=%s\n' "$ET_LISTENER_PROTO"
            printf 'ET_LISTENER_PORT=%s\n' "$ET_LISTENER_PORT"
            printf 'ET_LISTENERS=%s\n' "$(quote_env_value "$ET_LISTENERS")"
            [[ -n "${SERVICE_PORT:-}" ]] && printf 'SERVICE_PORT=%s\n' "$SERVICE_PORT"
            [[ -n "${SERVICE_PORT:-}" ]] && printf 'REMOTE_PORT=%s\n' "$SERVICE_PORT"
        fi

        if [[ "$ROLE" == "nat-ingress" ]]; then
            printf 'ET_PEERS=%s\n' "$(quote_env_value "$ET_PEERS")"
            printf 'ET_NO_LISTENER=%s\n' "${ET_NO_LISTENER:-true}"
            printf 'CNIX_ENTRY_PROTO=%s\n' "$CNIX_ENTRY_PROTO"
            printf 'CNIX_ENTRY_HOST=%s\n' "$CNIX_ENTRY_HOST"
            printf 'CNIX_ENTRY_PORT=%s\n' "$CNIX_ENTRY_PORT"
            [[ -n "${CODE_LISTENER_PORT:-}" ]] && printf 'CODE_LISTENER_PORT=%s\n' "$CODE_LISTENER_PORT"
            [[ -n "${CODE_TUNNEL_PROTOS:-}" ]] && printf 'CODE_TUNNEL_PROTOS=%s\n' "$(quote_env_value "$CODE_TUNNEL_PROTOS")"
            [[ -n "${CODE_LANDING_ET_CIDR:-}" ]] && printf 'CODE_LANDING_ET_CIDR=%s\n' "$CODE_LANDING_ET_CIDR"
            [[ -n "${CODE_SUGGESTED_INGRESS_ET_IP:-}" ]] && printf 'CODE_SUGGESTED_INGRESS_ET_IP=%s\n' "$CODE_SUGGESTED_INGRESS_ET_IP"
            [[ -n "${CODE_SUGGESTED_INGRESS_ET_CIDR:-}" ]] && printf 'CODE_SUGGESTED_INGRESS_ET_CIDR=%s\n' "$CODE_SUGGESTED_INGRESS_ET_CIDR"
            printf 'FORWARD_ENABLED=%s\n' "${FORWARD_ENABLED:-true}"
            [[ -n "${LOCAL_PORT:-}" ]] && printf 'LOCAL_PORT=%s\n' "$LOCAL_PORT"
            [[ -n "${LANDING_ET_IP:-}" ]] && printf 'LANDING_ET_IP=%s\n' "$LANDING_ET_IP"
            [[ -n "${REMOTE_PORT:-}" ]] && printf 'REMOTE_PORT=%s\n' "$REMOTE_PORT"
            [[ -n "${FORWARD_PROTO:-}" ]] && printf 'FORWARD_PROTO=%s\n' "$FORWARD_PROTO"
            [[ -n "${LANDING_EASYTIER_VERSION:-}" ]] && printf 'LANDING_EASYTIER_VERSION=%s\n' "$(quote_env_value "$LANDING_EASYTIER_VERSION")"
            [[ -n "${CODE_EASYTIER_VERSION:-}" ]] && printf 'CODE_EASYTIER_VERSION=%s\n' "$(quote_env_value "$CODE_EASYTIER_VERSION")"
        fi
    } >"$tmp"

    backup_file "$ENV_FILE"
    mv -f -- "$tmp" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    chmod 700 "$CONFIG_DIR"
    log_ok "已写入配置：${ENV_FILE}"
}

require_config_var() {
    local name="$1"
    [[ -n "${!name:-}" ]] || die_user "env 文件缺少必需变量：${name}"
}

validate_easytier_args() {
    local normalized
    require_config_var ROLE
    require_config_var ET_NETWORK_NAME
    require_config_var ET_NETWORK_SECRET
    require_config_var ET_HOSTNAME
    require_config_var ET_IPV4

    validate_network_name "$ET_NETWORK_NAME" || die_user "ET_NETWORK_NAME 格式不正确：请输入 1-64 个字符，仅允许字母、数字、点、下划线或短横线。"
    validate_secret "$ET_NETWORK_SECRET" || die_user "ET_NETWORK_SECRET 至少 12 位，且只能包含字母、数字和 . _ ~ : @ % + = , / -。"
    validate_hostname_value "$ET_HOSTNAME" || die_user "ET_HOSTNAME 格式不正确：请输入 1-64 个字符，仅允许字母、数字、点、下划线或短横线。"
    validate_ipv4_cidr "$ET_IPV4" || die_user "ET_IPV4 必须是 IPv4/CIDR，例如 10.144.144.1/24。"
    ET_SUBNET="${ET_SUBNET:-$(cidr_network24 "$ET_IPV4" 2>/dev/null || true)}"
    ET_PRIVATE_MODE="true"
    ET_EXPLICIT_ONLY="true"
    IXTF_EXPLICIT_ONLY="true"
    normalize_profile_compat_vars

    case "$ROLE" in
        nat-ingress)
            NAT_DIRECTION="$(normalize_nat_direction "${NAT_DIRECTION:-ingress-listener}")" || die_user "NAT_DIRECTION 只能是 ingress-listener 或 nat-listener。"
            require_config_var NAT_ET_IP
            require_config_var LOCAL_PORT
            require_config_var TRANSIT_PORT
            require_config_var FORWARD_PROTO
            validate_ipv4 "$NAT_ET_IP" || die_user "NAT_ET_IP 必须是 IPv4，例如 10.88.0.2。"
            validate_ipv4_cidr "${INGRESS_ET_CIDR:-$ET_IPV4}" || die_user "INGRESS_ET_CIDR 必须是 IPv4/CIDR。"
            validate_port "$LOCAL_PORT" || die_user "LOCAL_PORT 必须是 1-65535 的端口。"
            validate_port "$TRANSIT_PORT" || die_user "TRANSIT_PORT 必须是 1-65535 的端口。"
            normalized="$(normalize_forward_proto "$FORWARD_PROTO" "both")" || die_user "FORWARD_PROTO 只能是 tcp、udp 或 both。"
            FORWARD_PROTO="$normalized"
            INGRESS_ET_CIDR="${INGRESS_ET_CIDR:-$ET_IPV4}"
            INGRESS_ET_IP="${INGRESS_ET_IP:-${INGRESS_ET_CIDR%%/*}}"
            NAT_ET_CIDR="${NAT_ET_CIDR:-${NAT_ET_IP}/24}"
            validate_ipv4_cidr "$NAT_ET_CIDR" || die_user "NAT_ET_CIDR 必须是 IPv4/CIDR。"
            [[ "${INGRESS_ET_CIDR%%/*}" == "$INGRESS_ET_IP" ]] || die_user "INGRESS_ET_IP 和 INGRESS_ET_CIDR 不一致。"
            [[ "${NAT_ET_CIDR%%/*}" == "$NAT_ET_IP" ]] || die_user "NAT_ET_IP 和 NAT_ET_CIDR 不一致。"
            if [[ "$NAT_DIRECTION" == "nat-listener" ]]; then
                require_config_var NAT_PUBLIC_HOST
                require_config_var NAT_LISTENER_PROTO
                require_config_var NAT_LISTENER_PORT
                normalized="$(normalize_entry_proto "$NAT_LISTENER_PROTO" "both")" || die_user "NAT_LISTENER_PROTO 只能是 tcp、udp、tcp+udp、ws、wss、quic、wg 或 all。"
                NAT_LISTENER_PROTO="$normalized"
                NAT_LISTENER_PROTOS="$(normalize_peer_protos "$normalized" "both")"
                validate_host "$NAT_PUBLIC_HOST" || die_user "NAT_PUBLIC_HOST 必须是 NAT IX 商家入口 IP 或域名。"
                validate_port "$NAT_LISTENER_PORT" || die_user "NAT_LISTENER_PORT 必须是 1-65535 的端口。"
                NAT_PUBLIC_PORTS="$(normalize_nat_public_ports_input "${NAT_PUBLIC_PORTS:-$NAT_LISTENER_PORT}")" || die_user "NAT_PUBLIC_PORTS 必须是合法端口列表。"
                NAT_LISTENER_PORT="$(first_nat_public_port "$NAT_PUBLIC_PORTS")"
                [[ -z "${INGRESS_PUBLIC_HOST:-}" ]] || validate_host "$INGRESS_PUBLIC_HOST" || die_user "INGRESS_PUBLIC_HOST 必须是公网 IP 或域名。"
                refresh_nat_public_endpoints_for_profile "${PROFILE_ID:-default}"
                ET_NO_LISTENER="${ET_NO_LISTENER:-true}"
            else
                require_config_var INGRESS_PUBLIC_HOST
                require_config_var INGRESS_LISTENER_PROTO
                require_config_var INGRESS_LISTENER_PORT
                normalized="$(normalize_listener_proto "$INGRESS_LISTENER_PROTO" "both")" || die_user "INGRESS_LISTENER_PROTO 只能是 tcp、udp、tcp+udp、ws、wss、quic、wg 或 all。"
                INGRESS_LISTENER_PROTO="$normalized"
                INGRESS_LISTENER_PROTOS="$(normalize_listener_protos "$normalized" "both")"
                validate_host "$INGRESS_PUBLIC_HOST" || die_user "INGRESS_PUBLIC_HOST 必须是公网 IP 或域名。"
                validate_port "$INGRESS_LISTENER_PORT" || die_user "INGRESS_LISTENER_PORT 必须是 1-65535 的端口。"
                ET_LISTENER_PROTO="$INGRESS_LISTENER_PROTO"
                ET_LISTENER_PORT="$INGRESS_LISTENER_PORT"
                ET_LISTENERS="$(listener_urls_value "$INGRESS_LISTENER_PROTO" "$INGRESS_LISTENER_PORT")"
            fi
            FORWARD_ENABLED="${FORWARD_ENABLED:-true}"
            ;;
        nat-transit)
            NAT_DIRECTION="$(normalize_nat_direction "${NAT_DIRECTION:-ingress-listener}")" || die_user "NAT_DIRECTION 只能是 ingress-listener 或 nat-listener。"
            require_config_var INGRESS_ET_IP
            require_config_var NAT_ET_IP
            require_config_var TRANSIT_PORT
            require_config_var LANDING_HOST
            require_config_var LANDING_PORT
            require_config_var FORWARD_PROTO
            validate_ipv4 "$INGRESS_ET_IP" || die_user "INGRESS_ET_IP 必须是 IPv4，例如 10.88.0.1。"
            [[ -z "${INGRESS_ET_CIDR:-}" ]] || validate_ipv4_cidr "$INGRESS_ET_CIDR" || die_user "INGRESS_ET_CIDR 必须是 IPv4/CIDR。"
            validate_ipv4 "$NAT_ET_IP" || die_user "NAT_ET_IP 必须是 IPv4，例如 10.88.0.2。"
            validate_ipv4_cidr "${NAT_ET_CIDR:-$ET_IPV4}" || die_user "NAT_ET_CIDR 必须是 IPv4/CIDR。"
            validate_port "$TRANSIT_PORT" || die_user "TRANSIT_PORT 必须是 1-65535 的端口。"
            validate_host "$LANDING_HOST" || die_user "LANDING_HOST 必须是 IPv4 或域名。"
            validate_port "$LANDING_PORT" || die_user "LANDING_PORT 必须是 1-65535 的端口。"
            normalized="$(normalize_forward_proto "$FORWARD_PROTO" "both")" || die_user "FORWARD_PROTO 只能是 tcp、udp 或 both。"
            FORWARD_PROTO="$normalized"
            NAT_ET_CIDR="${NAT_ET_CIDR:-$ET_IPV4}"
            [[ -z "${INGRESS_ET_CIDR:-}" || "${INGRESS_ET_CIDR%%/*}" == "$INGRESS_ET_IP" ]] || die_user "INGRESS_ET_IP 和 INGRESS_ET_CIDR 不一致。"
            [[ "${NAT_ET_CIDR%%/*}" == "$NAT_ET_IP" ]] || die_user "NAT_ET_IP 和 NAT_ET_CIDR 不一致。"
            if [[ "$NAT_DIRECTION" == "nat-listener" ]]; then
                require_config_var NAT_PUBLIC_HOST
                require_config_var NAT_LISTENER_PROTO
                require_config_var NAT_LISTENER_PORT
                normalized="$(normalize_listener_proto "$NAT_LISTENER_PROTO" "both")" || die_user "NAT_LISTENER_PROTO 只能是 tcp、udp、tcp+udp、ws、wss、quic、wg 或 all。"
                NAT_LISTENER_PROTO="$normalized"
                NAT_LISTENER_PROTOS="$(normalize_listener_protos "$normalized" "both")"
                validate_host "$NAT_PUBLIC_HOST" || die_user "NAT_PUBLIC_HOST 必须是 NAT IX 商家入口 IP 或域名。"
                validate_port "$NAT_LISTENER_PORT" || die_user "NAT_LISTENER_PORT 必须是 1-65535 的端口。"
                NAT_PUBLIC_PORTS="$(normalize_nat_public_ports_input "${NAT_PUBLIC_PORTS:-$NAT_LISTENER_PORT}")" || die_user "NAT_PUBLIC_PORTS 必须是合法端口列表。"
                NAT_LISTENER_PORT="$(first_nat_public_port "$NAT_PUBLIC_PORTS")"
                [[ -z "${INGRESS_PUBLIC_HOST:-}" ]] || validate_host "$INGRESS_PUBLIC_HOST" || die_user "INGRESS_PUBLIC_HOST 必须是公网 IP 或域名。"
                refresh_nat_public_endpoints_for_profile "${PROFILE_ID:-default}"
                ET_NO_LISTENER="${ET_NO_LISTENER:-false}"
            else
                require_config_var INGRESS_PUBLIC_HOST
                require_config_var INGRESS_LISTENER_PROTO
                require_config_var INGRESS_LISTENER_PORT
                normalized="$(normalize_entry_proto "$INGRESS_LISTENER_PROTO" "both")" || die_user "INGRESS_LISTENER_PROTO 只能是 tcp、udp、tcp+udp、ws、wss、quic、wg 或 all。"
                INGRESS_LISTENER_PROTO="$normalized"
                INGRESS_LISTENER_PROTOS="$(normalize_peer_protos "$normalized" "both")"
                validate_host "$INGRESS_PUBLIC_HOST" || die_user "INGRESS_PUBLIC_HOST 必须是公网 IP 或域名。"
                validate_port "$INGRESS_LISTENER_PORT" || die_user "INGRESS_LISTENER_PORT 必须是 1-65535 的端口。"
                ET_PEERS="$(peer_urls_value "$INGRESS_LISTENER_PROTO" "$INGRESS_PUBLIC_HOST" "$INGRESS_LISTENER_PORT")"
                ET_NO_LISTENER="${ET_NO_LISTENER:-true}"
            fi
            FORWARD_ENABLED="${FORWARD_ENABLED:-true}"
            ;;
        *)
            die_user "ROLE 必须是 nat-ingress 或 nat-transit。"
            ;;
    esac
}

easytier_supports_private_mode() {
    local et_path help_text
    et_path="$(detect_easytier_binary 2>/dev/null || true)"
    [[ -n "$et_path" ]] || return 0
    help_text="$("$et_path" --help 2>&1 || true)"
    grep -q -- '--private-mode' <<<"$help_text"
}

render_private_mode_arg() {
    if easytier_supports_private_mode; then
        printf ' --private-mode true'
    else
        log_warn "当前 easytier-core 帮助信息未发现 --private-mode，已跳过该参数；请确认未配置公共 peer。"
    fi
}

easytier_supports_explicit_only() {
    local et_path help_text
    et_path="$(detect_easytier_binary 2>/dev/null || true)"
    [[ -n "$et_path" ]] || return 0
    help_text="$("$et_path" --help 2>&1 || true)"
    grep -q -- '--explicit-only' <<<"$help_text"
}

render_explicit_only_arg() {
    [[ "${ET_EXPLICIT_ONLY:-${IXTF_EXPLICIT_ONLY:-true}}" == "true" ]] || return 0
    if easytier_supports_explicit_only; then
        printf ' --explicit-only true'
    fi
}

validate_easytier_args_static() {
    local rendered="$1"
    case "${ROLE:-}" in
        nat-ingress)
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                [[ -n "${ET_PEERS:-}" ]] || return 1
            else
                [[ -n "${ET_LISTENERS:-}" ]] || return 1
            fi
            ;;
        nat-transit)
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                [[ -n "${ET_LISTENERS:-}" ]] || return 1
            else
                [[ -n "${ET_PEERS:-}" ]] || return 1
            fi
            ;;
        *) return 1 ;;
    esac
    [[ "$rendered" != *"--private-mode --"* ]] || return 1
    [[ "$rendered" != *"--private-mode"$'\n'* ]] || return 1
    if [[ "$rendered" == *"--private-mode"* && "$rendered" != *"--private-mode true"* && "$rendered" != *"--private-mode=true"* ]]; then
        return 1
    fi
    [[ "$rendered" != *"${ET_NETWORK_SECRET:-}"* ]]
}

load_install_env_file() {
    local expected_role="$1"
    [[ -n "$INSTALL_ENV_FILE_PATH" ]] || return 1
    load_env_from_path "$INSTALL_ENV_FILE_PATH" || die_user "无法读取 env 文件：${INSTALL_ENV_FILE_PATH}"
    require_config_var ROLE
    [[ "$ROLE" == "$expected_role" ]] || die_user "env 文件中的 ROLE=${ROLE}，但当前命令需要 ROLE=${expected_role}。"
    validate_easytier_args
    log_ok "已加载非交互 env 文件：${INSTALL_ENV_FILE_PATH}"
    return 0
}

render_easytier_args() {
    local secret_display listener peer
    validate_easytier_args
    secret_display="$(mask_secret "$ET_NETWORK_SECRET")"

    printf 'ET_NETWORK_SECRET=%q easytier-core' "$secret_display"
    printf ' --network-name %q' "$ET_NETWORK_NAME"
    printf ' --hostname %q' "$ET_HOSTNAME"
    printf ' --ipv4 %q' "$ET_IPV4"
    render_private_mode_arg
    render_explicit_only_arg

    if profile_uses_easytier_listener; then
        [[ -n "${ET_LISTENERS:-}" ]] || die_user "landing 必须至少有一个 listener。"
        while IFS= read -r listener; do
            [[ -n "$listener" ]] || continue
            printf ' --listeners %q' "$listener"
        done <<<"${ET_LISTENERS// /$'\n'}"
    else
        [[ -n "${ET_PEERS:-}" ]] || die_user "ingress 必须至少有一个 peer。"
        while IFS= read -r peer; do
            [[ -n "$peer" ]] || continue
            printf ' --peers %q' "$peer"
        done <<<"${ET_PEERS// /$'\n'}"
        if [[ "${ET_NO_LISTENER:-true}" == "true" ]]; then
            printf ' --no-listener'
        fi
    fi
    printf '\n'
}

print_easytier_peers() {
    local peer
    validate_easytier_args
    printf 'peers:\n'
    while IFS= read -r peer; do
        [[ -n "$peer" ]] || continue
        printf '  %s\n' "$peer"
    done <<<"${ET_PEERS// /$'\n'}"
}

print_easytier_listeners() {
    local listener
    validate_easytier_args
    printf 'listeners:\n'
    while IFS= read -r listener; do
        [[ -n "$listener" ]] || continue
        printf '  %s\n' "$listener"
    done <<<"${ET_LISTENERS// /$'\n'}"
}

print_easytier_endpoint_summary() {
    local count mapped_supported="未知" et_path
    case "${ROLE:-}" in
        nat-ingress)
            if [[ -n "${ET_PEERS:-}" ]]; then
                count="$(easytier_url_list_count "$ET_PEERS")"
                printf 'EasyTier peers（%s 个）：\n' "$count"
                print_easytier_url_list "$ET_PEERS"
            else
                printf 'EasyTier peers：未配置\n'
            fi
            ;;
        nat-transit)
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                if [[ -n "${ET_LISTENERS:-}" ]]; then
                    count="$(easytier_url_list_count "$ET_LISTENERS")"
                    printf 'EasyTier listeners（%s 个）：\n' "$count"
                    print_easytier_url_list "$ET_LISTENERS"
                else
                    printf 'EasyTier listeners：未配置\n'
                fi
                if [[ -n "${ET_MAPPED_LISTENERS:-}" ]]; then
                    count="$(easytier_url_list_count "$ET_MAPPED_LISTENERS")"
                    et_path="$(detect_easytier_binary 2>/dev/null || true)"
                    if [[ -n "$et_path" ]] && "$et_path" --help 2>&1 | grep -q -- '--mapped-listeners'; then
                        mapped_supported="是"
                    elif [[ -n "$et_path" ]]; then
                        mapped_supported="否（当前 EasyTier 不支持 --mapped-listeners）"
                    fi
                    printf 'EasyTier mapped-listeners（%s 个，运行时启用：%s）：\n' "$count" "$mapped_supported"
                    print_easytier_url_list "$ET_MAPPED_LISTENERS"
                else
                    printf 'EasyTier mapped-listeners：未配置\n'
                fi
            elif [[ -n "${ET_PEERS:-}" ]]; then
                count="$(easytier_url_list_count "$ET_PEERS")"
                printf 'EasyTier peers（%s 个）：\n' "$count"
                print_easytier_url_list "$ET_PEERS"
            else
                printf 'EasyTier peers：未配置\n'
            fi
            ;;
        nat-ingress)
            if [[ -n "${ET_PEERS:-}" ]]; then
                count="$(easytier_url_list_count "$ET_PEERS")"
                printf 'EasyTier peers（%s 个）：\n' "$count"
                print_easytier_url_list "$ET_PEERS"
            else
                printf 'EasyTier peers：未配置\n'
            fi
            ;;
    esac
}

render_easytier_wrapper() {
    install -d -m 0755 "$LIBEXEC_DIR"
    local tmp
    tmp="$(make_tmp_file "ix-transit-fabric.wrapper")"

    cat >"$tmp" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail

DEFAULT_ENV_FILE="${ENV_FILE}"
CONFIG_DIR="${CONFIG_DIR}"
EASYTIER_TARGET="${EASYTIER_TARGET}"
PROFILE_ID="\${1:-}"

if [[ -n "\$PROFILE_ID" ]]; then
    case "\$PROFILE_ID" in
        *[!a-z0-9-]*|'') echo "ix-transit-fabric: PROFILE_ID 不合法：\$PROFILE_ID" >&2; exit 1 ;;
    esac
    ENV_FILE="\${CONFIG_DIR}/profiles/\${PROFILE_ID}.env"
else
    ENV_FILE="\$DEFAULT_ENV_FILE"
fi

if [[ ! -r "\$ENV_FILE" ]]; then
    echo "ix-transit-fabric: 配置文件不可读：\$ENV_FILE" >&2
    exit 1
fi

set -a
. "\$ENV_FILE"
set +a

require_var() {
    local name="\$1"
    if [[ -z "\${!name:-}" ]]; then
        echo "ix-transit-fabric: 必需变量为空：\$name" >&2
        exit 1
    fi
}

require_var ROLE
require_var ET_NETWORK_NAME
require_var ET_NETWORK_SECRET
require_var ET_HOSTNAME
require_var ET_IPV4

if [[ -x "\$EASYTIER_TARGET" ]]; then
    EASYTIER_BIN="\$EASYTIER_TARGET"
elif command -v easytier-core >/dev/null 2>&1; then
    EASYTIER_BIN="\$(command -v easytier-core)"
else
    echo "ix-transit-fabric: 未找到 easytier-core" >&2
    exit 1
fi

args=(
    --network-name "\$ET_NETWORK_NAME"
    --hostname "\$ET_HOSTNAME"
    --ipv4 "\$ET_IPV4"
)

if [[ "\${ET_PRIVATE_MODE:-true}" == "true" ]]; then
    if "\$EASYTIER_BIN" --help 2>&1 | grep -q -- '--private-mode'; then
        args+=(--private-mode true)
    else
        echo "ix-transit-fabric: easytier-core 未声明支持 --private-mode，已跳过该参数" >&2
    fi
fi

if [[ "\${ET_EXPLICIT_ONLY:-\${IXTF_EXPLICIT_ONLY:-true}}" == "true" ]]; then
    if "\$EASYTIER_BIN" --help 2>&1 | grep -q -- '--explicit-only'; then
        args+=(--explicit-only true)
    fi
fi

case "\$ROLE" in
    nat-ingress)
        if [[ "\${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
            require_var ET_PEERS
            read -r -a peer_items <<<"\$ET_PEERS"
            for peer in "\${peer_items[@]}"; do
                [[ -n "\$peer" ]] || continue
                args+=(--peers "\$peer")
            done
            if [[ "\${ET_NO_LISTENER:-true}" == "true" ]]; then
                args+=(--no-listener)
            fi
        else
            require_var ET_LISTENERS
            read -r -a listener_items <<<"\$ET_LISTENERS"
            for listener in "\${listener_items[@]}"; do
                [[ -n "\$listener" ]] || continue
                args+=(--listeners "\$listener")
            done
        fi
        ;;
    nat-transit)
        if [[ "\${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
            require_var ET_LISTENERS
            read -r -a listener_items <<<"\$ET_LISTENERS"
            for listener in "\${listener_items[@]}"; do
                [[ -n "\$listener" ]] || continue
                args+=(--listeners "\$listener")
            done
            if [[ -n "\${ET_MAPPED_LISTENERS:-}" ]]; then
                if "\$EASYTIER_BIN" --help 2>&1 | grep -q -- '--mapped-listeners'; then
                    read -r -a mapped_items <<<"\$ET_MAPPED_LISTENERS"
                    for mapped in "\${mapped_items[@]}"; do
                        [[ -n "\$mapped" ]] || continue
                        args+=(--mapped-listeners "\$mapped")
                    done
                fi
            fi
        else
            require_var ET_PEERS
            read -r -a peer_items <<<"\$ET_PEERS"
            for peer in "\${peer_items[@]}"; do
                [[ -n "\$peer" ]] || continue
                args+=(--peers "\$peer")
            done
            if [[ "\${ET_NO_LISTENER:-true}" == "true" ]]; then
                args+=(--no-listener)
            fi
        fi
        ;;
    *)
        echo "ix-transit-fabric: 未知 ROLE：\$ROLE" >&2
        exit 1
        ;;
esac

exec "\$EASYTIER_BIN" "\${args[@]}"
EOF

    install_if_changed "$tmp" "$WRAPPER_FILE" 0755 "EasyTier 启动包装器"
}

ix_cli_source_path() {
    local path="${BASH_SOURCE[0]:-$0}"
    if [[ "$path" != /* ]]; then
        path="$(cd -P "$(dirname "$path")" && pwd)/$(basename "$path")"
    fi
    if command_exists readlink; then
        readlink -f "$path" 2>/dev/null && return 0
    fi
    printf '%s\n' "$path"
}

sync_ix_cli_install_sh() {
    local src dest tmp
    src="$(ix_cli_source_path)"
    dest="$IX_CLI_INSTALL_SH"
    install -d -m 0755 "$LIBEXEC_DIR"
    if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
        log_debug "ix CLI 安装脚本已是最新：${dest}"
        return 0
    fi
    tmp="$(make_tmp_file "ix-transit-fabric.install")"
    cp -a -- "$src" "$tmp"
    chmod 0755 "$tmp"
    backup_file "$dest"
    install -m 0755 "$tmp" "$dest"
    rm -f -- "$tmp"
    log_debug "已同步 ix CLI 安装脚本：${dest}"
}

render_ix_cli_wrapper_file() {
    cat <<EOF
#!/usr/bin/env bash
exec bash "${IX_CLI_INSTALL_SH}" ix "\$@"
EOF
}

render_ix_cli_wrappers() {
    local tmp_ix tmp_IX
    tmp_ix="$(make_tmp_file "ix-transit-fabric.ix-cli")"
    tmp_IX="$(make_tmp_file "ix-transit-fabric.IX-cli")"
    render_ix_cli_wrapper_file >"$tmp_ix"
    cp -a -- "$tmp_ix" "$tmp_IX"
    install_if_changed "$tmp_ix" "$IX_CLI_BIN" 0755 "ix 快捷命令"
    install_if_changed "$tmp_IX" "$IX_CLI_BIN_UPPER" 0755 "IX 快捷命令"
}

ensure_ix_cli_shortcut() {
    require_root
    sync_ix_cli_install_sh
    render_ix_cli_wrappers
}

install_ix_cli() {
    require_root "$@"
    ensure_ix_cli_shortcut
    log_ok "已安装快捷命令：ix / IX（直接输入即可进入管理菜单）"
    log_info "安装脚本副本：${IX_CLI_INSTALL_SH}"
    if [[ -x "$IX_CLI_BIN" && -x "$IX_CLI_BIN_UPPER" ]]; then
        log_ok "验证通过：$(command -v ix) 与 $(command -v IX)"
    fi
}

remove_ix_cli_shortcut() {
    rm -f -- "$IX_CLI_BIN" "$IX_CLI_BIN_UPPER" "$IX_CLI_INSTALL_SH"
    log_debug "已删除 ix / IX 快捷命令与安装脚本副本（若存在）。"
}

render_systemd_service() {
    validate_easytier_args
    local rendered_args
    rendered_args="$(render_easytier_args)"
    validate_easytier_args_static "$rendered_args" || die_user "EasyTier 参数静态校验失败：不能生成裸 --private-mode，且不能输出网络密钥明文。"
    render_easytier_wrapper

    local nft_bin tmp
    tmp="$(make_tmp_file "ix-transit-fabric.service")"

    {
        printf '[Unit]\n'
        printf 'Description=ix-transit-fabric EasyTier node\n'
        printf 'After=network-online.target\n'
        printf 'Wants=network-online.target\n\n'
        printf '[Service]\n'
        printf 'Type=simple\n'
        printf 'EnvironmentFile=%s\n' "$ENV_FILE"
        printf 'ExecStartPre=/usr/bin/test -r %s\n' "$ENV_FILE"
        printf 'ExecStartPre=/usr/bin/test -x %s\n' "$WRAPPER_FILE"
        printf "ExecStartPre=/bin/sh -c 'test -x %s || command -v easytier-core >/dev/null 2>&1'\n" "$EASYTIER_TARGET"
        if [[ ( "${ROLE:-}" == "nat-ingress" || "${ROLE:-}" == "nat-transit" ) && "${FORWARD_ENABLED:-true}" == "true" ]]; then
            nft_bin="$(command -v nft 2>/dev/null || true)"
            [[ -n "$nft_bin" ]] || nft_bin="/usr/sbin/nft"
            printf 'ExecStartPre=/usr/bin/test -f %s\n' "$NFT_FILE"
            printf 'ExecStartPre=%s -c -f %s\n' "$nft_bin" "$NFT_FILE"
            printf 'ExecStartPre=-%s delete table ip %s\n' "$nft_bin" "$NFT_TABLE"
            printf 'ExecStartPre=%s -f %s\n' "$nft_bin" "$NFT_FILE"
        fi
        printf 'ExecStart=%s\n' "$WRAPPER_FILE"
        printf 'Restart=on-failure\n'
        printf 'RestartSec=3\n'
        printf 'StartLimitIntervalSec=60\n'
        printf 'StartLimitBurst=5\n'
        printf 'User=root\n'
        printf 'LimitNOFILE=1048576\n\n'
        printf '[Install]\n'
        printf 'WantedBy=multi-user.target\n'
    } >"$tmp"

    install_if_changed "$tmp" "$SYSTEMD_SERVICE" 0644 "systemd 服务"
	}

render_profile_systemd_template() {
    local tmp
    tmp="$(make_tmp_file "ix-transit-fabric.profile-service")"
    {
        printf '[Unit]\n'
        printf 'Description=ix-transit-fabric EasyTier profile %%i\n'
        printf 'After=network-online.target\n'
        printf 'Wants=network-online.target\n\n'
        printf '[Service]\n'
        printf 'Type=simple\n'
        printf 'ExecStartPre=/usr/bin/test -r %s/profiles/%%i.env\n' "$CONFIG_DIR"
        printf 'ExecStartPre=/usr/bin/test -x %s\n' "$WRAPPER_FILE"
        printf "ExecStartPre=/bin/sh -c 'test -x %s || command -v easytier-core >/dev/null 2>&1'\n" "$EASYTIER_TARGET"
        printf 'ExecStart=%s %%i\n' "$WRAPPER_FILE"
        printf 'Restart=on-failure\n'
        printf 'RestartSec=3\n'
        printf 'StartLimitIntervalSec=60\n'
        printf 'StartLimitBurst=5\n'
        printf 'User=root\n'
        printf 'LimitNOFILE=1048576\n\n'
        printf '[Install]\n'
        printf 'WantedBy=multi-user.target\n'
    } >"$tmp"
    install_if_changed "$tmp" "$PROFILE_SERVICE_TEMPLATE" 0644 "systemd 模板服务"
}

render_profile_service_files() {
    render_easytier_wrapper
    render_profile_systemd_template
    _IXTF_PROFILE_SERVICE_FILES_READY="true"
}

restart_easytier() {
    local rc
    ensure_systemctl
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME" >/dev/null
    set +e
    systemctl restart "$SERVICE_NAME" >/dev/null 2>&1
    rc=$?
    set -e
    if [[ "$rc" -ne 0 ]]; then
        log_warn "systemctl restart ${SERVICE_NAME} 返回非 0（${rc}），继续执行健康检查。"
    fi
    sleep 3
    if health_check_easytier; then
        log_ok "EasyTier 服务健康检查通过。"
    else
        log_warn "EasyTier 服务已提交启动，但健康检查未通过。"
        log_warn "请运行：bash install.sh logs"
        analyze_recent_easytier_logs
    fi
}

status_easytier() {
    status_easytier_detailed
}

check_easytier_process() {
    if command_exists pgrep; then
        pgrep -x easytier-core >/dev/null 2>&1 || pgrep -f 'easytier-core' >/dev/null 2>&1
        return $?
    fi
    ps -ef 2>/dev/null | grep -F 'easytier-core' | grep -v grep >/dev/null 2>&1
}

check_et_ip_present() {
    local et_ip="${1:-${ET_IPV4:-}}"
    et_ip="${et_ip%%/*}"
    [[ -n "$et_ip" ]] || return 1
    command_exists ip || return 2
    ip addr show 2>/dev/null | grep -Fq "$et_ip"
}

# 0=网卡可见 3=未挂网卡但 peer 路由可用 2=无法检查 1=不可用
assess_et_ip_health() {
    local et_ip="${1:-${ET_IPV4:-}}"
    et_ip="${et_ip%%/*}"
    [[ -n "$et_ip" ]] || return 1
    command_exists ip || return 2
    if ip addr show 2>/dev/null | grep -Fq "$et_ip"; then
        return 0
    fi
    check_easytier_process || return 1
    case "${ROLE:-}" in
        nat-transit)
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" && -n "${INGRESS_ET_IP:-}" ]]; then
                ip route get "$INGRESS_ET_IP" >/dev/null 2>&1 && return 3
            fi
            ;;
        nat-ingress)
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" && -n "${NAT_ET_IP:-}" ]]; then
                ip route get "$NAT_ET_IP" >/dev/null 2>&1 && return 3
            fi
            ;;
    esac
    return 1
}

et_ip_health_label() {
    case "$1" in
        0) printf '存在\n' ;;
        3) printf '未挂网卡但虚拟网可用\n' ;;
        2) printf '无法检查\n' ;;
        *) printf '不存在\n' ;;
    esac
}

apply_et_ip_health_mark() {
    case "$1" in
        2) health_mark warning "无法检查本机虚拟 IP" ;;
        1) health_mark down "本机虚拟 IP 不存在" ;;
    esac
}

check_listener_present() {
    profile_uses_easytier_listener || return 3
    check_listener_proto_port "${ET_LISTENER_PROTO:-tcp}" "${ET_LISTENER_PORT:-0}"
}

print_recent_service_logs() {
    local lines="${1:-20}"
    local secret="${ET_NETWORK_SECRET:-}"
    command_exists journalctl || return 0
    journalctl -u "$SERVICE_NAME" -n "$lines" --no-pager 2>&1 | while IFS= read -r line; do
        if [[ -n "$secret" ]]; then
            line="${line//$secret/[hidden]}"
        fi
        printf '%s\n' "$line"
    done
}

recent_service_logs_text() {
    local lines="${1:-80}"
    command_exists journalctl || return 0
    journalctl -u "$SERVICE_NAME" -n "$lines" --no-pager 2>&1 || true
}

analyze_recent_easytier_logs() {
    local logs_text
    logs_text="$(recent_service_logs_text 80)"
    [[ -n "$logs_text" ]] || return 0
    if grep -qi -- 'private-mode' <<<"$logs_text"; then
        log_warn "检测到 EasyTier 参数 private-mode 相关日志：旧版本可能生成过裸 --private-mode。请使用当前 1.0.0 脚本重新配置。"
    fi
    if grep -Eqi 'Address in use|failed to listen' <<<"$logs_text"; then
        log_warn "检测到 listener 端口被占用或监听失败。请更换 EasyTier listener 端口，不要直接杀业务进程。"
    fi
}

health_check_easytier() {
    local active rc proc_ok="false" ip_ok="false" role_ok="false"
    if command_exists systemctl; then
        active="$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || true)"
        [[ "$active" == "active" || "$active" == "activating" ]] || return 1
    fi

    if check_easytier_process; then
        proc_ok="true"
    fi

    set +e
    assess_et_ip_health
    rc=$?
    set -e
    [[ "$rc" -eq 0 || "$rc" -eq 2 || "$rc" -eq 3 ]] && ip_ok="true"

    if profile_uses_easytier_listener; then
            set +e
            check_listener_present
            rc=$?
            set -e
            [[ "$rc" -eq 0 || "$rc" -eq 2 ]] && role_ok="true"
    else
        case "${ROLE:-}" in
            nat-ingress|nat-transit)
            [[ -n "${ET_PEERS:-}" ]] && role_ok="true"
            ;;
            *)
                role_ok="false"
                ;;
        esac
    fi

    [[ "$proc_ok" == "true" && "$ip_ok" == "true" && "$role_ok" == "true" ]]
}

ensure_listener_port_available_before_start() {
    validate_easytier_args
    profile_uses_easytier_listener || return 0
    if command_exists systemctl; then
        systemctl stop "$SERVICE_NAME" >/dev/null 2>&1 || true
        cleanup_own_service_processes
    fi
    if validate_listener_port_available "$ET_LISTENER_PROTO" "$ET_LISTENER_PORT"; then
        return 0
    fi
    if [[ "${ET_LISTENER_PORT_WAS_DEFAULT:-false}" == "true" ]]; then
        local new_port
        if new_port="$(pick_random_port_excluding_listeners "$ET_LISTENER_PROTO")"; then
            log_warn "默认 listener 端口被占用，已自动重新随机：${new_port}"
            ET_LISTENER_PORT="$new_port"
            ET_LISTENERS="$(listener_urls_value "$ET_LISTENER_PROTO" "$ET_LISTENER_PORT")"
            return 0
        fi
    fi
    die_user "当前端口已被占用，不能作为 EasyTier listener。请换一个端口。"
}

cleanup_own_service_processes() {
    local control_group cg_path pid
    command_exists systemctl || return 0
    control_group="$(systemctl show -p ControlGroup --value "$SERVICE_NAME" 2>/dev/null || true)"
    [[ -n "$control_group" && "$control_group" != "/" ]] || return 0
    cg_path="/sys/fs/cgroup${control_group}"
    [[ -r "${cg_path}/cgroup.procs" ]] || return 0
    while IFS= read -r pid; do
        [[ "$pid" =~ ^[0-9]+$ ]] || continue
        [[ "$pid" -ne "$$" ]] || continue
        kill "$pid" >/dev/null 2>&1 || true
    done <"${cg_path}/cgroup.procs"
}

profile_systemd_units() {
    local id
    {
        for id in $(profile_ids); do
            profile_service_name "$id"
        done
        if command_exists systemctl; then
            systemctl list-units 'ix-transit-easytier@*.service' --all --no-legend --no-pager 2>/dev/null | awk '{print $1}'
            systemctl list-unit-files 'ix-transit-easytier@*.service' --no-legend --no-pager 2>/dev/null | awk '{print $1}'
        fi
    } | while IFS= read -r unit; do
        case "$unit" in
            ix-transit-easytier@?*.service) printf '%s\n' "$unit" ;;
        esac
    done | sort -u
}

stop_disable_profile_services() {
    local unit
    command_exists systemctl || return 0
    while IFS= read -r unit; do
        [[ -n "$unit" ]] || continue
        systemctl stop "$unit" >/dev/null 2>&1 || true
        systemctl disable "$unit" >/dev/null 2>&1 || true
        systemctl reset-failed "$unit" >/dev/null 2>&1 || true
    done < <(profile_systemd_units)
}

status_easytier_detailed() {
    local service_name="${1:-$SERVICE_NAME}"
    local et_path active enabled version active_since ts now age proc_status ip_status listener_status peer_status ready_status rc
    et_path="$(detect_easytier_binary 2>/dev/null || true)"
    if [[ -n "$et_path" ]]; then
        version="$(get_easytier_version "$et_path")"
        printf 'EasyTier 程序路径：%s\n' "$et_path"
        printf 'EasyTier 版本：%s\n' "$version"
    else
        printf 'EasyTier 程序路径：未找到\n'
        printf 'EasyTier 版本：未知\n'
    fi

    if command_exists systemctl; then
        active="$(systemctl is-active "$service_name" 2>/dev/null || true)"
        enabled="$(systemctl is-enabled "$service_name" 2>/dev/null || true)"
        printf 'systemd 状态：%s（开机自启：%s）\n' "${active:-未知}" "${enabled:-未知}"
    else
        active="unknown"
        printf 'systemd 状态：systemctl 不可用\n'
    fi

    if check_easytier_process; then
        proc_status="存在"
    else
        proc_status="不存在"
    fi
    printf 'easytier-core 进程：%s\n' "$proc_status"

    set +e
    check_et_ip_present
    rc=$?
    set -e
    case "$rc" in
        0) ip_status="存在" ;;
        2) ip_status="无法检查（ip 命令不可用）" ;;
        *) ip_status="不存在" ;;
    esac
    printf '本机 EasyTier 虚拟 IP：%s\n' "$ip_status"

    case "${ROLE:-}" in
        nat-transit|nat-ingress)
            set +e
            check_listener_present
            rc=$?
            set -e
            case "$rc" in
                0) listener_status="已监听" ;;
                2) listener_status="无法检查（ss 命令不可用）" ;;
                *) listener_status="未监听" ;;
            esac
            printf 'EasyTier listener：%s\n' "$listener_status"
            ;;
        nat-ingress|nat-transit)
            if [[ -n "${ET_PEERS:-}" ]]; then
                peer_status="存在"
                printf 'EasyTier peer 配置：存在\n'
                printf 'peers:\n'
                while IFS= read -r peer; do
                    [[ -n "$peer" ]] || continue
                    printf '  %s\n' "$peer"
                done <<<"${ET_PEERS// /$'\n'}"
            else
                peer_status="不存在"
                printf 'EasyTier peer 配置：不存在\n'
            fi
            if [[ "${FORWARD_ENABLED:-true}" == "true" ]]; then
                printf '业务转发：已配置\n'
            else
                printf '业务转发：未配置\n'
            fi
            ;;
    esac

    if [[ "$active" == "activating" ]]; then
        active_since="$(systemctl show "$service_name" -p ActiveEnterTimestamp --value 2>/dev/null || true)"
        ts="$(date -d "$active_since" +%s 2>/dev/null || printf '')"
        now="$(date +%s)"
        age=""
        [[ -n "$ts" ]] && age=$((now - ts))
        ready_status="false"
        if [[ ( "${ROLE:-}" == "nat-transit" && "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" || "${ROLE:-}" == "nat-ingress" ) && "$proc_status" == "存在" && "$ip_status" == "存在" && "${listener_status:-未监听}" == "已监听" ]]; then
            ready_status="true"
        elif [[ ( "${ROLE:-}" == "nat-ingress" || "${ROLE:-}" == "nat-transit" ) && "$proc_status" == "存在" && "$ip_status" == "存在" && "${peer_status:-不存在}" == "存在" ]]; then
            ready_status="true"
        fi
        if [[ "$ready_status" == "true" ]]; then
            printf '[WARN] systemd 仍显示 activating，但 EasyTier 进程和关键运行状态存在，可能是服务类型/前台行为差异。建议运行 logs 确认。\n'
        else
            if [[ -n "$age" && "$age" -gt 30 ]]; then
                printf '[WARN] 服务仍在 activating（约 %s 秒），且进程/IP/监听检查未全部通过，建议运行 bash install.sh logs。\n' "$age"
            else
                printf '[WARN] 服务仍在 activating，且进程/IP/监听检查未全部通过，建议运行 bash install.sh logs。\n'
            fi
        fi
    fi
}

enable_ip_forward() {
    local tmp
    tmp="$(make_tmp_file "ix-transit-fabric.sysctl")"
    {
        printf '# Managed by ix-transit-fabric\n'
        printf 'net.ipv4.ip_forward=1\n'
    } >"$tmp"

    backup_file "$SYSCTL_FILE"
    install -m 0644 "$tmp" "$SYSCTL_FILE"
    rm -f -- "$tmp"
    sysctl -w net.ipv4.ip_forward=1 >/dev/null
    log_debug "已开启 IPv4 转发：net.ipv4.ip_forward=1"
}

profile_needs_nft_forward() {
    case "${ROLE:-}" in
        nat-ingress|nat-transit)
            [[ "${ENABLED:-true}" == "true" && "${FORWARD_ENABLED:-true}" == "true" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

landing_ip_for_nft() {
    local host="${1:-${LANDING_HOST:-}}" resolved
    [[ -n "$host" ]] || return 1
    if validate_ipv4 "$host"; then
        printf '%s\n' "$host"
        return 0
    fi
    resolved="$(resolve_host_ipv4 "$host" 2>/dev/null || true)"
    if [[ -n "$resolved" ]]; then
        printf '%s\n' "$resolved"
        return 0
    fi
    if [[ -n "${LANDING_IP:-}" ]] && validate_ipv4 "$LANDING_IP"; then
        printf '%s\n' "$LANDING_IP"
        return 0
    fi
    log_warn "LANDING_HOST 域名解析失败：${host}，已中止应用 nftables。"
    return 1
}

resolve_host_ipv4() {
    local host="$1" resolved
    host="$(trim_space "$host")"
    [[ -n "$host" ]] || return 1
    if validate_ipv4 "$host"; then
        printf '%s\n' "$host"
        return 0
    fi
    if command_exists getent; then
        resolved="$(getent ahostsv4 "$host" 2>/dev/null | awk '{print $1; exit}')"
        if [[ -n "$resolved" ]] && validate_ipv4 "$resolved"; then
            printf '%s\n' "$resolved"
            return 0
        fi
    fi
    return 1
}

host_is_domain() {
    local host="$1"
    [[ -n "$host" ]] || return 1
    validate_ipv4 "$host" && return 1
    validate_host "$host"
}

ddns_try_update_host_ip() {
    local host_var="$1" ip_var="$2" host old_ip new_ip
    host="${!host_var:-}"
    host_is_domain "$host" || return 1
    old_ip="${!ip_var:-}"
    new_ip="$(resolve_host_ipv4 "$host")" || return 1
    [[ "$new_ip" != "$old_ip" ]] || return 1
    printf -v "$ip_var" '%s' "$new_ip"
    return 0
}

ddns_seed_profile_resolved_ips() {
    local profile_id="${1:-${PROFILE_ID:-}}" rule_id
    ddns_try_update_host_ip LANDING_HOST LANDING_IP || true
    ddns_try_update_host_ip NAT_PUBLIC_HOST NAT_PUBLIC_IP || true
    ddns_try_update_host_ip INGRESS_PUBLIC_HOST INGRESS_PUBLIC_IP || true
    if profile_supports_forward_rules; then
        for rule_id in $(profile_rule_ids "$profile_id"); do
            load_rule "$profile_id" "$rule_id" || continue
            if ddns_try_update_host_ip LANDING_HOST LANDING_IP; then
                save_rule_env "$profile_id" "$rule_id" || true
            fi
        done
    fi
}

ddns_refresh_profile() {
    local profile_id="$1" changed=0 need_restart=0 rule_id
    profile_id="$(resolve_profile_id "$profile_id")"
    load_profile "$profile_id" || return 1
    [[ "${ENABLED:-true}" == "true" ]] || return 0
    normalize_profile_compat_vars

    if ddns_try_update_host_ip LANDING_HOST LANDING_IP; then changed=1; fi
    if ddns_try_update_host_ip NAT_PUBLIC_HOST NAT_PUBLIC_IP; then changed=1; need_restart=1; fi
    if ddns_try_update_host_ip INGRESS_PUBLIC_HOST INGRESS_PUBLIC_IP; then changed=1; need_restart=1; fi

    if profile_supports_forward_rules; then
        for rule_id in $(profile_rule_ids "$profile_id"); do
            load_rule "$profile_id" "$rule_id" || continue
            [[ "${RULE_ENABLED:-true}" == "true" ]] || continue
            if ddns_try_update_host_ip LANDING_HOST LANDING_IP; then
                save_rule_env "$profile_id" "$rule_id" || return 1
                changed=1
            fi
        done
    fi

    [[ "$changed" -eq 1 ]] || return 1
    save_profile_env "$profile_id"
    if [[ "${FORWARD_ENABLED:-true}" == "true" ]]; then
        apply_nft_all || log_warn "DDNS：nftables 重载失败，请运行 bash install.sh apply-nft-all"
    fi
    if [[ "$need_restart" -eq 1 ]] && command_exists systemctl; then
        restart_profile "$profile_id" || log_warn "DDNS：EasyTier 重启失败，请运行 bash install.sh restart-profile ${profile_id}"
    fi
    log_ok "DDNS 已更新线路 ${profile_id} 的域名解析。"
    return 0
}

ddns_refresh_all() {
    require_root "$@"
    local id updated=0
    ensure_profile_dirs
    for id in $(profile_ids); do
        if ddns_refresh_profile "$id"; then
            updated=$((updated + 1))
        fi
    done
    date -u +%Y-%m-%dT%H:%M:%SZ >"$DDNS_LAST_RUN_FILE" 2>/dev/null || true
    chmod 600 "$DDNS_LAST_RUN_FILE" 2>/dev/null || true
    if [[ "$updated" -eq 0 ]]; then
        log_debug "DDNS：所有域名解析未变化。"
    fi
}

ddns_interval_minutes() {
    if [[ -r "$DDNS_INTERVAL_FILE" ]]; then
        awk 'NR==1 && $1 ~ /^[0-9]+$/ {print $1; found=1} END{if (!found) print '"$DDNS_DEFAULT_INTERVAL_MINUTES"'}' "$DDNS_INTERVAL_FILE"
    else
        printf '%s\n' "$DDNS_DEFAULT_INTERVAL_MINUTES"
    fi
}

render_ddns_systemd_files() {
    local interval script_path tmp_service tmp_timer
    ensure_profile_dirs
    install -d -m 700 "$STATE_DIR"
    interval="$(ddns_interval_minutes)"
    script_path="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
    tmp_service="$(make_tmp_file "ix-transit-ddns.service")"
    tmp_timer="$(make_tmp_file "ix-transit-ddns.timer")"
    {
        printf '[Unit]\n'
        printf 'Description=ix-transit-fabric DDNS refresh\n\n'
        printf '[Service]\n'
        printf 'Type=oneshot\n'
        printf 'ExecStart=/bin/bash %s ddns-refresh --timer\n' "$script_path"
    } >"$tmp_service"
    {
        printf '[Unit]\n'
        printf 'Description=ix-transit-fabric DDNS timer\n\n'
        printf '[Timer]\n'
        printf 'OnBootSec=90s\n'
        printf 'OnUnitActiveSec=%smin\n' "$interval"
        printf 'AccuracySec=30s\n'
        printf 'Persistent=true\n\n'
        printf '[Install]\n'
        printf 'WantedBy=timers.target\n'
    } >"$tmp_timer"
    install -m 0644 "$tmp_service" "$DDNS_SERVICE_FILE"
    install -m 0644 "$tmp_timer" "$DDNS_TIMER_FILE"
    rm -f -- "$tmp_service" "$tmp_timer"
}

ensure_ddns_timer_enabled() {
    command_exists systemctl || return 0
    [[ -d "$PROFILES_DIR" && "$(profile_count)" != "0" ]] || return 0
    if ddns_user_disabled; then
        systemctl disable --now "$DDNS_TIMER_NAME" >/dev/null 2>&1 || true
        return 0
    fi
    render_ddns_systemd_files
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable --now "$DDNS_TIMER_NAME" >/dev/null 2>&1 || true
}

ddns_user_disabled() {
    [[ -f "$DDNS_DISABLED_FILE" ]]
}

ddns_disable() {
    require_root "$@"
    ensure_profile_dirs
    install -d -m 700 "$STATE_DIR"
    : >"$DDNS_DISABLED_FILE"
    chmod 600 "$DDNS_DISABLED_FILE" 2>/dev/null || true
    if command_exists systemctl; then
        systemctl disable --now "$DDNS_TIMER_NAME" >/dev/null 2>&1 || true
    fi
    log_ok "已禁用 DDNS 定时刷新。仍可手动运行：bash install.sh ddns-refresh"
}

ddns_enable() {
    require_root "$@"
    ensure_profile_dirs
    rm -f -- "$DDNS_DISABLED_FILE"
    ensure_ddns_timer_enabled
    log_ok "已启用 DDNS 定时刷新：${DDNS_TIMER_NAME}"
}

ddns_status() {
    require_root "$@"
    local enabled active next_run last_run interval policy
    interval="$(ddns_interval_minutes)"
    if ddns_user_disabled; then
        policy="已禁用（用户关闭定时刷新）"
    else
        policy="已启用（默认）"
    fi
    if command_exists systemctl; then
        enabled="$(systemctl is-enabled "$DDNS_TIMER_NAME" 2>/dev/null || printf disabled)"
        active="$(systemctl is-active "$DDNS_TIMER_NAME" 2>/dev/null || printf inactive)"
        next_run="$(systemctl list-timers "$DDNS_TIMER_NAME" --no-pager --no-legend 2>/dev/null | awk '{print $1" "$2" "$3" "$4; exit}')"
    else
        enabled="systemctl-unavailable"
        active="systemctl-unavailable"
        next_run="-"
    fi
    last_run="$(cat "$DDNS_LAST_RUN_FILE" 2>/dev/null || printf '从未运行')"
    printf 'DDNS 定时刷新：%s\n' "$policy"
    printf '刷新间隔：%s 分钟\n' "$interval"
    printf 'timer 状态：%s / %s\n' "$enabled" "$active"
    printf '下次运行：%s\n' "${next_run:-未知}"
    printf '上次运行：%s\n' "$last_run"
}

ddns_run_once() {
    if ddns_user_disabled; then
        log_debug "DDNS 定时刷新已禁用，跳过本次刷新。"
        return 0
    fi
    ddns_refresh_all "$@"
}

profile_nft_target() {
    local landing_ip
    case "${ROLE:-}" in
        nat-ingress)
            [[ -n "${NAT_ET_IP:-}" && -n "${TRANSIT_PORT:-}" ]] || return 1
            printf '%s:%s\n' "$NAT_ET_IP" "$TRANSIT_PORT"
            ;;
        nat-transit)
            [[ -n "${LANDING_HOST:-}" && -n "${LANDING_PORT:-}" ]] || return 1
            landing_ip="$(landing_ip_for_nft "$LANDING_HOST")" || return 1
            printf '%s:%s\n' "$landing_ip" "$LANDING_PORT"
            ;;
        *)
            return 1
            ;;
    esac
}

profile_nft_daddr_match() {
    case "${ROLE:-}" in
        nat-transit)
            [[ -n "${NAT_ET_IP:-}" ]] || return 1
            printf 'ip daddr %s ' "$NAT_ET_IP"
            ;;
    esac
}

profile_nft_dport() {
    case "${ROLE:-}" in
        nat-ingress)
            [[ -n "${LOCAL_PORT:-}" ]] || return 1
            printf '%s\n' "$LOCAL_PORT"
            ;;
        nat-transit)
            [[ -n "${TRANSIT_PORT:-}" ]] || return 1
            printf '%s\n' "$TRANSIT_PORT"
            ;;
        *)
            return 1
            ;;
    esac
}

profile_nft_postrouting_ip_port() {
    local landing_ip
    case "${ROLE:-}" in
        nat-ingress)
            [[ -n "${LANDING_ET_IP:-}" && -n "${REMOTE_PORT:-}" ]] || return 1
            printf '%s:%s\n' "$LANDING_ET_IP" "$REMOTE_PORT"
            ;;
        nat-ingress)
            [[ -n "${NAT_ET_IP:-}" && -n "${TRANSIT_PORT:-}" ]] || return 1
            printf '%s:%s\n' "$NAT_ET_IP" "$TRANSIT_PORT"
            ;;
        nat-transit)
            [[ -n "${LANDING_HOST:-}" && -n "${LANDING_PORT:-}" ]] || return 1
            landing_ip="$(landing_ip_for_nft "$LANDING_HOST")" || return 1
            printf '%s:%s\n' "$landing_ip" "$LANDING_PORT"
            ;;
        *)
            return 1
            ;;
    esac
}

profile_rule_nft_dport() {
    case "${ROLE:-}" in
        nat-ingress)
            [[ -n "${CLIENT_PORT:-}" ]] || return 1
            printf '%s\n' "$CLIENT_PORT"
            ;;
        nat-transit)
            [[ -n "${TRANSIT_PORT:-}" ]] || return 1
            printf '%s\n' "$TRANSIT_PORT"
            ;;
        *)
            profile_nft_dport
            ;;
    esac
}

profile_rule_nft_target() {
    local landing_ip
    case "${ROLE:-}" in
        nat-ingress)
            [[ -n "${NAT_ET_IP:-}" && -n "${TRANSIT_PORT:-}" ]] || return 1
            printf '%s:%s\n' "$NAT_ET_IP" "$TRANSIT_PORT"
            ;;
        nat-transit)
            [[ -n "${LANDING_HOST:-}" && -n "${LANDING_PORT:-}" ]] || return 1
            landing_ip="$(landing_ip_for_nft "$LANDING_HOST")" || return 1
            printf '%s:%s\n' "$landing_ip" "$LANDING_PORT"
            ;;
        *)
            profile_nft_target
            ;;
    esac
}

profile_rule_nft_postrouting_ip_port() {
    profile_rule_nft_target
}

profile_rule_nft_daddr_match() {
    case "${ROLE:-}" in
        nat-transit)
            [[ -n "${NAT_ET_IP:-}" ]] || return 1
            printf 'ip daddr %s ' "$NAT_ET_IP"
            ;;
        *)
            profile_nft_daddr_match || true
            ;;
    esac
}

profile_rule_status_display() {
    [[ "${RULE_ENABLED:-true}" == "true" ]] && printf '启用' || printf '停止'
}

rule_note_display() {
    local note="${1:-${RULE_NOTE:-}}"
    [[ -n "$note" ]] && printf '%s' "$note" || printf '未备注'
}

rule_client_port_display() {
    case "${ROLE:-}" in
        nat-transit)
            printf '公网入口机侧指定'
            ;;
        nat-ingress)
            if [[ -n "${CLIENT_PORT:-}" ]]; then
                printf '%s' "${CLIENT_PORT}"
            elif [[ -n "${LOCAL_PORT:-}" ]]; then
                printf '%s' "${LOCAL_PORT}"
            else
                printf '—'
            fi
            ;;
        *)
            [[ -n "${CLIENT_PORT:-}" ]] && printf '%s' "${CLIENT_PORT}" || printf '—'
            ;;
    esac
}

rule_nat_public_port_value() {
    local value="${NAT_PUBLIC_PORT:-}"
    [[ -n "$value" ]] || value="${NAT_LISTENER_PORT:-${ET_LISTENER_PORT:-}}"
    [[ -n "$value" ]] || return 1
    printf '%s\n' "$value"
}

rule_nat_public_port_display() {
    rule_nat_public_port_value 2>/dev/null || printf '商家入口端口未配置'
}

profile_rule_nat_public_ports_csv() {
    local profile_id="${1:-${PROFILE_ID:-default}}" enabled_only="${2:-enabled}" rule_id value seen=" " out=()
    local saved_rule_id="${RULE_ID:-}" saved_note="${RULE_NOTE:-}" saved_enabled="${RULE_ENABLED:-}" saved_client="${CLIENT_PORT:-}" saved_nat_public="${NAT_PUBLIC_PORT:-}"
    local saved_transit="${TRANSIT_PORT:-}" saved_landing_host="${LANDING_HOST:-}" saved_landing_port="${LANDING_PORT:-}" saved_proto="${FORWARD_PROTO:-both}" saved_created="${CREATED_AT:-}" saved_updated="${UPDATED_AT:-}"
    for rule_id in $(profile_rule_ids "$profile_id"); do
        load_rule "$profile_id" "$rule_id" || continue
        [[ "$enabled_only" != "enabled" || "${RULE_ENABLED:-true}" == "true" ]] || continue
        value="$(rule_nat_public_port_value 2>/dev/null || true)"
        [[ -n "$value" ]] || continue
        if [[ "$seen" != *" ${value} "* ]]; then
            seen="${seen}${value} "
            out+=("$value")
        fi
    done
    RULE_ID="$saved_rule_id"; RULE_NOTE="$saved_note"; RULE_ENABLED="$saved_enabled"; CLIENT_PORT="$saved_client"; NAT_PUBLIC_PORT="$saved_nat_public"
    TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"; CREATED_AT="$saved_created"; UPDATED_AT="$saved_updated"
    if [[ "${#out[@]}" -gt 0 ]]; then
        (IFS=','; printf '%s\n' "${out[*]}")
        return 0
    fi
    if [[ -n "${NAT_PUBLIC_PORTS:-}" ]]; then
        printf '%s\n' "$NAT_PUBLIC_PORTS"
        return 0
    fi
    [[ -n "${NAT_LISTENER_PORT:-}" ]] || return 1
    printf '%s\n' "$NAT_LISTENER_PORT"
}

pick_next_nat_public_port() {
    local profile_id="$1" except_rule="${2:-}" ports="${NAT_PUBLIC_PORTS:-${NAT_LISTENER_PORT:-}}" port used
    [[ -n "$ports" ]] || return 1
    while IFS= read -r port; do
        [[ -n "$port" ]] || continue
        validate_port "$port" || continue
        used="$(port_used_by_profile_rule "$profile_id" nat-public "$port" "$except_rule" && printf yes || printf no)"
        if [[ "$used" == "no" ]]; then
            printf '%s\n' "$port"
            return 0
        fi
    done < <(nat_public_ports_to_words "$ports")
    return 1
}

nat_public_port_in_pool() {
    local port="$1" candidate
    while IFS= read -r candidate; do
        [[ "$candidate" == "$port" ]] && return 0
    done < <(nat_public_ports_to_words "${NAT_PUBLIC_PORTS:-${NAT_LISTENER_PORT:-}}")
    return 1
}

refresh_nat_public_endpoints_for_profile() {
    local profile_id="${1:-${PROFILE_ID:-default}}" ports first
    [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]] || return 0
    [[ "${ROLE:-}" == "nat-transit" || "${ROLE:-}" == "nat-ingress" ]] || return 0
    if [[ -z "${NAT_PUBLIC_PORTS:-}" && -n "${NAT_LISTENER_PORT:-}" ]]; then
        NAT_PUBLIC_PORTS="$NAT_LISTENER_PORT"
        NAT_PUBLIC_PORT_MODE="${NAT_PUBLIC_PORT_MODE:-single}"
    fi
    ports="$(profile_rule_nat_public_ports_csv "$profile_id" enabled 2>/dev/null || true)"
    [[ -n "$ports" ]] || ports="${NAT_PUBLIC_PORTS:-${NAT_LISTENER_PORT:-}}"
    [[ -n "$ports" ]] || return 0
    first="$(first_nat_public_port "$ports" 2>/dev/null || true)"
    [[ -n "${NAT_LISTENER_PORT:-}" ]] || NAT_LISTENER_PORT="$first"
    case "${ROLE:-}" in
        nat-transit)
            ET_LISTENER_PROTO="$NAT_LISTENER_PROTO"
            ET_LISTENER_PORT="$NAT_LISTENER_PORT"
            ET_LISTENERS="$(listener_urls_for_ports_value "${NAT_LISTENER_PROTO:-both}" "$ports" 2>/dev/null || true)"
            ET_MAPPED_LISTENERS="$(peer_urls_for_ports_value "${NAT_LISTENER_PROTO:-both}" "$NAT_PUBLIC_HOST" "$ports" 2>/dev/null || true)"
            ET_NO_LISTENER="${ET_NO_LISTENER:-false}"
            ;;
        nat-ingress)
            ET_PEERS="$(peer_urls_for_ports_value "${NAT_LISTENER_PROTO:-both}" "$NAT_PUBLIC_HOST" "$ports" 2>/dev/null || true)"
            ET_NO_LISTENER="${ET_NO_LISTENER:-true}"
            ;;
    esac
}

nft_rule_state_display() {
    case "${1:-}" in
        ok|present) printf '正常' ;;
        missing|mismatch) printf '缺失' ;;
        skipped) printf '跳过' ;;
        unavailable|unknown) printf '未知' ;;
        *) printf '%s' "${1:-未知}" ;;
    esac
}

profile_role_label_zh() {
    case "${1:-${ROLE:-}}" in
        nat-ingress) printf '公网入口线路' ;;
        nat-transit) printf 'NAT IX 中转线路' ;;
        *) printf '%s' "${1:-${ROLE:-未知}}" ;;
    esac
}

enabled_label_zh() {
    [[ "${1:-true}" == "true" ]] && printf '启用' || printf '停止'
}

forward_label_zh() {
    local role="${1:-}" enabled="${2:-true}" forward="${3:-true}"
    case "$role" in
        nat-ingress|nat-transit) ;;
        *) printf '不适用'; return 0 ;;
    esac
    if [[ "$enabled" != "true" ]]; then
        printf '停止'
    elif [[ "$forward" == "true" ]]; then
        printf '转发中'
    else
        printf '待机'
    fi
}

service_label_zh() {
    case "${1:-}" in
        active|running) printf '运行中' ;;
        inactive|dead|failed) printf '未运行' ;;
        activating) printf '启动中' ;;
        *) printf '未知' ;;
    esac
}

health_label_zh() {
    case "${1:-unknown}" in
        healthy) printf '健康' ;;
        warning) printf '警告' ;;
        down) printf '故障' ;;
        unknown|"") printf '未检查' ;;
        *) printf '%s' "$1" ;;
    esac
}

line_role_label_zh() {
    case "${1:-standalone}" in
        primary) printf '主线路' ;;
        backup) printf '备用线路' ;;
        standalone) printf '独立' ;;
        *) printf '%s' "$1" ;;
    esac
}

host_role_hint_zh() {
    local id nat_listener_transit=0 nat_listener_ingress=0 legacy=0
    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        case "${ROLE:-}:${NAT_DIRECTION:-}" in
            nat-transit:nat-listener) nat_listener_transit=$((nat_listener_transit + 1)) ;;
            nat-ingress:nat-listener) nat_listener_ingress=$((nat_listener_ingress + 1)) ;;
            *) legacy=$((legacy + 1)) ;;
        esac
    done
    if [[ "$nat_listener_transit" -gt 0 && "$nat_listener_ingress" -gt 0 ]]; then
        printf '当前机器同时存在 NAT IX 中转线路和公网入口线路。'
    elif [[ "$nat_listener_transit" -gt 0 ]]; then
        printf '当前机器是 NAT IX 中转机，负责监听商家入口并转发到落地机。'
    elif [[ "$nat_listener_ingress" -gt 0 ]]; then
        printf '当前机器是公网入口机，负责接收客户端连接并转发到 NAT IX 机器。'
    elif [[ "$legacy" -gt 0 ]]; then
        printf '检测到历史配置。'
    else
        printf '尚未创建线路；请先创建 NAT IX 中转线路或导入接入码。'
    fi
}

resolve_profile_id_for_menu() {
    local verb="${1:-}" requested="${2:-}" count only
    count="$(profile_count)"
    if [[ "$count" == "0" && ! -f "$ENV_FILE" ]]; then
        die_user "当前没有线路，请先创建 NAT IX 中转线路或导入接入码。"
        return 2
    fi
    if [[ -n "$requested" ]]; then
        validate_profile_id "$requested" || die_user "线路 ID 格式不正确：${requested}"
        [[ -f "$(profile_env_path "$requested")" ]] || die_user "未找到线路：${requested}"
        printf '%s\n' "$requested"
        return 0
    fi
    if [[ "$count" == "1" ]]; then
        only="$(profile_ids | head -n 1)"
        printf '%s\n' "$only"
        return 0
    fi
    if [[ "$count" == "0" && -f "$ENV_FILE" ]]; then
        printf 'default\n'
        return 0
    fi
    printf '当前机器已有线路：\n' >&2
    profile_ids | sed 's/^/  - /' >&2
    printf '请输入线路 ID：' >&2
    IFS= read -r requested || return 0
    [[ -n "$requested" ]] || die_user "请指定线路 ID。"
    resolve_profile_id_for_menu "$verb" "$requested"
}

prompt_profile_id_for_menu() {
    local verb="${1:-}" count only profile_id
    count="$(profile_count)"
    if [[ "$count" == "1" ]]; then
        only="$(profile_ids | head -n 1)"
        printf '已自动选择唯一线路：%s\n' "$only" >&2
        printf '%s\n' "$only"
        return 0
    fi
    printf '请输入线路编号或 ID（直接回车自动选择唯一线路）：' >&2
    IFS= read -r profile_id || return 0
    if ! profile_id="$(resolve_profile_id_for_menu "$verb" "$profile_id")"; then
        return 0
    fi
    printf '%s\n' "$profile_id"
}

latency_report_from_menu() {
    local profile_id=""
    if ! profile_id="$(prompt_profile_id_for_menu latency-report)"; then
        return 0
    fi
    [[ -n "$profile_id" ]] || return 0
    latency_report "$profile_id"
    return 0
}

show_profile_from_menu() {
    local profile_id=""
    if ! profile_id="$(prompt_profile_id_for_menu show-config)"; then
        return 0
    fi
    [[ -n "$profile_id" ]] || return 0
    show_profile "$profile_id"
    return 0
}

health_profile_from_menu() {
    local profile_id=""
    if ! profile_id="$(prompt_profile_id_for_menu health)"; then
        return 0
    fi
    [[ -n "$profile_id" ]] || return 0
    health_profile "$profile_id"
    return 0
}

normalize_systemctl_word() {
    local value="${1//$'\r'/}"
    value="${value%%$'\n'*}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

self_check_monitor_timer_status() {
    local enabled
    if ! command_exists systemctl; then
        printf '未安装'
        return 0
    fi
    enabled="$(normalize_systemctl_word "$(systemctl is-enabled "$MONITOR_TIMER_NAME" 2>/dev/null || true)")"
    case "$enabled" in
        enabled) printf '已启用' ;;
        disabled) printf '未启用' ;;
        *) printf '未安装' ;;
    esac
}

self_check_ddns_timer_status() {
    local enabled
    if ddns_user_disabled; then
        printf '已禁用'
        return 0
    fi
    if ! command_exists systemctl; then
        printf '未安装'
        return 0
    fi
    enabled="$(normalize_systemctl_word "$(systemctl is-enabled "$DDNS_TIMER_NAME" 2>/dev/null || true)")"
    case "$enabled" in
        enabled) printf '已启用' ;;
        disabled) printf '未启用' ;;
        *) printf '未安装' ;;
    esac
}

profile_easytier_proto_display() {
    case "${ROLE:-}" in
        nat-transit)
            proto_display_user "${NAT_LISTENER_PROTO:-${ET_LISTENER_PROTO:-both}}"
            ;;
        nat-ingress)
            proto_display_user "${NAT_LISTENER_PROTO:-both}"
            ;;
        nat-transit)
            proto_display_user "${ET_LISTENER_PROTO:-${LISTENER_PROTOS:-both}}"
            ;;
        *)
            proto_display_user "${FORWARD_PROTO:-both}"
            ;;
    esac
}

nat_ix_machine_role_label() {
    case "${ROLE:-}:${NAT_DIRECTION:-}" in
        nat-transit:nat-listener) printf 'NAT IX 机器（生成接入码）' ;;
        nat-ingress:nat-listener) printf '公网入口机（导入接入码）' ;;
        nat-transit:*) printf 'NAT IX 机器（兼容旧模式）' ;;
        nat-ingress:*) printf '公网入口机（兼容旧模式）' ;;
        *) printf '未知' ;;
    esac
}

profile_rule_count() {
    local profile_id="$1" rule_id count=0
    for rule_id in $(profile_rule_ids "$profile_id"); do
        count=$((count + 1))
    done
    printf '%s' "$count"
}

profile_client_port_summary() {
    local profile_id="$1" rule_id count=0 port=""
    local saved_rule_id="${RULE_ID:-}" saved_note="${RULE_NOTE:-}" saved_enabled="${RULE_ENABLED:-}" saved_client="${CLIENT_PORT:-}" saved_nat_public="${NAT_PUBLIC_PORT:-}"
    local saved_transit="${TRANSIT_PORT:-}" saved_landing_host="${LANDING_HOST:-}" saved_landing_port="${LANDING_PORT:-}" saved_proto="${FORWARD_PROTO:-both}"
    if [[ "${ROLE:-}" == "nat-transit" ]]; then
        printf '公网入口机侧指定'
        return 0
    fi
    if profile_supports_forward_rules; then
        for rule_id in $(profile_rule_ids "$profile_id"); do
            load_rule "$profile_id" "$rule_id" || continue
            count=$((count + 1))
            port="${CLIENT_PORT:-}"
        done
        RULE_ID="$saved_rule_id"; RULE_NOTE="$saved_note"; RULE_ENABLED="$saved_enabled"; CLIENT_PORT="$saved_client"; NAT_PUBLIC_PORT="$saved_nat_public"
        TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
        if [[ "$count" -gt 1 ]]; then
            printf '多规则，请查看转发规则'
            return 0
        fi
        [[ -n "$port" ]] && { printf '%s' "$port"; return 0; }
    fi
    [[ -n "${LOCAL_PORT:-}" ]] && printf '%s' "${LOCAL_PORT}" || printf '—'
}

profile_landing_target_summary() {
    local profile_id="$1" rule_id count=0 host="" port=""
    local saved_rule_id="${RULE_ID:-}" saved_note="${RULE_NOTE:-}" saved_enabled="${RULE_ENABLED:-}" saved_client="${CLIENT_PORT:-}" saved_nat_public="${NAT_PUBLIC_PORT:-}"
    local saved_transit="${TRANSIT_PORT:-}" saved_landing_host="${LANDING_HOST:-}" saved_landing_port="${LANDING_PORT:-}" saved_proto="${FORWARD_PROTO:-both}"
    if profile_supports_forward_rules; then
        for rule_id in $(profile_rule_ids "$profile_id"); do
            load_rule "$profile_id" "$rule_id" || continue
            count=$((count + 1))
            host="${LANDING_HOST:-}"
            port="${LANDING_PORT:-}"
        done
        RULE_ID="$saved_rule_id"; RULE_NOTE="$saved_note"; RULE_ENABLED="$saved_enabled"; CLIENT_PORT="$saved_client"; NAT_PUBLIC_PORT="$saved_nat_public"
        TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
        if [[ "$count" -gt 1 ]]; then
            printf '多规则，请查看转发规则'
            return 0
        fi
        if [[ "$count" -eq 1 && -n "$host" && -n "$port" ]]; then
            printf '%s:%s' "$host" "$port"
            return 0
        fi
    fi
    if [[ -n "${LANDING_HOST:-}" && -n "${LANDING_PORT:-}" ]]; then
        printf '%s:%s' "${LANDING_HOST}" "${LANDING_PORT}"
    elif [[ -n "${REMOTE_PORT:-${SERVICE_PORT:-}}" ]]; then
        printf '%s:%s' "${LANDING_ET_IP:-落地机}" "${REMOTE_PORT:-${SERVICE_PORT:-}}"
    else
        printf '—'
    fi
}

format_rules_for_show_config() {
    local profile_id="$1" rule_id saved_local saved_nat_public saved_transit saved_landing_host saved_landing_port saved_proto printed=0
    saved_local="${LOCAL_PORT:-}"; saved_nat_public="${NAT_PUBLIC_PORT:-}"; saved_transit="${TRANSIT_PORT:-}"; saved_landing_host="${LANDING_HOST:-}"; saved_landing_port="${LANDING_PORT:-}"; saved_proto="${FORWARD_PROTO:-both}"
    for rule_id in $(profile_rule_ids "$profile_id"); do
        load_rule "$profile_id" "$rule_id" || continue
        printed=1
        case "${ROLE:-}" in
            nat-ingress)
                printf '* [%s] %s -> %s:%s -> %s:%s -> %s:%s（%s，%s）\n' \
                    "$(rule_note_display)" "$(rule_client_port_display)" "${NAT_PUBLIC_HOST:-商家 NAT/IX 入口地址}" "$(rule_nat_public_port_display)" "${NAT_ET_IP:-NAT IX 虚拟 IP}" "${TRANSIT_PORT:-}" \
                    "${LANDING_HOST:-}" "${LANDING_PORT:-}" "$(proto_display_user "${FORWARD_PROTO:-both}")" "$(profile_rule_status_display)"
                ;;
            nat-transit)
                printf '* [%s] %s:%s -> %s:%s -> %s:%s（%s，%s）\n' \
                    "$(rule_note_display)" "${NAT_PUBLIC_HOST:-商家 NAT/IX 入口地址}" "$(rule_nat_public_port_display)" "${NAT_ET_IP:-NAT IX 虚拟 IP}" "${TRANSIT_PORT:-}" \
                    "${LANDING_HOST:-}" "${LANDING_PORT:-}" "$(proto_display_user "${FORWARD_PROTO:-both}")" "$(profile_rule_status_display)"
                ;;
        esac
    done
    [[ "$printed" -eq 1 ]] || printf '* 暂无转发规则\n'
    LOCAL_PORT="$saved_local"; NAT_PUBLIC_PORT="$saved_nat_public"; TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
    return 0
}

profile_rule_path_display() {
    case "${ROLE:-}" in
        nat-ingress)
            printf '%s -> %s:%s -> %s:%s -> %s:%s' "${CLIENT_PORT:-客户端入口端口}" "${NAT_PUBLIC_HOST:-商家 NAT/IX 入口地址}" "$(rule_nat_public_port_display)" "${NAT_ET_IP:-NAT IX 虚拟 IP}" "${TRANSIT_PORT:-虚拟网中转端口}" "${LANDING_HOST:-落地机地址}" "${LANDING_PORT:-落地业务端口}"
            ;;
        nat-transit)
            printf '公网入口机侧指定 -> %s:%s -> %s:%s -> %s:%s' "${NAT_PUBLIC_HOST:-商家 NAT/IX 入口地址}" "$(rule_nat_public_port_display)" "${NAT_ET_IP:-NAT IX 虚拟 IP}" "${TRANSIT_PORT:-虚拟网中转端口}" "${LANDING_HOST:-落地机地址}" "${LANDING_PORT:-落地业务端口}"
            ;;
        *)
            printf '%s -> %s' "$(profile_nft_dport 2>/dev/null || printf '-')" "$(profile_nft_target 2>/dev/null || printf '-')"
            ;;
    esac
}

render_nft_file() {
    local output="$1" dport target daddr post ip port
    local table_name="$2"
    [[ "${FORWARD_ENABLED:-true}" == "true" ]] || die_user "业务转发未配置，不能生成 nftables 规则。请运行 configure-forward。"
    dport="$(profile_nft_dport)" || die_user "Profile 缺少 nftables 接收端口。"
    target="$(profile_nft_target)" || die_user "Profile 缺少 nftables 转发目标。"
    daddr="$(profile_nft_daddr_match || true)"
    post="$(profile_nft_postrouting_ip_port)" || die_user "Profile 缺少 nftables SNAT 目标。"
    ip="${post%:*}"
    port="${post##*:}"

    {
        printf 'table ip %s {\n' "$table_name"
        printf '    chain prerouting {\n'
        printf '        type nat hook prerouting priority dstnat; policy accept;\n'
        if [[ "$FORWARD_PROTO" == "tcp" || "$FORWARD_PROTO" == "both" ]]; then
            printf '        %stcp dport %s dnat to %s\n' "$daddr" "$dport" "$target"
        fi
        if [[ "$FORWARD_PROTO" == "udp" || "$FORWARD_PROTO" == "both" ]]; then
            printf '        %sudp dport %s dnat to %s\n' "$daddr" "$dport" "$target"
        fi
        printf '    }\n\n'
        printf '    chain postrouting {\n'
        printf '        type nat hook postrouting priority srcnat; policy accept;\n'
        if [[ "$FORWARD_PROTO" == "tcp" || "$FORWARD_PROTO" == "both" ]]; then
            printf '        ip daddr %s tcp dport %s masquerade\n' "$ip" "$port"
        fi
        if [[ "$FORWARD_PROTO" == "udp" || "$FORWARD_PROTO" == "both" ]]; then
            printf '        ip daddr %s udp dport %s masquerade\n' "$ip" "$port"
        fi
        printf '    }\n'
        printf '}\n'
    } >"$output"
}

validate_profile_config() {
    local profile_id="${1:-${PROFILE_ID:-}}"
    validate_profile_id "$profile_id" || die_user "PROFILE_ID 格式不正确：${profile_id}"
    normalize_profile_compat_vars
    validate_line_role "${LINE_ROLE:-standalone}" || die_user "LINE_ROLE 只能是 primary、backup 或 standalone。"
    validate_line_priority "${LINE_PRIORITY:-100}" || die_user "LINE_PRIORITY 必须是数字。"
    validate_health_status_value "${HEALTH_STATUS:-unknown}" || die_user "HEALTH_STATUS 只能是 unknown、healthy、warning 或 down。"
    validate_easytier_args
    check_profile_rule_conflicts "$profile_id"
}

current_profile_forward_client_ports() {
    local profile_id="${1:-${PROFILE_ID:-}}" rule_id
    local saved_rule_id="${RULE_ID:-}" saved_note="${RULE_NOTE:-}" saved_enabled="${RULE_ENABLED:-}" saved_client="${CLIENT_PORT:-}" saved_nat_public="${NAT_PUBLIC_PORT:-}"
    local saved_transit="${TRANSIT_PORT:-}" saved_landing_host="${LANDING_HOST:-}" saved_landing_port="${LANDING_PORT:-}" saved_proto="${FORWARD_PROTO:-both}" saved_created="${CREATED_AT:-}" saved_updated="${UPDATED_AT:-}"
    [[ "${ENABLED:-true}" == "true" && "${FORWARD_ENABLED:-true}" == "true" ]] || return 0
    case "${ROLE:-}" in
        nat-ingress)
            for rule_id in $(profile_rule_ids "$profile_id"); do
                load_rule "$profile_id" "$rule_id" || continue
                [[ "${RULE_ENABLED:-true}" == "true" && -n "${CLIENT_PORT:-}" ]] || continue
                printf '%s\n' "$CLIENT_PORT"
            done
            ;;
    esac
    RULE_ID="$saved_rule_id"; RULE_NOTE="$saved_note"; RULE_ENABLED="$saved_enabled"; CLIENT_PORT="$saved_client"; NAT_PUBLIC_PORT="${saved_nat_public:-}"; TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"; CREATED_AT="$saved_created"; UPDATED_AT="$saved_updated"
}

profile_forward_client_ports_for_conflict() (
    local profile_id="$1"
    load_profile "$profile_id" >/dev/null 2>&1 || return 0
    current_profile_forward_client_ports "$profile_id"
)

check_profile_conflicts() {
    local profile_id="${1:-${PROFILE_ID:-}}" other path other_role other_forward other_direction current_port other_port old_listener old_subnet old_ip
    local current_subnet current_ip
    validate_profile_id "$profile_id" || die_user "PROFILE_ID 格式不正确：${profile_id}"
    normalize_profile_compat_vars
    [[ "${ENABLED:-true}" == "true" ]] || return 0
    current_subnet="${ET_SUBNET:-}"
    if [[ -z "$current_subnet" && -n "${ET_IPV4:-}" ]]; then
        current_subnet="$(cidr_network24 "$ET_IPV4" 2>/dev/null || true)"
    fi
    current_ip="${ET_IPV4:-}"
    current_ip="${current_ip%%/*}"

    if [[ ( "${ROLE:-}" == "nat-ingress" ) && "${FORWARD_ENABLED:-true}" == "true" ]]; then
        while IFS= read -r current_port; do
            [[ -n "$current_port" ]] || continue
            for other in $(profile_ids); do
                [[ "$other" == "$profile_id" ]] && continue
                path="$(profile_env_path "$other")"
                profile_path_enabled "$path" || continue
                other_role="$(profile_env_value_from_path "$path" ROLE 2>/dev/null || true)"
                [[ "$other_role" == "nat-ingress" ]] || continue
                other_forward="$(profile_env_value_from_path "$path" FORWARD_ENABLED 2>/dev/null || true)"
                [[ "${other_forward:-true}" == "true" ]] || continue
                while IFS= read -r other_port; do
                    [[ -n "$other_port" ]] || continue
                    if [[ "$other_port" == "$current_port" ]]; then
                        die_user "客户端入口端口冲突：${current_port} 已被 profile ${other} 使用。"
                    fi
                done < <(profile_forward_client_ports_for_conflict "$other")
            done
            if is_port_in_use "$current_port"; then
                log_warn "CLIENT_PORT ${current_port} 已被本机进程监听，可能和 nftables DNAT 冲突。"
                show_port_owner "$current_port" >&2
            fi
        done < <(current_profile_forward_client_ports "$profile_id")
        if [[ "${ROLE:-}" == "nat-ingress" ]]; then
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                [[ -n "${TRANSIT_PORT:-}" && -n "${LANDING_HOST:-}" && -n "${LANDING_PORT:-}" ]] \
                    || die_user "NAT-IX 公网入口缺少 TRANSIT_PORT / LANDING_HOST / LANDING_PORT。"
            else
                [[ -n "${REMOTE_PORT:-}" ]] || die_user "REMOTE_PORT 为空但业务转发已启用。"
            fi
        fi
    fi
    if [[ "${ROLE:-}" == "nat-ingress" && "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" && "${FORWARD_ENABLED:-true}" == "true" ]]; then
        [[ -n "${TRANSIT_PORT:-}" ]] || die_user "TRANSIT_PORT 为空但 NAT-IX 转发已启用。"
    fi
    if [[ "${ROLE:-}" == "nat-ingress" && "${NAT_DIRECTION:-ingress-listener}" == "ingress-listener" && "${FORWARD_ENABLED:-true}" == "true" ]]; then
        [[ -n "${TRANSIT_PORT:-}" ]] || die_user "TRANSIT_PORT 为空但 NAT-IX 转发已启用。"
        if [[ -n "${LOCAL_PORT:-}" && -n "${INGRESS_LISTENER_PORT:-}" && "$LOCAL_PORT" == "$INGRESS_LISTENER_PORT" ]]; then
            die_user "LOCAL_PORT 不能和 INGRESS_LISTENER_PORT 相同。"
        fi
    fi
    if [[ "${ROLE:-}" == "nat-transit" && "${FORWARD_ENABLED:-true}" == "true" ]]; then
        [[ -n "${TRANSIT_PORT:-}" && -n "${LANDING_HOST:-}" && -n "${LANDING_PORT:-}" ]] || die_user "nat-transit 缺少 TRANSIT_PORT / LANDING_HOST / LANDING_PORT。"
    fi
    check_profile_rule_conflicts "$profile_id"
    if profile_uses_easytier_listener; then
        local listener_port listener_proto
        if [[ "${ROLE:-}" == "nat-transit" && "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
            listener_port="${NAT_LISTENER_PORT:-${ET_LISTENER_PORT:-}}"
            listener_proto="${NAT_LISTENER_PROTO:-${ET_LISTENER_PROTO:-both}}"
        else
            listener_port="${LISTENER_PORT:-${ET_LISTENER_PORT:-${INGRESS_LISTENER_PORT:-}}}"
            listener_proto="${ET_LISTENER_PROTO:-${LISTENER_PROTOS:-${INGRESS_LISTENER_PROTO:-both}}}"
        fi
        for other in $(profile_ids); do
            [[ "$other" == "$profile_id" ]] && continue
            path="$(profile_env_path "$other")"
            profile_path_enabled "$path" || continue
            other_role="$(profile_env_value_from_path "$path" ROLE 2>/dev/null || true)"
            other_direction="$(profile_env_value_from_path "$path" NAT_DIRECTION 2>/dev/null || true)"
            other_direction="${other_direction:-ingress-listener}"
            case "$other_role:$other_direction" in
                nat-transit:nat-listener) old_listener="$(profile_env_value_from_path "$path" NAT_LISTENER_PORT 2>/dev/null || true)" ;;
                nat-ingress:ingress-listener) old_listener="$(profile_env_value_from_path "$path" INGRESS_LISTENER_PORT 2>/dev/null || true)" ;;
                nat-transit:nat-listener) old_listener="$(profile_env_value_from_path "$path" NAT_LISTENER_PORT 2>/dev/null || true)" ;;
                *) continue ;;
            esac
            [[ -n "$old_listener" ]] || old_listener="$(profile_env_value_from_path "$path" ET_LISTENER_PORT 2>/dev/null || true)"
            if [[ -n "$listener_port" && "$old_listener" == "$listener_port" ]]; then
                die_user "EasyTier listener 端口冲突：${listener_port} 已被 profile ${other} 使用。"
            fi
        done
        validate_listener_port_available "$listener_proto" "$listener_port" || die_user "EasyTier listener 端口不可用。"
    fi

    for other in $(profile_ids); do
        [[ "$other" == "$profile_id" ]] && continue
        path="$(profile_env_path "$other")"
        profile_path_enabled "$path" || continue
        old_subnet="$(profile_subnet_from_path "$path" 2>/dev/null || true)"
        old_ip="$(profile_et_ip_addr_from_path "$path" 2>/dev/null || true)"
        if [[ -n "$current_subnet" && -n "$old_subnet" && "$old_subnet" == "$current_subnet" ]]; then
            die_user "ET_SUBNET 冲突：${current_subnet} 已被 profile ${other} 使用。"
        fi
        if [[ -n "$current_ip" && -n "$old_ip" && "$old_ip" == "$current_ip" ]]; then
            die_user "ET_IPV4 冲突：${current_ip} 已被 profile ${other} 使用。"
        fi
    done
}

check_all_profiles_conflicts() {
    local id path role direction enabled forward_enabled local_port transit_port listener_port subnet et_ip
    declare -A seen_local=() seen_transit=() seen_listener=() seen_subnet=() seen_ip=()
    for id in $(profile_ids); do
        path="$(profile_env_path "$id")"
        profile_path_enabled "$path" || continue
        role="$(profile_env_value_from_path "$path" ROLE 2>/dev/null || true)"

        if [[ "$role" == "nat-ingress" ]]; then
            forward_enabled="$(profile_env_value_from_path "$path" FORWARD_ENABLED 2>/dev/null || true)"
            if [[ "${forward_enabled:-true}" == "true" ]]; then
                while IFS= read -r local_port; do
                    [[ -n "$local_port" ]] || continue
                    if [[ -n "${seen_local[$local_port]:-}" ]]; then
                        die_user "多个启用 Profile 使用相同客户端入口端口：${local_port}（${seen_local[$local_port]} 与 ${id}）"
                    fi
                    seen_local[$local_port]="$id"
                done < <(profile_forward_client_ports_for_conflict "$id")
            fi
        fi
        if [[ "$role" == "nat-transit" ]]; then
            forward_enabled="$(profile_env_value_from_path "$path" FORWARD_ENABLED 2>/dev/null || true)"
            if [[ "${forward_enabled:-true}" == "true" ]]; then
                while IFS= read -r transit_port; do
                    [[ -n "$transit_port" ]] || continue
                    if [[ -n "${seen_transit[$transit_port]:-}" ]]; then
                        die_user "多个启用 Profile 使用相同 TRANSIT_PORT：${transit_port}（${seen_transit[$transit_port]} 与 ${id}）"
                    fi
                    seen_transit[$transit_port]="$id"
                done < <(profile_forward_transit_ports_for_conflict "$id")
            fi
        fi

        direction="$(profile_env_value_from_path "$path" NAT_DIRECTION 2>/dev/null || true)"
        direction="${direction:-ingress-listener}"
        listener_port=""
        case "$role:$direction" in

            nat-ingress:ingress-listener) listener_port="$(profile_env_value_from_path "$path" INGRESS_LISTENER_PORT 2>/dev/null || true)" ;;
            nat-transit:nat-listener) listener_port="$(profile_env_value_from_path "$path" NAT_LISTENER_PORT 2>/dev/null || true)" ;;
        esac
        [[ -n "$listener_port" ]] || listener_port="$(profile_env_value_from_path "$path" ET_LISTENER_PORT 2>/dev/null || true)"
        if [[ -n "$listener_port" ]]; then
            if [[ -n "${seen_listener[$listener_port]:-}" ]]; then
                die_user "多个启用 Profile 使用相同 LISTENER_PORT：${listener_port}（${seen_listener[$listener_port]} 与 ${id}）"
            fi
            seen_listener[$listener_port]="$id"
        fi

        subnet="$(profile_subnet_from_path "$path" 2>/dev/null || true)"
        if [[ -n "$subnet" ]]; then
            if [[ -n "${seen_subnet[$subnet]:-}" ]]; then
                die_user "多个启用 Profile 使用相同 ET_SUBNET：${subnet}（${seen_subnet[$subnet]} 与 ${id}）"
            fi
            seen_subnet[$subnet]="$id"
        fi

        et_ip="$(profile_et_ip_addr_from_path "$path" 2>/dev/null || true)"
        if [[ -n "$et_ip" ]]; then
            if [[ -n "${seen_ip[$et_ip]:-}" ]]; then
                die_user "多个启用 Profile 使用相同 ET_IPV4：${et_ip}（${seen_ip[$et_ip]} 与 ${id}）"
            fi
            seen_ip[$et_ip]="$id"
        fi
    done
}

validate_all_enabled_profiles() {
    local id path
    for id in $(profile_ids); do
        path="$(profile_env_path "$id")"
        profile_path_enabled "$path" || continue
        load_profile "$id" || die_user "无法读取线路：${id}"
        profile_needs_nft_forward || continue
        validate_profile_config "$id"
    done
}

render_nft_all_file() {
    local output="$1" table_name="$2" id dport target daddr post ip port
    {
        printf 'table ip %s {\n' "$table_name"
        printf '    chain prerouting {\n'
        printf '        type nat hook prerouting priority dstnat; policy accept;\n\n'
        for id in $(profile_ids); do
            load_profile "$id" || continue
            profile_needs_nft_forward || continue
            dport="$(profile_nft_dport)" || continue
            target="$(profile_nft_target)" || return 1
            daddr="$(profile_nft_daddr_match || true)"
            printf '        # profile: %s\n' "$id"
            if [[ "${FORWARD_PROTO:-both}" == "tcp" || "${FORWARD_PROTO:-both}" == "both" ]]; then
                printf '        %stcp dport %s dnat to %s\n' "$daddr" "$dport" "$target"
            fi
            if [[ "${FORWARD_PROTO:-both}" == "udp" || "${FORWARD_PROTO:-both}" == "both" ]]; then
                printf '        %sudp dport %s dnat to %s\n' "$daddr" "$dport" "$target"
            fi
            printf '\n'
        done
        printf '    }\n\n'
        printf '    chain postrouting {\n'
        printf '        type nat hook postrouting priority srcnat; policy accept;\n\n'
        for id in $(profile_ids); do
            load_profile "$id" || continue
            profile_needs_nft_forward || continue
            post="$(profile_nft_postrouting_ip_port)" || return 1
            ip="${post%:*}"
            port="${post##*:}"
            printf '        # profile: %s\n' "$id"
            if [[ "${FORWARD_PROTO:-both}" == "tcp" || "${FORWARD_PROTO:-both}" == "both" ]]; then
                printf '        ip daddr %s tcp dport %s masquerade\n' "$ip" "$port"
            fi
            if [[ "${FORWARD_PROTO:-both}" == "udp" || "${FORWARD_PROTO:-both}" == "both" ]]; then
                printf '        ip daddr %s udp dport %s masquerade\n' "$ip" "$port"
            fi
            printf '\n'
        done
        printf '    }\n'
        printf '}\n'
    } >"$output"
}

apply_nft_all() {
    require_root "$@"
    ensure_profile_dirs
    validate_all_enabled_profiles
    check_all_profiles_conflicts
    install_nftables
    install -d -m 0755 "$NFT_DIR"
    local check_tmp actual_tmp check_table backup_path
    check_tmp="$(make_tmp_file "ix-transit-fabric.nft-all-check")"
    actual_tmp="$(make_tmp_file "ix-transit-fabric.nft-all")"
    check_table="$NFT_TABLE"
    if nft list table ip "$NFT_TABLE" >/dev/null 2>&1; then
        check_table="${NFT_TABLE}_check_$$"
    fi
    render_nft_all_file "$check_tmp" "$check_table"
    nft -c -f "$check_tmp"
    rm -f -- "$check_tmp"
    render_nft_all_file "$actual_tmp" "$NFT_TABLE"
    backup_file "$NFT_FILE"
    install -m 0644 "$actual_tmp" "$NFT_FILE"
    rm -f -- "$actual_tmp"
    backup_path="$(backup_current_nft_table)"
    nft delete table ip "$NFT_TABLE" >/dev/null 2>&1 || true
    if nft -f "$NFT_FILE"; then
        log_debug "已应用全部线路的 nftables 项目表。"
        ensure_ddns_timer_enabled
        if profile_ids | awk 'NF{found=1; exit} END{exit !found}'; then
            ensure_ix_cli_shortcut || true
        fi
        return 0
    fi
    log_error "应用全部 nftables 规则失败，正在回滚。"
    restore_nft_backup "$backup_path" || true
    return 1
}

backup_current_nft_table() {
    local stamp backup_path
    ensure_config_dir
    stamp="$(date +%Y%m%d-%H%M%S)"
    backup_path="${BACKUP_DIR}/nft-${stamp}.nft"

    if nft list table ip "$NFT_TABLE" >"$backup_path" 2>/dev/null; then
        chmod 600 "$backup_path" 2>/dev/null || true
        printf '%s\n' "$backup_path"
    else
        rm -f -- "$backup_path"
        backup_path="${BACKUP_DIR}/nft-${stamp}.empty"
        : >"$backup_path"
        chmod 600 "$backup_path" 2>/dev/null || true
        printf '%s\n' "$backup_path"
    fi
}

restore_nft_backup() {
    local backup_path="$1"

    if [[ "$backup_path" == *.empty ]]; then
        nft delete table ip "$NFT_TABLE" >/dev/null 2>&1 || true
        log_warn "之前不存在项目 nftables 表，已清理残留表。"
        return 0
    fi

    nft delete table ip "$NFT_TABLE" >/dev/null 2>&1 || true
    if nft -f "$backup_path"; then
        log_warn "已恢复旧 nftables 项目表：${backup_path}"
        return 0
    fi

    log_error "恢复旧 nftables 项目表失败，请手动检查：${backup_path}"
    return 1
}

apply_nft() {
    install_nftables
    install -d -m 0755 "$NFT_DIR"

    local check_tmp actual_tmp check_table backup_path
    check_tmp="$(make_tmp_file "ix-transit-fabric.nft-check")"
    actual_tmp="$(make_tmp_file "ix-transit-fabric.nft")"
    check_table="$NFT_TABLE"
    if nft list table ip "$NFT_TABLE" >/dev/null 2>&1; then
        check_table="${NFT_TABLE}_check_$$"
    fi

    render_nft_file "$check_tmp" "$check_table"
    nft -c -f "$check_tmp"
    rm -f -- "$check_tmp"

    render_nft_file "$actual_tmp" "$NFT_TABLE"
    backup_file "$NFT_FILE"
    install -m 0644 "$actual_tmp" "$NFT_FILE"
    rm -f -- "$actual_tmp"

    backup_path="$(backup_current_nft_table)"
    nft delete table ip "$NFT_TABLE" >/dev/null 2>&1 || true
    if nft -f "$NFT_FILE"; then
        log_ok "已应用 nftables 项目表：table ip ${NFT_TABLE}"
        return 0
    fi

    log_error "应用 nftables 项目表失败，正在尝试回滚。"
    if ! restore_nft_backup "$backup_path"; then
        log_error "nftables 回滚失败，备份路径：${backup_path}"
    fi
    return 1
}

remove_nft() {
    if command_exists nft; then
        nft delete table ip "$NFT_TABLE" >/dev/null 2>&1 || true
        log_ok "已删除 nftables 项目表（如果存在）：table ip ${NFT_TABLE}"
    else
        log_warn "未找到 nft 命令，跳过运行时表删除。"
    fi
    backup_and_remove_file "$NFT_FILE"
}

delete_nft_runtime_and_file() {
    if command_exists nft; then
        nft delete table ip "$NFT_TABLE" >/dev/null 2>&1 || true
        log_ok "已删除 nftables 项目表（如果存在）：table ip ${NFT_TABLE}"
    else
        log_warn "未找到 nft 命令，跳过运行时表删除。"
    fi
    rm -f -- "$NFT_FILE"
}

status_nft() {
    if command_exists nft; then
        if nft list table ip "$NFT_TABLE" >/dev/null 2>&1; then
            printf 'nftables 项目表：存在（table ip %s）\n' "$NFT_TABLE"
        else
            printf 'nftables 项目表：不存在（table ip %s）\n' "$NFT_TABLE"
        fi
    else
        printf 'nftables 项目表：nft 命令不可用\n'
    fi
}

show_nft() {
    if ! command_exists nft; then
        printf '未找到 nft 命令。入口机需要安装 nftables。\n'
        return 0
    fi

    if ! nft list table ip "$NFT_TABLE" >/dev/null 2>&1; then
        printf 'nftables 项目表不存在：table ip %s\n' "$NFT_TABLE"
        return 0
    fi

    nft list table ip "$NFT_TABLE"
}

load_env_or_warn() {
    if load_env; then
        return 0
    fi
    printf '[WARN] 未找到可读取的配置文件：%s。请先创建 NAT IX 中转线路或导入接入码。\n' "$ENV_FILE"
    return 1
}

et_ip_addr() {
    printf '%s\n' "${ET_IPV4%%/*}"
}

nat_rules_tsv() {
    local profile_id="${PROFILE_ID:-default}" rule_id saved_local saved_nat_public saved_transit saved_landing_host saved_landing_port saved_proto
    saved_local="${LOCAL_PORT:-}"; saved_nat_public="${NAT_PUBLIC_PORT:-}"; saved_transit="${TRANSIT_PORT:-}"; saved_landing_host="${LANDING_HOST:-}"; saved_landing_port="${LANDING_PORT:-}"; saved_proto="${FORWARD_PROTO:-both}"
    for rule_id in $(profile_rule_ids "$profile_id"); do
        load_rule "$profile_id" "$rule_id" || continue
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$rule_id" "${RULE_NOTE:-}" "${RULE_ENABLED:-true}" "$(rule_nat_public_port_value 2>/dev/null || true)" "${TRANSIT_PORT:-}" "${LANDING_HOST:-}" "${LANDING_PORT:-}" "${FORWARD_PROTO:-both}"
    done
    LOCAL_PORT="$saved_local"; NAT_PUBLIC_PORT="$saved_nat_public"; TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
}

nat_code_rules_b64() {
    nat_rules_tsv | base64url_encode
}

nat_code_rules_json() {
    local profile_id="${PROFILE_ID:-default}" rule_id first="true"
    local saved_local saved_nat_public saved_transit saved_landing_host saved_landing_port saved_proto
    saved_local="${LOCAL_PORT:-}"; saved_nat_public="${NAT_PUBLIC_PORT:-}"; saved_transit="${TRANSIT_PORT:-}"; saved_landing_host="${LANDING_HOST:-}"; saved_landing_port="${LANDING_PORT:-}"; saved_proto="${FORWARD_PROTO:-both}"
    printf '['
    for rule_id in $(profile_rule_ids "$profile_id"); do
        load_rule "$profile_id" "$rule_id" || continue
        [[ "$first" == "true" ]] || printf ','
        printf '{'
        printf '"rule_id":"%s",' "$(json_escape "$rule_id")"
        printf '"note":"%s",' "$(json_escape "${RULE_NOTE:-}")"
        printf '"enabled":%s,' "$([[ "${RULE_ENABLED:-true}" == "true" ]] && printf true || printf false)"
        printf '"nat_public_port":%s,' "$(rule_nat_public_port_value 2>/dev/null || printf '0')"
        printf '"transit_port":%s,' "${TRANSIT_PORT:-0}"
        printf '"landing_host":"%s",' "$(json_escape "${LANDING_HOST:-}")"
        printf '"landing_port":%s,' "${LANDING_PORT:-0}"
        printf '"forward_proto":"%s"' "${FORWARD_PROTO:-both}"
        printf '}'
        first="false"
    done
    printf ']'
    LOCAL_PORT="$saved_local"; NAT_PUBLIC_PORT="$saved_nat_public"; TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
}

render_nat_code_json() {
    local created_at ingress_listener_proto ingress_listener_protos nat_direction nat_listener_proto nat_listener_protos rules_json rules_b64
    validate_easytier_args
    [[ "$ROLE" == "nat-ingress" || "$ROLE" == "nat-transit" ]] || die_user "只有 NAT-IX Profile 可以生成 NAT-IX 接入码。"
    normalize_profile_compat_vars
    nat_direction="$(normalize_nat_direction "${NAT_DIRECTION:-ingress-listener}")" || die_user "NAT_DIRECTION 只能是 ingress-listener 或 nat-listener。"
    created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    if [[ "$nat_direction" == "nat-listener" ]]; then
        [[ "$ROLE" == "nat-transit" ]] || die_user "只有 NAT IX 中转线路可以生成推荐模式接入码。"
        nat_listener_proto="$(normalize_listener_proto "${NAT_LISTENER_PROTO:-both}" "both")"
        nat_listener_protos="$(normalize_listener_protos "$nat_listener_proto" "both")"
        rules_json="$(nat_code_rules_json)"
        rules_b64="$(nat_code_rules_b64)"

        printf '{'
        printf '"version":3,'
        printf '"code_schema":4,'
        printf '"project":"%s",' "$APP_NAME"
        printf '"mode":"nat-transit",'
        printf '"direction":"nat-listener",'
        printf '"role":"nat-listener-code",'
        printf '"profile_id":"%s",' "$(json_escape "${PROFILE_ID:-default}")"
        printf '"profile_name":"%s",' "$(json_escape "${PROFILE_NAME:-${PROFILE_ID:-default}}")"
        printf '"network_name":"%s",' "$(json_escape "$ET_NETWORK_NAME")"
        printf '"network_secret":"%s",' "$(json_escape "$ET_NETWORK_SECRET")"
        printf '"nat_hostname":"%s",' "$(json_escape "$ET_HOSTNAME")"
        printf '"nat_public_host":"%s",' "$(json_escape "$NAT_PUBLIC_HOST")"
        printf '"nat_public_port_spec":"%s",' "$(json_escape "$(nat_public_port_spec_for_code 2>/dev/null || printf '%s' "${NAT_LISTENER_PORT:-}")")"
        printf '"nat_public_port_mode":"%s",' "$(json_escape "${NAT_PUBLIC_PORT_MODE:-single}")"
        if code_ports="$(nat_public_ports_for_code_json 2>/dev/null)"; then
            printf '"nat_public_ports":"%s",' "$(json_escape "$code_ports")"
        fi
        printf '"nat_listener_port":%s,' "$NAT_LISTENER_PORT"
        printf '"nat_listener_proto":"%s",' "$nat_listener_proto"
        printf '"nat_listener_protos":%s,' "$(listener_protos_json "$nat_listener_proto")"
        printf '"nat_et_ip":"%s",' "$NAT_ET_IP"
        printf '"nat_et_cidr":"%s",' "${NAT_ET_CIDR:-$ET_IPV4}"
        printf '"ingress_et_ip":"%s",' "$INGRESS_ET_IP"
        printf '"ingress_et_cidr":"%s",' "${INGRESS_ET_CIDR:-${INGRESS_ET_IP}/24}"
        printf '"transit_port":%s,' "$TRANSIT_PORT"
        printf '"landing_host":"%s",' "$(json_escape "$LANDING_HOST")"
        printf '"landing_port":%s,' "$LANDING_PORT"
        printf '"forward_proto":"%s",' "${FORWARD_PROTO:-both}"
        printf '"rules":%s,' "$rules_json"
        printf '"rules_b64":"%s",' "$rules_b64"
        printf '"created_at":"%s"' "$created_at"
        printf '}'
        return 0
    fi

    [[ "$ROLE" == "nat-ingress" ]] || die_user "只有公网入口线路可以生成兼容旧模式接入码。"
    ingress_listener_proto="$(normalize_listener_proto "${INGRESS_LISTENER_PROTO:-both}" "both")"
    ingress_listener_protos="$(normalize_listener_protos "$ingress_listener_proto" "both")"

    printf '{'
    printf '"version":1,'
    printf '"project":"%s",' "$APP_NAME"
    printf '"mode":"nat-transit",'
    printf '"direction":"ingress-listener",'
    printf '"role":"nat-ingress-code",'
    printf '"profile_id":"%s",' "$(json_escape "${PROFILE_ID:-default}")"
    printf '"profile_name":"%s",' "$(json_escape "${PROFILE_NAME:-${PROFILE_ID:-default}}")"
    printf '"network_name":"%s",' "$(json_escape "$ET_NETWORK_NAME")"
    printf '"network_secret":"%s",' "$(json_escape "$ET_NETWORK_SECRET")"
    printf '"ingress_hostname":"%s",' "$(json_escape "${INGRESS_HOSTNAME:-$ET_HOSTNAME}")"
    printf '"ingress_public_host":"%s",' "$(json_escape "$INGRESS_PUBLIC_HOST")"
    printf '"ingress_et_ip":"%s",' "$INGRESS_ET_IP"
    printf '"ingress_et_cidr":"%s",' "${INGRESS_ET_CIDR:-$ET_IPV4}"
    printf '"ingress_listener_proto":"%s",' "$ingress_listener_proto"
    printf '"ingress_listener_protos":%s,' "$(listener_protos_json "$ingress_listener_proto")"
    printf '"ingress_listener_port":%s,' "$INGRESS_LISTENER_PORT"
    printf '"nat_et_ip":"%s",' "$NAT_ET_IP"
    printf '"nat_et_cidr":"%s",' "${NAT_ET_CIDR:-${NAT_ET_IP}/24}"
    printf '"local_port":%s,' "$LOCAL_PORT"
    printf '"transit_port":%s,' "$TRANSIT_PORT"
    printf '"forward_proto":"%s",' "${FORWARD_PROTO:-both}"
    printf '"created_at":"%s"' "$created_at"
    printf '}'
}

generate_nat_code() {
    render_nat_code_json | base64url_encode | sed 's/^/IXTF1:/'
}

save_landing_code_file() {
    local code="$1"
    ensure_config_dir
    printf '%s\n' "$code" >"$LANDING_CODE_FILE"
    chmod 600 "$LANDING_CODE_FILE"
}

format_rules_for_code_summary() {
    local profile_id="$1" rule_id index=0 saved_local saved_nat_public saved_transit saved_landing_host saved_landing_port saved_proto
    saved_local="${LOCAL_PORT:-}"; saved_nat_public="${NAT_PUBLIC_PORT:-}"; saved_transit="${TRANSIT_PORT:-}"; saved_landing_host="${LANDING_HOST:-}"; saved_landing_port="${LANDING_PORT:-}"; saved_proto="${FORWARD_PROTO:-both}"
    for rule_id in $(profile_rule_ids "$profile_id"); do
        load_rule "$profile_id" "$rule_id" || continue
        index=$((index + 1))
        printf '%s. %s  %s  [%s]  %s:%s -> %s:%s -> %s:%s（%s）\n' \
            "$index" "$rule_id" "$(profile_rule_status_display)" "$(rule_note_display)" \
            "${NAT_PUBLIC_HOST:-商家 NAT/IX 入口地址}" "$(rule_nat_public_port_display)" "${NAT_ET_IP:-NAT IX 虚拟 IP}" "${TRANSIT_PORT:-}" "${LANDING_HOST:-}" "${LANDING_PORT:-}" "$(proto_display_user "${FORWARD_PROTO:-both}")"
    done
    [[ "$index" -gt 0 ]] || printf '暂无转发规则。\n'
    LOCAL_PORT="$saved_local"; NAT_PUBLIC_PORT="$saved_nat_public"; TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
}

format_rules_for_port_map() {
    local profile_id="$1" rule_id saved_local saved_nat_public saved_transit saved_landing_host saved_landing_port saved_proto
    saved_local="${LOCAL_PORT:-}"; saved_nat_public="${NAT_PUBLIC_PORT:-}"; saved_transit="${TRANSIT_PORT:-}"; saved_landing_host="${LANDING_HOST:-}"; saved_landing_port="${LANDING_PORT:-}"; saved_proto="${FORWARD_PROTO:-both}"
    for rule_id in $(profile_rule_ids "$profile_id"); do
        load_rule "$profile_id" "$rule_id" || continue
        case "${ROLE:-}" in
            nat-ingress)
                printf '%s  %s  [%s]\n' "$rule_id" "$(profile_rule_status_display)" "$(rule_note_display)"
                printf '  公网入口端口：%s\n' "$(rule_client_port_display)"
                printf '  商家入口端口：%s\n' "$(rule_nat_public_port_display)"
                printf '  虚拟网中转端口：%s\n' "${TRANSIT_PORT:-虚拟网中转端口}"
                printf '  落地目标：%s:%s\n' "${LANDING_HOST:-落地目标}" "${LANDING_PORT:-}"
                printf '  完整路径：%s\n' "$(profile_rule_path_display)"
                printf '  协议：%s\n' "$(proto_display_user "${FORWARD_PROTO:-both}")"
                ;;
            nat-transit)
                printf '%s  %s  [%s]\n' "$rule_id" "$(profile_rule_status_display)" "$(rule_note_display)"
                printf '  公网入口端口：%s\n' "$(rule_client_port_display)"
                printf '  商家入口端口：%s\n' "$(rule_nat_public_port_display)"
                printf '  虚拟网中转端口：%s\n' "${TRANSIT_PORT:-虚拟网中转端口}"
                printf '  落地目标：%s:%s\n' "${LANDING_HOST:-落地机地址}" "${LANDING_PORT:-落地业务端口}"
                printf '  完整路径：%s\n' "$(profile_rule_path_display)"
                printf '  协议：%s\n' "$(proto_display_user "${FORWARD_PROTO:-both}")"
                ;;
        esac
        printf '\n'
    done
    LOCAL_PORT="$saved_local"; NAT_PUBLIC_PORT="$saved_nat_public"; TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
}

show_code_skip_security=""

show_code() {
    local code listener_proto listener_port listener_proto_display profile_id="${1:-}" code_path
    if [[ -n "$profile_id" || -d "$PROFILES_DIR" ]]; then
        if ! profile_id="$(resolve_profile_id_for_cmd "$profile_id" show-code)"; then
            return_or_exit 2 || return $?
        fi
        if ! load_profile "$profile_id"; then
            print_profile_selection_hint "$profile_id" show-code
            return_or_exit 2 || return $?
        fi
    elif ! load_env; then
        printf '[WARN] 未找到可读取的配置文件：%s。请先安装落地机模式。\n' "$ENV_FILE"
        return 0
    fi
    normalize_profile_compat_vars
    if [[ "${ROLE:-}" == "nat-ingress" || ( "${ROLE:-}" == "nat-transit" && "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ) ]]; then
        code="$(generate_nat_code)"
        if [[ -n "${PROFILE_ID:-}" && "${PROFILE_ID:-default}" != "default" ]]; then
            save_profile_code_file "$PROFILE_ID" "$code"
        fi
        if [[ "${ROLE:-}" == "nat-transit" && "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
            cat <<EOF
NAT IX 中转线路接入码：${PROFILE_ID:-default}

接入码包含规则：
$(format_rules_for_code_summary "$PROFILE_ID")

接入码：
$(c_yellow '===== 接入码开始 =====')
${code}
$(c_yellow '===== 接入码结束 =====')
EOF
            print_access_code_security_hint
            printf '\n下一步：\n'
            printf '在公网入口机运行 bash install.sh，选择“公网入口机导入接入码”。\n'
            return 0
        fi
        if [[ "${show_code_skip_security:-}" == "true" ]]; then
            cat <<EOF
NAT-IX 接入码（复制整段到 NAT IX 机器）
$(c_yellow '===== 接入码开始 =====')
${code}
$(c_yellow '===== 接入码结束 =====')

NAT IX 机器导入后会连接：
入口机：${INGRESS_PUBLIC_HOST}:${INGRESS_LISTENER_PORT}
公网入口机虚拟 IP：${INGRESS_ET_IP}
NAT IX 虚拟 IP：${NAT_ET_IP}
虚拟网中转端口：${TRANSIT_PORT}
EOF
        else
            cat <<EOF
NAT-IX 接入码（复制整段到 NAT IX 机器）
$(c_yellow '===== 接入码开始 =====')
${code}
$(c_yellow '===== 接入码结束 =====')

NAT IX 机器导入后会连接：
入口机：${INGRESS_PUBLIC_HOST}:${INGRESS_LISTENER_PORT}
公网入口机虚拟 IP：${INGRESS_ET_IP}
NAT IX 虚拟 IP：${NAT_ET_IP}
虚拟网中转端口：${TRANSIT_PORT}
EOF
            print_access_code_security_hint
        fi
        return 0
    fi
    printf '[WARN] 当前角色不能生成接入码；请使用 nat-ingress 或 nat-transit nat-listener。\n'
    return 0
}

access_code_payload_decodes() {
    local code="$1" payload decoded
    [[ "$code" == IXTF1:* ]] || return 1
    payload="${code#IXTF1:}"
    decoded="$(base64url_decode "$payload" 2>/dev/null)" || return 1
    [[ "$decoded" == \{* ]]
}

extract_landing_code() {
    local input="$1"
    local line_code compact compact_code
    input="${input//$'\r'/}"
    line_code="$(printf '%s\n' "$input" | grep -Eo 'IXTF1:[A-Za-z0-9_-]+' | head -n 1 || true)"
    compact="$(printf '%s' "$input" | tr -d '[:space:]')"
    compact_code="$(printf '%s\n' "$compact" | grep -Eo 'IXTF1:[A-Za-z0-9_-]+' | head -n 1 || true)"
    if [[ -n "$compact_code" ]] && access_code_payload_decodes "$compact_code"; then
        printf '%s\n' "$compact_code"
        return 0
    fi
    if [[ -n "$line_code" ]]; then
        printf '%s\n' "$line_code"
        return 0
    fi
    if [[ -n "$compact_code" ]]; then
        printf '%s\n' "$compact_code"
        return 0
    fi
    return 1
}

drain_access_code_trailing_blank_input() {
    local more trimmed
    [[ -t 0 ]] || return 0
    while IFS= read -r -t 0.05 more; do
        trimmed="$(trim_space "${more%$'\r'}")"
        [[ -z "$trimmed" ]] || break
    done
}

read_access_code_from_tty() {
    local prompt="${1:-请粘贴接入码（IXTF1:...）：}" line buffer="" code lines=0
    require_tty
    printf '%s' "$prompt" >&2
    while true; do
        IFS= read -r line || return 1
        line="${line%$'\r'}"
        buffer="${buffer}${buffer:+$'\n'}${line}"
        if code="$(extract_landing_code "$buffer" 2>/dev/null)" && access_code_payload_decodes "$code"; then
            drain_access_code_trailing_blank_input
            printf '%s\n' "$code"
            return 0
        fi
        lines=$((lines + 1))
        if (( lines >= 8 )); then
            die_user "未识别到有效 IXTF1 接入码，请重新粘贴。"
        fi
        printf '未识别到有效 IXTF1 接入码，请继续粘贴或重新粘贴：' >&2
    done
}

read_code_from_args_or_prompt() {
    local code
    if [[ -n "$CODE_ARG" ]]; then
        extract_landing_code "$CODE_ARG" || die_user "未识别到有效 IXTF1 接入码，请重新粘贴。"
        return 0
    fi
    if [[ -n "$CODE_FILE_ARG" ]]; then
        [[ -r "$CODE_FILE_ARG" ]] || die_user "无法读取接入码文件：${CODE_FILE_ARG}"
        code="$(cat "$CODE_FILE_ARG")"
        extract_landing_code "$code" || die_user "未识别到有效 IXTF1 接入码，请重新粘贴。"
        return 0
    fi
    read_access_code_from_tty "请粘贴落地机接入码（IXTF1:...）："
}

read_nat_code_from_args_or_prompt() {
    local code
    if [[ -n "$CODE_ARG" ]]; then
        extract_landing_code "$CODE_ARG" || die_user "未识别到有效 IXTF1 接入码，请重新粘贴。"
        return 0
    fi
    if [[ -n "$CODE_FILE_ARG" ]]; then
        [[ -r "$CODE_FILE_ARG" ]] || die_user "无法读取 NAT-IX 接入码文件：${CODE_FILE_ARG}"
        code="$(cat "$CODE_FILE_ARG")"
        extract_landing_code "$code" || die_user "未识别到有效 IXTF1 接入码，请重新粘贴。"
        return 0
    fi
    read_access_code_from_tty "请粘贴 NAT-IX 接入码（IXTF1:...）："
}

import_code() {
    legacy_panel_removed
}

validate_code_rules_tsv() {
    local line rule_id note enabled nat_public_port transit_port landing_host landing_port forward_proto extra count=0 normalized="" compat="false"
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -n "$line" ]] || continue
        IFS=$'\t' read -r rule_id note enabled nat_public_port transit_port landing_host landing_port forward_proto extra <<<"$line"
        [[ -n "${rule_id:-}" ]] || continue
        if [[ -z "${forward_proto:-}" && -n "${landing_port:-}" ]]; then
            forward_proto="$landing_port"
            landing_port="$landing_host"
            landing_host="$transit_port"
            transit_port="$nat_public_port"
            nat_public_port="${CODE_NAT_LISTENER_PORT:-}"
            compat="true"
        fi
        validate_rule_id "$rule_id" || die_user "接入码中的 rule_id 不正确：${rule_id}"
        case "${enabled:-true}" in true|false) ;; *) die_user "接入码中的 enabled 不正确：${rule_id}" ;; esac
        validate_port "$nat_public_port" || die_user "接入码中的 nat_public_port 不正确：${rule_id}"
        validate_port "$transit_port" || die_user "接入码中的 transit_port 不正确：${rule_id}"
        validate_host "$landing_host" || die_user "接入码中的 landing_host 不正确：${rule_id}"
        validate_port "$landing_port" || die_user "接入码中的 landing_port 不正确：${rule_id}"
        forward_proto="$(normalize_forward_proto "${forward_proto:-both}" "both")" || die_user "接入码中的 forward_proto 不正确：${rule_id}"
        normalized="${normalized}${normalized:+$'\n'}$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' "$rule_id" "$note" "${enabled:-true}" "$nat_public_port" "$transit_port" "$landing_host" "$landing_port" "$forward_proto")"
        count=$((count + 1))
    done <<<"${CODE_RULES_TSV:-}"
    [[ "$count" -gt 0 ]] || die_user "接入码中没有可用转发规则。"
    CODE_RULES_TSV="$normalized"
    CODE_RULE_COUNT="$count"
    CODE_RULES_COMPAT_NAT_PORT="$compat"
}

parse_nat_code() {
    local code="$1"
    local payload json version project mode role direction cidr_ip normalized ingress_listener_protos nat_listener_protos rules_b64
    code="$(extract_landing_code "$code")" || die_user "接入码格式不正确，应以 IXTF1: 开头。"
    payload="${code#IXTF1:}"
    json="$(base64url_decode "$payload")" || die_user "NAT-IX 接入码解码失败，请确认复制完整。"

    version="$(json_get_number "$json" "version")"
    CODE_CODE_SCHEMA="$(json_get_number "$json" "code_schema")"
    project="$(json_get_string "$json" "project")"
    mode="$(json_get_string "$json" "mode")"
    role="$(json_get_string "$json" "role")"
    direction="$(json_get_string "$json" "direction")"

    [[ "$version" == "1" || "$version" == "2" || "$version" == "3" || "$version" == "4" || -z "$version" ]] || die_user "NAT-IX 接入码版本不支持。"
    [[ "$project" == "$APP_NAME" ]] || die_user "NAT-IX 接入码项目不匹配。"
    [[ "$mode" == "nat-transit" ]] || die_user "NAT-IX 接入码 mode 不匹配。"
    [[ "$role" == "nat-ingress-code" || "$role" == "nat-listener-code" ]] || die_user "NAT-IX 接入码 role 不匹配。"
    case "$role" in
        nat-ingress-code) CODE_NAT_DIRECTION="$(normalize_nat_direction "${direction:-ingress-listener}")" || die_user "NAT-IX 接入码 direction 不正确。" ;;
        nat-listener-code) CODE_NAT_DIRECTION="$(normalize_nat_direction "${direction:-nat-listener}")" || die_user "NAT-IX 接入码 direction 不正确。" ;;
    esac
    if [[ "$role" == "nat-ingress-code" && "$CODE_NAT_DIRECTION" != "ingress-listener" ]]; then
        die_user "nat-ingress-code 必须使用 direction=ingress-listener。"
    fi
    if [[ "$role" == "nat-listener-code" && "$CODE_NAT_DIRECTION" != "nat-listener" ]]; then
        die_user "nat-listener-code 必须使用 direction=nat-listener。"
    fi

    CODE_NETWORK_NAME="$(json_get_string "$json" "network_name")"
    CODE_NETWORK_SECRET="$(json_get_string "$json" "network_secret")"
    CODE_PROFILE_ID="$(json_get_string "$json" "profile_id")"
    CODE_PROFILE_NAME="$(json_get_string "$json" "profile_name")"
    CODE_INGRESS_HOSTNAME="$(json_get_string "$json" "ingress_hostname")"
    CODE_INGRESS_PUBLIC_HOST="$(json_get_string "$json" "ingress_public_host")"
    CODE_INGRESS_ET_IP="$(json_get_string "$json" "ingress_et_ip")"
    CODE_INGRESS_ET_CIDR="$(json_get_string "$json" "ingress_et_cidr")"
    CODE_INGRESS_LISTENER_PROTO="$(json_get_string "$json" "ingress_listener_proto")"
    ingress_listener_protos="$(json_get_string_array_as_words "$json" "ingress_listener_protos" 2>/dev/null || true)"
    [[ -n "$CODE_INGRESS_LISTENER_PROTO" && -z "$ingress_listener_protos" ]] && ingress_listener_protos="$CODE_INGRESS_LISTENER_PROTO"
    CODE_INGRESS_LISTENER_PORT="$(json_get_number "$json" "ingress_listener_port")"
    CODE_NAT_PUBLIC_HOST="$(json_get_string "$json" "nat_public_host")"
    CODE_NAT_PUBLIC_PORTS="$(json_get_string "$json" "nat_public_ports")"
    CODE_NAT_PUBLIC_PORT_SPEC="$(json_get_string "$json" "nat_public_port_spec")"
    CODE_NAT_PUBLIC_PORT_MODE="$(json_get_string "$json" "nat_public_port_mode")"
    CODE_NAT_LISTENER_PROTO="$(json_get_string "$json" "nat_listener_proto")"
    nat_listener_protos="$(json_get_string_array_as_words "$json" "nat_listener_protos" 2>/dev/null || true)"
    [[ -n "$CODE_NAT_LISTENER_PROTO" && -z "$nat_listener_protos" ]] && nat_listener_protos="$CODE_NAT_LISTENER_PROTO"
    CODE_NAT_LISTENER_PORT="$(json_get_number "$json" "nat_listener_port")"
    CODE_NAT_ET_IP="$(json_get_string "$json" "nat_et_ip")"
    CODE_NAT_ET_CIDR="$(json_get_string "$json" "nat_et_cidr")"
    CODE_LOCAL_PORT="$(json_get_number "$json" "local_port")"
    CODE_TRANSIT_PORT="$(json_get_number "$json" "transit_port")"
    CODE_LANDING_HOST="$(json_get_string "$json" "landing_host")"
    CODE_LANDING_PORT="$(json_get_number "$json" "landing_port")"
    CODE_FORWARD_PROTO="$(json_get_string "$json" "forward_proto")"
    rules_b64="$(json_get_string "$json" "rules_b64")"
    CODE_RULES_B64="$rules_b64"

    validate_network_name "$CODE_NETWORK_NAME" || die_user "接入码中的 network_name 格式不正确。"
    validate_secret "$CODE_NETWORK_SECRET" || die_user "接入码中的 network_secret 不合法或长度不足。"
    validate_ipv4 "$CODE_NAT_ET_IP" || die_user "接入码中的 nat_et_ip 不正确。"
    validate_ipv4_cidr "$CODE_NAT_ET_CIDR" || die_user "接入码中的 nat_et_cidr 不正确。"
    cidr_ip="${CODE_NAT_ET_CIDR%%/*}"
    [[ "$cidr_ip" == "$CODE_NAT_ET_IP" ]] || die_user "接入码中的 nat_et_ip 和 nat_et_cidr 不一致。"
    validate_port "$CODE_TRANSIT_PORT" || die_user "接入码中的 transit_port 不正确。"

    if [[ "$CODE_NAT_DIRECTION" == "nat-listener" ]]; then
        validate_host "$CODE_NAT_PUBLIC_HOST" || die_user "接入码中的 nat_public_host 不正确。"
        normalized="$(normalize_entry_proto "${nat_listener_protos:-$CODE_NAT_LISTENER_PROTO}" "both")" || die_user "接入码中的 nat_listener_proto 不正确。"
        CODE_NAT_LISTENER_PROTO="$normalized"
        CODE_NAT_LISTENER_PROTOS="$(normalize_peer_protos "$normalized" "both")"
        validate_port "$CODE_NAT_LISTENER_PORT" || die_user "接入码中的 nat_listener_port 不正确。"
        CODE_NAT_PUBLIC_PORT_MODE="${CODE_NAT_PUBLIC_PORT_MODE:-single}"
        validate_ipv4 "$CODE_INGRESS_ET_IP" || die_user "接入码中的 ingress_et_ip 不正确。"
        validate_ipv4_cidr "$CODE_INGRESS_ET_CIDR" || die_user "接入码中的 ingress_et_cidr 不正确。"
        cidr_ip="${CODE_INGRESS_ET_CIDR%%/*}"
        [[ "$cidr_ip" == "$CODE_INGRESS_ET_IP" ]] || die_user "接入码中的 ingress_et_ip 和 ingress_et_cidr 不一致。"
        validate_host "$CODE_LANDING_HOST" || die_user "接入码中的 landing_host 不正确。"
        validate_port "$CODE_LANDING_PORT" || die_user "接入码中的 landing_port 不正确。"
    else
        validate_host "$CODE_INGRESS_PUBLIC_HOST" || die_user "接入码中的 ingress_public_host 不正确。"
        validate_ipv4 "$CODE_INGRESS_ET_IP" || die_user "接入码中的 ingress_et_ip 不正确。"
        validate_ipv4_cidr "$CODE_INGRESS_ET_CIDR" || die_user "接入码中的 ingress_et_cidr 不正确。"
        cidr_ip="${CODE_INGRESS_ET_CIDR%%/*}"
        [[ "$cidr_ip" == "$CODE_INGRESS_ET_IP" ]] || die_user "接入码中的 ingress_et_ip 和 ingress_et_cidr 不一致。"
        normalized="$(normalize_entry_proto "${ingress_listener_protos:-$CODE_INGRESS_LISTENER_PROTO}" "both")" || die_user "接入码中的 ingress_listener_proto 不正确。"
        CODE_INGRESS_LISTENER_PROTO="$normalized"
        CODE_INGRESS_LISTENER_PROTOS="$(normalize_peer_protos "$normalized" "both")"
        validate_port "$CODE_INGRESS_LISTENER_PORT" || die_user "接入码中的 ingress_listener_port 不正确。"
        if [[ -n "${CODE_LOCAL_PORT:-}" ]]; then
            validate_port "$CODE_LOCAL_PORT" || die_user "接入码中的 local_port 不正确。"
        fi
    fi
    CODE_FORWARD_PROTO="$(normalize_forward_proto "${CODE_FORWARD_PROTO:-both}" "both")" || die_user "接入码中的 forward_proto 不正确。"
    if [[ -n "$rules_b64" ]]; then
        CODE_RULES_TSV="$(base64url_decode "$rules_b64")" || die_user "接入码 rules_b64 解码失败。"
    else
        CODE_RULES_TSV="$(printf 'rule-main\t默认转发\ttrue\t%s\t%s\t%s\t%s\t%s\n' "${CODE_NAT_LISTENER_PORT:-}" "$CODE_TRANSIT_PORT" "${CODE_LANDING_HOST:-landing.example}" "${CODE_LANDING_PORT:-50000}" "$CODE_FORWARD_PROTO")"
    fi
    validate_code_rules_tsv
    if [[ "$CODE_NAT_DIRECTION" == "nat-listener" ]]; then
        if [[ -n "${CODE_NAT_PUBLIC_PORTS:-}" ]]; then
            CODE_NAT_PUBLIC_PORTS="$(normalize_nat_public_ports_input "${CODE_NAT_PUBLIC_PORTS:-$CODE_NAT_LISTENER_PORT}")" || die_user "接入码中的 nat_public_ports 不正确。"
        elif ports_from_rules="$(code_rules_nat_public_ports_csv 2>/dev/null || true)"; [[ -n "$ports_from_rules" ]]; then
            CODE_NAT_PUBLIC_PORTS="$(normalize_nat_public_ports_input "$ports_from_rules")" || die_user "接入码 rules 中的 nat_public_port 不正确。"
        else
            CODE_NAT_PUBLIC_PORTS="$(normalize_nat_public_ports_input "${CODE_NAT_LISTENER_PORT}")" || die_user "接入码缺少 nat_public_ports 且无法从 rules 推导。"
        fi
        CODE_NAT_PUBLIC_PORT_SPEC="${CODE_NAT_PUBLIC_PORT_SPEC:-${CODE_NAT_PUBLIC_PORTS:-}}"
    fi
}

collect_nat_ingress_inputs() {
    local default_network default_secret default_subnet default_ingress_cidr default_nat_cidr default_listener_port default_local_port default_transit_port default_public public_prompt env_public detected_public
    require_tty add-nat-ingress-profile
    ROLE="nat-ingress"
    NAT_DIRECTION="ingress-listener"
    default_network="$(generate_network_name)"
    default_secret="$(generate_secret)"
    default_subnet="$(generate_et_subnet)"
    default_ingress_cidr="$(cidr_from_subnet_host "$default_subnet" 1)"
    default_nat_cidr="$(cidr_from_subnet_host "$default_subnet" 2)"
    default_listener_port="$(pick_random_port_excluding_listeners both || true)"
    default_local_port="$(pick_random_port || true)"
    default_transit_port="$(pick_random_port || true)"
    default_public=""

    cat >&2 <<EOF
按 Enter 使用推荐默认值。
兼容旧模式默认连接方向：公网入口机监听，NAT IX 机器连接公网入口机。

EOF
    if env_public="$(detect_env_ingress_public_host)"; then
        default_public="$env_public"
        printf '使用环境变量指定的公网入口地址：%s\n' "$default_public" >&2
        public_prompt="请输入公网入口机公网 IP 或域名 INGRESS_PUBLIC_HOST"
    elif detected_public="$(detect_public_ipv4)"; then
        default_public="$detected_public"
        printf '检测到当前公网 IPv4：%s\n' "$default_public" >&2
        public_prompt="请输入公网入口机公网 IP 或域名 INGRESS_PUBLIC_HOST"
    else
        printf '未自动检测到公网 IPv4。\n' >&2
        public_prompt="请输入公网入口机公网 IP 或域名 INGRESS_PUBLIC_HOST"
    fi
    ET_NETWORK_NAME="$(prompt_validated "请输入 EasyTier 网络名" "$default_network" validate_network_name "请输入 1-64 个字符，仅允许字母、数字、点、下划线或短横线。")" || return 1
    ET_NETWORK_SECRET="$(prompt_secret_default "$default_secret")" || return 1
    ET_HOSTNAME="$(prompt_validated "请输入当前节点名称" "ix-nat-ingress-${PROFILE_ID:-default}" validate_hostname_value "请输入 1-64 个字符，仅允许字母、数字、点、下划线或短横线。")" || return 1
    INGRESS_HOSTNAME="$ET_HOSTNAME"
    INGRESS_PUBLIC_HOST="$(prompt_validated "$public_prompt" "$default_public" validate_host "请输入公网 IP 或域名。")" || return 1
    ET_IPV4="$(prompt_validated "请输入公网入口机 EasyTier IP，例如 ${default_ingress_cidr}" "$default_ingress_cidr" validate_ipv4_cidr "请输入 IPv4/CIDR，例如 ${default_ingress_cidr}。")" || return 1
    INGRESS_ET_CIDR="$ET_IPV4"
    INGRESS_ET_IP="${INGRESS_ET_CIDR%%/*}"
    ET_SUBNET="$(cidr_network24 "$ET_IPV4")"
    NAT_ET_CIDR="$(prompt_validated "请输入 NAT IX 机器 EasyTier IP，例如 ${default_nat_cidr}" "$default_nat_cidr" validate_ipv4_cidr "请输入 IPv4/CIDR，例如 ${default_nat_cidr}。")" || return 1
    NAT_ET_IP="${NAT_ET_CIDR%%/*}"
    INGRESS_LISTENER_PROTO="$(prompt_listener_proto "请选择公网入口机 EasyTier listener 协议（tcp / udp / tcp+udp / ws / wss / quic / wg / all）" "both")" || return 1
    INGRESS_LISTENER_PROTOS="$(normalize_listener_protos "$INGRESS_LISTENER_PROTO" "both")"
    INGRESS_LISTENER_PORT="$(prompt_listener_port "请输入公网入口机 EasyTier listener 端口" "$INGRESS_LISTENER_PROTO" "$default_listener_port")" || return 1
    if [[ -n "$default_listener_port" && "$INGRESS_LISTENER_PORT" == "$default_listener_port" ]]; then
        ET_LISTENER_PORT_WAS_DEFAULT="true"
    else
        ET_LISTENER_PORT_WAS_DEFAULT="false"
    fi
    LOCAL_PORT="$(prompt_random_port "请输入客户端连接端口 LOCAL_PORT" "$default_local_port")" || return 1
    TRANSIT_PORT="$(prompt_random_port "请输入 NAT IX 机器中转接收端口 TRANSIT_PORT" "$default_transit_port")" || return 1
    FORWARD_PROTO="$(prompt_forward_proto "请选择业务转发协议（tcp / udp / both / tcp/udp）" "both")" || return 1
    ET_LISTENER_PROTO="$INGRESS_LISTENER_PROTO"
    ET_LISTENER_PORT="$INGRESS_LISTENER_PORT"
    ET_LISTENERS="$(listener_urls_value "$INGRESS_LISTENER_PROTO" "$INGRESS_LISTENER_PORT")"
    ET_PRIVATE_MODE="true"
    ET_EXPLICIT_ONLY="true"
    IXTF_EXPLICIT_ONLY="true"
    FORWARD_ENABLED="true"
}

collect_nat_listener_inputs() {
    local default_network default_secret default_subnet default_ingress_cidr default_nat_cidr default_transit_port advanced nat_public_ports_input
    require_tty add-nat-listener-profile
    ROLE="nat-transit"
    NAT_DIRECTION="nat-listener"
    default_network="$(generate_network_name)"
    default_secret="$(generate_secret)"
    default_subnet="$(generate_et_subnet)"
    default_ingress_cidr="$(cidr_from_subnet_host "$default_subnet" 1)"
    default_nat_cidr="$(cidr_from_subnet_host "$default_subnet" 2)"
    default_transit_port="$(pick_random_port || true)"

    NAT_PUBLIC_HOST="$(prompt_validated "请输入商家分配给你的 NAT/IX 入口地址" "" validate_host "请输入商家分配给你的入口 IP 或域名。")" || return 1
    prompt_nat_public_ports "请输入商家分配给你的 NAT/IX 入口端口或端口段" "" || return 1
    nat_public_ports_input="${PROMPT_NAT_PUBLIC_PORTS_NORMALIZED:-}"
    NAT_PUBLIC_PORT_SPEC="${PROMPT_NAT_PUBLIC_PORT_RAW:-$nat_public_ports_input}"
    NAT_PUBLIC_PORTS="$nat_public_ports_input"
    NAT_PUBLIC_PORT_MODE="${PROMPT_NAT_PUBLIC_PORT_MODE:-$(nat_public_port_mode_for_input "$nat_public_ports_input")}"
    NAT_LISTENER_PORT="$(first_nat_public_port "$NAT_PUBLIC_PORTS")" || return 1
    LANDING_HOST="$(prompt_validated "请输入落地机公网 IP 或域名" "" validate_host "请输入落地机 IP 或域名。")" || return 1
    LANDING_PORT="$(prompt_port "请输入落地业务端口" "")" || return 1
    advanced="$(prompt_yes_no "是否自定义高级参数" "false")" || return 1
    if [[ "$advanced" == "true" ]]; then
        collect_profile_identity "nat-listener" || return 1
        ET_NETWORK_NAME="$(prompt_validated "请输入网络名" "$default_network" validate_network_name "请输入 1-64 个字符，仅允许字母、数字、点、下划线或短横线。")" || return 1
        ET_NETWORK_SECRET="$(prompt_secret_default "$default_secret")" || return 1
        ET_HOSTNAME="$(prompt_validated "请输入节点名" "ix-nat-listener-${PROFILE_ID}" validate_hostname_value "请输入 1-64 个字符，仅允许字母、数字、点、下划线或短横线。")" || return 1
        NAT_ET_CIDR="$(prompt_validated "请输入 NAT IX 虚拟 IP，例如 ${default_nat_cidr}" "$default_nat_cidr" validate_ipv4_cidr "请输入 IPv4/CIDR，例如 ${default_nat_cidr}。")" || return 1
        INGRESS_ET_CIDR="$(prompt_validated "请输入公网入口机虚拟 IP，例如 ${default_ingress_cidr}" "$default_ingress_cidr" validate_ipv4_cidr "请输入 IPv4/CIDR，例如 ${default_ingress_cidr}。")" || return 1
        TRANSIT_PORT="$(prompt_virtual_transit_port "$default_transit_port")" || return 1
        NAT_LISTENER_PROTO="$(prompt_easytier_protocol_choice 1)" || return 1
        FORWARD_PROTO="$(prompt_forward_proto "请选择转发协议（tcp / udp / both / tcp/udp）" "both")" || return 1
    else
        assign_auto_profile_identity "nat-listener"
        ET_NETWORK_NAME="$default_network"
        ET_NETWORK_SECRET="$default_secret"
        ET_HOSTNAME="ix-nat-listener-${PROFILE_ID}"
        NAT_ET_CIDR="$default_nat_cidr"
        INGRESS_ET_CIDR="$default_ingress_cidr"
        TRANSIT_PORT="$default_transit_port"
        NAT_LISTENER_PROTO="$(prompt_easytier_protocol_choice 1)" || return 1
        FORWARD_PROTO="both"
    fi
    NAT_LISTENER_PROTOS="$(normalize_listener_protos "$NAT_LISTENER_PROTO" "both")"
    if [[ -z "${TRANSIT_PORT:-}" ]]; then
        TRANSIT_PORT="$(prompt_virtual_transit_port "$default_transit_port")" || return 1
    fi
    NAT_ET_IP="${NAT_ET_CIDR%%/*}"
    ET_IPV4="$NAT_ET_CIDR"
    ET_SUBNET="$(cidr_network24 "$ET_IPV4")"
    INGRESS_ET_IP="${INGRESS_ET_CIDR%%/*}"
    if validate_ipv4 "$LANDING_HOST"; then
        LANDING_IP="$LANDING_HOST"
    else
        LANDING_IP=""
    fi
    ET_LISTENER_PROTO="$NAT_LISTENER_PROTO"
    ET_LISTENER_PORT="$NAT_LISTENER_PORT"
    ET_LISTENERS="$(listener_urls_for_ports_value "$NAT_LISTENER_PROTO" "$NAT_LISTENER_PORT")"
    ET_NO_LISTENER="false"
    ET_PRIVATE_MODE="true"
    ET_EXPLICIT_ONLY="true"
    IXTF_EXPLICIT_ONLY="true"
    FORWARD_ENABLED="true"
}

print_config_summary() {
    local source="${1:-env}" profile_id="${PROFILE_ID:-default}"
    if [[ "$source" != "loaded" ]]; then
        if ! load_env; then
            printf '配置文件：未找到（%s）\n' "$ENV_FILE"
            return 1
        fi
    fi

    printf '项目：%s\n' "$APP_NAME"
    printf '线路 ID：%s\n' "$profile_id"
    printf '线路类型：%s\n' "$(profile_role_label_zh "${ROLE:-}")"
    printf '线路模式：%s\n' "$(line_role_label_zh "${LINE_ROLE:-standalone}")"
    printf '启用状态：%s\n' "$(enabled_label_zh "${ENABLED:-true}")"
    printf '转发状态：%s\n' "$(forward_label_zh "${ROLE:-}" "${ENABLED:-true}" "${FORWARD_ENABLED:-true}")"
    printf '健康状态：%s\n' "$(health_label_zh "${HEALTH_STATUS:-unknown}")"
    [[ -n "${LAST_HEALTH_CHECK_AT:-}" ]] && printf '最近健康检查：%s\n' "$LAST_HEALTH_CHECK_AT"
    [[ -n "${LAST_HEALTH_REASON:-}" ]] && printf '健康说明：%s\n' "$LAST_HEALTH_REASON"

    printf '\nEasyTier：\n'
    printf '* 网络名：%s\n' "${ET_NETWORK_NAME:-}"
    printf '* 网络密钥：%s\n' "$(mask_secret "${ET_NETWORK_SECRET:-}")"
    printf '* 节点名称：%s\n' "${ET_HOSTNAME:-}"
    printf '* 本机虚拟 IP：%s\n' "${ET_IPV4:-}"
    printf '* 组网协议：%s\n' "$(profile_easytier_proto_display)"

    case "${ROLE:-}" in
        nat-ingress|nat-transit)
            printf '\nNAT-IX：\n'
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                printf '* 部署方向：NAT IX 机器监听，公网入口机连接 NAT IX\n'
            else
                printf '* 部署方向：公网入口机监听，NAT IX 机器连接公网入口机（兼容旧模式）\n'
            fi
            printf '* 当前机器角色：%s\n' "$(nat_ix_machine_role_label)"
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                printf '* 商家入口：%s:%s\n' "${NAT_PUBLIC_HOST:-}" "${NAT_PUBLIC_PORTS:-${NAT_LISTENER_PORT:-}}"
            elif [[ "${ROLE:-}" == "nat-ingress" ]]; then
                printf '* 公网入口监听：%s:%s\n' "${INGRESS_PUBLIC_HOST:-}" "${INGRESS_LISTENER_PORT:-}"
            else
                printf '* 公网入口监听：%s:%s\n' "${INGRESS_PUBLIC_HOST:-}" "${INGRESS_LISTENER_PORT:-}"
            fi
            printf '* 公网入口机虚拟 IP：%s\n' "${INGRESS_ET_IP:-}"
            printf '* NAT IX 虚拟 IP：%s\n' "${NAT_ET_IP:-}"
            printf '\n转发规则：\n'
            format_rules_for_show_config "$profile_id"
            ;;
        nat-transit)
            normalize_profile_compat_vars
            printf '\n落地机：\n'
            if [[ -n "${ET_LISTENERS:-}" || ( -n "${ET_LISTENER_PROTO:-}" && -n "${ET_LISTENER_PORT:-}" ) ]]; then
                print_easytier_listeners
            else
                printf '[WARN] 线路缺少 listener 端口，请检查配置文件。\n'
            fi
            [[ -n "${REMOTE_PORT:-${SERVICE_PORT:-}}" ]] && printf '* 业务端口：%s\n' "${REMOTE_PORT:-${SERVICE_PORT:-}}"
            ;;
        nat-ingress)
            printf '\n旧版入口：\n'
            printf '* CNIX 面板入口：%s://%s:%s\n' "$(proto_display_user "${CNIX_ENTRY_PROTO:-tcp}")" "${CNIX_ENTRY_HOST:-}" "${CNIX_ENTRY_PORT:-}"
            if [[ "${FORWARD_ENABLED:-true}" == "true" ]]; then
                printf '* 客户端入口端口：%s\n' "${LOCAL_PORT:-}"
                printf '* 落地目标：%s:%s\n' "${LANDING_ET_IP:-}" "${REMOTE_PORT:-}"
                printf '* 转发协议：%s\n' "$(proto_display_user "${FORWARD_PROTO:-both}")"
            else
                printf '* 业务转发：未配置\n'
            fi
            ;;
    esac
    return 0
}

print_config_summary_diagnostic() {
    local source="${1:-env}"
    if [[ "$source" != "loaded" ]]; then
        load_env || return 1
    fi
    printf 'ROLE=%s\n' "${ROLE:-}"
    printf 'LINE_GROUP=%s\n' "${LINE_GROUP:-}"
    printf 'LINE_ROLE=%s\n' "${LINE_ROLE:-standalone}"
    printf 'LINE_PRIORITY=%s\n' "${LINE_PRIORITY:-100}"
    printf 'ENABLED=%s\n' "${ENABLED:-true}"
    printf 'FORWARD_ENABLED=%s\n' "${FORWARD_ENABLED:-true}"
    printf 'FORWARD_PROTO=%s\n' "${FORWARD_PROTO:-both}"
    printf 'HEALTH_STATUS=%s\n' "${HEALTH_STATUS:-unknown}"
    return 0
}

show_profile_summary() {
    require_root "$@"
    local profile_id="${1:-}" service active enabled_status listener_port listener_proto remote_port landing_public
    profile_id="$(resolve_profile_id "$profile_id")"
    load_profile_or_die "$profile_id"
    normalize_profile_compat_vars
    service="$(profile_service_name "$profile_id")"
    listener_port="${LISTENER_PORT:-${ET_LISTENER_PORT:-}}"
    listener_proto="${ET_LISTENER_PROTO:-${LISTENER_PROTOS:-}}"
    remote_port="${REMOTE_PORT:-${SERVICE_PORT:-}}"
    landing_public="${LANDING_PUBLIC_HOST:-落地 VPS 公网 IP}"
    if command_exists systemctl; then
        active="$(systemctl is-active "$service" 2>/dev/null || true)"
        enabled_status="$(systemctl is-enabled "$service" 2>/dev/null || true)"
    else
        active="unknown"
        enabled_status="unknown"
    fi

    case "${ROLE:-}" in
        nat-transit)
            printf '\n%s\n' "$(c_green "落地线路已完成：${profile_id}")"
            if [[ -z "$listener_port" ]]; then
                printf '[WARN] 线路配置缺少 listener 端口，请检查配置文件：%s\n' "$(profile_env_path "$profile_id")"
            fi
            print_box "【CNIX 面板出口填写】" \
                "出口 IP：${landing_public}" \
                "出口端口：$(c_cyan "${listener_port:-LISTENER_PORT}")" \
                "出口协议：$(proto_display "$listener_proto")"
            printf '\n%s\n' "$(c_bold "LISTENER_PORT 是 EasyTier listener / WG ListenPort 等价端口。")"
            printf '%s\n' "$(c_yellow "REMOTE_PORT 是落地业务服务端口，不要填到 CNIX 面板出口。")"
            printf '\n线路信息：\n'
            printf '  ID：%s\n' "$profile_id"
            printf '  名称：%s\n' "${PROFILE_NAME:-$profile_id}"
            printf '  角色：%s\n' "${ROLE:-}"
            printf '  EasyTier 虚拟 IP：%s\n' "${ET_IPV4:-未配置}"
            printf '  EasyTier listener：%s :%s\n' "$(proto_display "$listener_proto")" "${listener_port:-未配置}"
            printf '  业务端口 REMOTE_PORT：%s\n' "${remote_port:-未配置}"
            printf '  systemd 实例：%s\n' "$service"
            printf '  systemd 状态：%s（开机自启：%s）\n' "${active:-unknown}" "${enabled_status:-unknown}"
            ;;
        nat-ingress)
            printf '\n%s\n' "$(c_green "入口线路已完成：${profile_id}")"
            print_box "【客户端连接】" "入口 VPS 公网 IP:$(c_cyan "${LOCAL_PORT:-LOCAL_PORT}")"
            print_box "【CNIX 面板】" \
                "入口：${CNIX_ENTRY_HOST:-CNIX_ENTRY_HOST}:${CNIX_ENTRY_PORT:-CNIX_ENTRY_PORT}" \
                "出口：${CODE_LANDING_PUBLIC_HINT:-落地 VPS 公网 IP}:${CODE_LISTENER_PORT:-LISTENER_PORT}"
            if [[ "${FORWARD_ENABLED:-true}" == "true" ]]; then
                print_box "【内部转发】" "入口机 ${LOCAL_PORT:-LOCAL_PORT} -> ${LANDING_ET_IP:-LANDING_ET_IP}:${REMOTE_PORT:-REMOTE_PORT}"
            else
                print_box "【内部转发】" "未配置，稍后可运行 bash install.sh configure-forward"
            fi
            printf '\nsystemd 实例：%s\n' "$service"
            printf 'systemd 状态：%s（开机自启：%s）\n' "${active:-unknown}" "${enabled_status:-unknown}"
            ;;
        nat-ingress)
            printf '\n%s\n' "$(c_green "公网入口线路已完成：${profile_id}")"
            print_box "【客户端连接】" "按下方转发规则中的客户端入口端口连接"
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                print_box "【连接 NAT IX】" \
                    "商家 NAT/IX 入口：${NAT_PUBLIC_HOST:-商家 NAT/IX 入口地址}:${NAT_LISTENER_PORT:-商家分配入口端口}" \
                    "协议：$(proto_display "${NAT_LISTENER_PROTO:-both}")"
            else
                print_box "【兼容旧模式监听】" \
                    "公网入口机：${INGRESS_PUBLIC_HOST:-公网入口机公网 IP}:${INGRESS_LISTENER_PORT:-入口机监听端口}" \
                    "协议：$(proto_display "${INGRESS_LISTENER_PROTO:-both}")"
            fi
            printf '\n转发规则：\n'
            format_rules_for_port_map "$profile_id"
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                printf '\n当前连接方向：NAT IX 机器监听，公网入口机连接 NAT IX。\n'
            else
                printf '\nNAT IX 机器下一步：bash install.sh add-nat-transit-profile-from-code\n'
            fi
            printf 'systemd 实例：%s\n' "$service"
            printf 'systemd 状态：%s（开机自启：%s）\n' "${active:-unknown}" "${enabled_status:-unknown}"
            ;;
        nat-transit)
            printf '\n%s\n' "$(c_green "NAT IX 中转线路已完成：${profile_id}")"
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                print_box "【商家入口】" \
                    "商家 NAT/IX 入口：${NAT_PUBLIC_HOST:-商家 NAT/IX 入口地址}:${NAT_LISTENER_PORT:-商家分配入口端口}" \
                    "协议：$(proto_display "${NAT_LISTENER_PROTO:-both}")"
                print_box "【公网入口机下一步】" "选择“公网入口机导入 NAT IX 接入码”"
            else
                print_box "【兼容旧模式】" "连接公网入口机：${INGRESS_PUBLIC_HOST:-公网入口机公网 IP}:${INGRESS_LISTENER_PORT:-入口机监听端口}"
            fi
            printf '\n转发规则：\n'
            format_rules_for_port_map "$profile_id"
            printf '说明：虚拟网中转端口只在 EasyTier 虚拟网内部使用，不需要公网放行。\n'
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                print_box "【客户端连接】" "公网入口机导入后，客户端连接公网入口机公网 IP:客户端入口端口"
            else
                print_box "【客户端连接】" "${INGRESS_PUBLIC_HOST:-公网入口 VPS}:${LOCAL_PORT:-LOCAL_PORT}"
            fi
            printf '\n注意：NAT IX 机器只做 nftables 中转，不需要安装代理服务。\n'
            printf 'systemd 实例：%s\n' "$service"
            printf 'systemd 状态：%s（开机自启：%s）\n' "${active:-unknown}" "${enabled_status:-unknown}"
            ;;
        *)
            printf '[WARN] 线路角色未知：%s\n' "${ROLE:-未设置}"
            ;;
    esac
}

print_profile_next_steps() {
    local profile_id="${1:-}" landing_public listener_port
    profile_id="$(resolve_profile_id "$profile_id")"
    load_profile_or_die "$profile_id"
    normalize_profile_compat_vars
    landing_public="${LANDING_PUBLIC_HOST:-${CODE_LANDING_PUBLIC_HINT:-落地 VPS 公网 IP}}"
    listener_port="${LISTENER_PORT:-${ET_LISTENER_PORT:-${CODE_LISTENER_PORT:-LISTENER_PORT}}}"
    case "${ROLE:-}" in
        nat-transit)
            print_next_steps "下一步：" \
                "在 CNIX 面板出口填 ${landing_public}:${listener_port}" \
                "到入口机粘贴接入码" \
                "入口机完成后客户端连接入口机公网 IP:LOCAL_PORT"
            ;;
        nat-ingress)
            print_next_steps "下一步：" \
                "在客户端填写入口 VPS 公网 IP:${LOCAL_PORT:-LOCAL_PORT}" \
                "如果不通，运行 bash install.sh health ${profile_id}" \
                "继续查看：bash install.sh doctor-all 或 bash install.sh logs-profile ${profile_id}"
            ;;
        nat-ingress)
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                print_next_steps "下一步：" \
                    "确认公网入口机已连接商家 NAT/IX 入口：${NAT_PUBLIC_HOST:-商家 NAT/IX 入口地址}:${NAT_LISTENER_PORT:-商家分配入口端口}" \
                    "运行 bash install.sh health ${profile_id}" \
                    "运行 bash install.sh list-rules ${profile_id} 查看客户端入口端口"
            else
                print_next_steps "下一步：" \
                    "把 NAT-IX 接入码复制到 NAT IX 机器" \
                    "在 NAT IX 机器运行 bash install.sh add-nat-transit-profile-from-code" \
                    "不要把接入码发到聊天记录、工单、截图或公开日志；如果已经发出，请正式使用前运行：bash install.sh refresh-nat-code ${profile_id}，或重建线路" \
                    "运行 bash install.sh list-rules ${profile_id} 查看客户端入口端口"
            fi
            ;;
        nat-transit)
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                print_next_steps "下一步：" \
                    "把 NAT-IX 接入码复制到公网入口机" \
                    "在公网入口机选择“公网入口机导入 NAT IX 接入码”" \
                    "确认落地机允许 NAT IX 机器出口 IP 访问 ${LANDING_HOST:-落地机地址}:${LANDING_PORT:-落地业务端口}" \
                    "运行 bash install.sh health ${profile_id}"
            else
                print_next_steps "下一步：" \
                    "确认落地机允许 NAT IX 机器出口 IP 访问 ${LANDING_HOST:-落地机地址}:${LANDING_PORT:-落地业务端口}" \
                    "运行 bash install.sh health ${profile_id}" \
                    "回入口机运行 bash install.sh health 公网入口线路ID，并可检查虚拟网中转 TCP" \
                    "客户端连接 ${INGRESS_PUBLIC_HOST:-公网入口 VPS}:${LOCAL_PORT:-客户端入口端口}"
            fi
            ;;
    esac
}

print_access_code_security_hint() {
    printf '%s\n' "$(c_yellow "安全提醒：接入码包含 EasyTier 组网密钥，不要发到聊天记录、工单、截图或公开日志；如果接入码已经出现在日志、截图、聊天记录或工单，请正式使用前刷新接入码。")"
}

print_nat_listener_created_summary() {
    local profile_id="$1"
    load_profile_or_die "$profile_id"
    normalize_profile_compat_vars
    printf '\n%s：%s\n\n' "$(c_green "NAT IX 中转线路已创建")" "$profile_id"
    show_code "$profile_id" || true
}

print_nat_ingress_created_summary() {
    local profile_id="$1" ingress_host
    load_profile_or_die "$profile_id"
    normalize_profile_compat_vars
    ingress_host="${INGRESS_PUBLIC_HOST:-公网入口机公网 IP}"
    printf '\n%s\n\n' "$(c_green "公网入口线路已创建")"
    cat <<EOF
客户端连接：
按下方转发规则中的客户端入口端口连接

当前线路：
* 连接 NAT IX：${NAT_PUBLIC_HOST:-商家 NAT/IX 入口地址}:${NAT_LISTENER_PORT:-商家分配入口端口}

转发规则：
$(format_rules_for_port_map "$profile_id")

nftables 转发规则：正常
查看详细 nftables 校验：
bash install.sh verify-nft-profiles
EOF
}

profile_has_code_rule_id() {
    local want="$1" line rule_id
    while IFS=$'\t' read -r rule_id _ _ _ _ _ _ _ || [[ -n "${rule_id:-}" ]]; do
        [[ "${rule_id:-}" == "$want" ]] && return 0
    done <<<"${CODE_RULES_TSV:-}"
    return 1
}

verify_nat_transit_rule_consistency() {
    local profile_id="$1" rule_id nat_port issues=() enabled_count=0 nft_text
    local saved_rule_id="${RULE_ID:-}" saved_note="${RULE_NOTE:-}" saved_enabled="${RULE_ENABLED:-}" saved_client="${CLIENT_PORT:-}" saved_nat_public="${NAT_PUBLIC_PORT:-}"
    local saved_transit="${TRANSIT_PORT:-}" saved_landing_host="${LANDING_HOST:-}" saved_landing_port="${LANDING_PORT:-}" saved_proto="${FORWARD_PROTO:-both}" saved_created="${CREATED_AT:-}" saved_updated="${UPDATED_AT:-}"

    load_profile_or_die "$profile_id"
    [[ "${ROLE:-}" == "nat-transit" && "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]] || return 0
    refresh_nat_public_endpoints_for_profile "$profile_id"
    if command_exists nft && nft list table ip "$NFT_TABLE" >/dev/null 2>&1; then
        nft_text="$(nft list table ip "$NFT_TABLE" 2>/dev/null || true)"
    elif [[ -r "$NFT_FILE" ]]; then
        nft_text="$(cat "$NFT_FILE" 2>/dev/null || true)"
    else
        nft_text=""
    fi
    for rule_id in $(profile_rule_ids "$profile_id"); do
        load_rule "$profile_id" "$rule_id" || continue
        [[ "${RULE_ENABLED:-true}" == "true" ]] || continue
        enabled_count=$((enabled_count + 1))
        nat_port="$(rule_nat_public_port_value 2>/dev/null || true)"
        [[ -n "$nat_port" ]] || issues+=("规则 ${rule_id} 缺少商家入口端口 NAT_PUBLIC_PORT")
        [[ -n "${TRANSIT_PORT:-}" ]] || issues+=("规则 ${rule_id} 缺少虚拟网中转端口 TRANSIT_PORT")
        [[ -n "${LANDING_HOST:-}" && -n "${LANDING_PORT:-}" ]] || issues+=("规则 ${rule_id} 缺少落地目标")
        if [[ -n "$nat_port" && -n "${ET_LISTENERS:-}" ]] && ! easytier_urls_contain_port "$nat_port" "${ET_LISTENERS:-}"; then
            issues+=("EasyTier listener 未包含商家入口端口 ${nat_port}（规则 ${rule_id}）")
        fi
        if [[ -n "$nat_port" && -n "${ET_MAPPED_LISTENERS:-}" ]] && ! easytier_urls_contain_port "$nat_port" "${ET_MAPPED_LISTENERS:-}"; then
            issues+=("EasyTier mapped-listener 未包含商家入口端口 ${nat_port}（规则 ${rule_id}）")
        fi
        if [[ -n "$nft_text" && -n "${TRANSIT_PORT:-}" && -n "${NAT_ET_IP:-}" ]]; then
            if ! grep -qE "(tcp|udp) dport ${TRANSIT_PORT} " <<<"$nft_text"; then
                issues+=("nftables 未找到虚拟网中转端口 ${TRANSIT_PORT}（规则 ${rule_id}）")
            fi
        fi
    done
    RULE_ID="$saved_rule_id"; RULE_NOTE="$saved_note"; RULE_ENABLED="$saved_enabled"; CLIENT_PORT="$saved_client"; NAT_PUBLIC_PORT="$saved_nat_public"
    TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"; CREATED_AT="$saved_created"; UPDATED_AT="$saved_updated"
    if [[ "$enabled_count" -eq 0 ]]; then
        return 0
    fi
    if [[ "${#issues[@]}" -gt 0 ]]; then
        log_warn "NAT IX 规则一致性检查发现问题："
        local item
        for item in "${issues[@]}"; do
            log_warn "  * ${item}"
        done
        log_warn "建议运行：bash install.sh diagnose ${profile_id}"
        return 1
    fi
    return 0
}

verify_nat_ingress_import_consistency() {
    local profile_id="$1" expected_count="${2:-0}" rule_id issues=() saved_count=0 enabled_count=0 code_enabled_count=0
    local saved_rule_id="${RULE_ID:-}" saved_note="${RULE_NOTE:-}" saved_enabled="${RULE_ENABLED:-}" saved_client="${CLIENT_PORT:-}" saved_nat_public="${NAT_PUBLIC_PORT:-}"
    local saved_transit="${TRANSIT_PORT:-}" saved_landing_host="${LANDING_HOST:-}" saved_landing_port="${LANDING_PORT:-}" saved_proto="${FORWARD_PROTO:-both}" saved_created="${CREATED_AT:-}" saved_updated="${UPDATED_AT:-}"
    local nft_text expected_rules actual_rules missing_rules nat_port dport

    load_profile_or_die "$profile_id"
    normalize_profile_compat_vars
    for rule_id in $(profile_rule_ids "$profile_id"); do
        if [[ -n "${CODE_RULES_TSV:-}" ]] && ! profile_has_code_rule_id "$rule_id"; then
            continue
        fi
        load_rule "$profile_id" "$rule_id" || continue
        saved_count=$((saved_count + 1))
        [[ "${RULE_ENABLED:-true}" == "true" ]] || continue
        enabled_count=$((enabled_count + 1))
        [[ -n "${CLIENT_PORT:-}" ]] || issues+=("规则 ${rule_id} 已保存，但缺少 CLIENT_PORT")
        nat_port="$(rule_nat_public_port_value 2>/dev/null || true)"
        [[ -n "$nat_port" ]] || issues+=("规则 ${rule_id} 已保存，但缺少 NAT_PUBLIC_PORT")
        [[ -n "${TRANSIT_PORT:-}" ]] || issues+=("规则 ${rule_id} 已保存，但缺少 TRANSIT_PORT")
        [[ -n "${LANDING_HOST:-}" ]] || issues+=("规则 ${rule_id} 已保存，但缺少 LANDING_HOST")
        [[ -n "${LANDING_PORT:-}" ]] || issues+=("规则 ${rule_id} 已保存，但缺少 LANDING_PORT")
        if [[ -n "${CLIENT_PORT:-}" ]]; then
            if command_exists nft && nft list table ip "$NFT_TABLE" >/dev/null 2>&1; then
                nft_text="$(nft list table ip "$NFT_TABLE" 2>/dev/null || true)"
            elif [[ -r "$NFT_FILE" ]]; then
                nft_text="$(cat "$NFT_FILE" 2>/dev/null || true)"
            else
                nft_text=""
            fi
            if [[ -n "$nft_text" ]] && ! grep -qE "(tcp|udp) dport ${CLIENT_PORT} " <<<"$nft_text"; then
                issues+=("规则 ${rule_id} 已保存，但 nftables 未找到客户端入口端口 ${CLIENT_PORT}")
            fi
        fi
        if [[ -n "$nat_port" ]] && ! et_peer_contains_port "$nat_port"; then
            issues+=("EasyTier peer 未包含商家入口端口 ${nat_port}")
        fi
    done
    if [[ -n "${CODE_RULES_TSV:-}" ]]; then
        while IFS=$'\t' read -r rule_id _ enabled _ _ _ _ _ || [[ -n "${rule_id:-}" ]]; do
            [[ -n "${rule_id:-}" ]] || continue
            [[ "${enabled:-true}" == "true" ]] && code_enabled_count=$((code_enabled_count + 1))
        done <<<"${CODE_RULES_TSV:-}"
    fi
    if [[ "$expected_count" -gt 0 && "$saved_count" -ne "$expected_count" ]]; then
        issues+=("实际保存规则数 ${saved_count} 与同步结果 ${expected_count} 不一致")
    elif [[ "${code_enabled_count:-0}" -gt 0 && "$enabled_count" -ne "$code_enabled_count" ]]; then
        issues+=("启用规则数 ${enabled_count} 与接入码启用规则数 ${code_enabled_count} 不一致")
    fi
    expected_rules="$(expected_forwarding_nft_rules 2>/dev/null || true)"
    if command_exists nft && nft list table ip "$NFT_TABLE" >/dev/null 2>&1; then
        actual_rules="$(nft_dnat_rules_from_text "$(nft list table ip "$NFT_TABLE" 2>/dev/null || true)")"
    elif [[ -r "$NFT_FILE" ]]; then
        actual_rules="$(nft_dnat_rules_from_text "$(cat "$NFT_FILE" 2>/dev/null || true)")"
    else
        actual_rules=""
    fi
    missing_rules="$(comm -23 <(printf '%s\n' "$expected_rules" | awk 'NF' | sort -u) <(printf '%s\n' "$actual_rules" | awk 'NF' | sort -u) 2>/dev/null || true)"
    if [[ -n "$missing_rules" ]]; then
        while IFS= read -r dport; do
            [[ -n "$dport" ]] || continue
            issues+=("nftables 缺少转发规则：${dport}")
        done <<<"$missing_rules"
    fi
    RULE_ID="$saved_rule_id"; RULE_NOTE="$saved_note"; RULE_ENABLED="$saved_enabled"; CLIENT_PORT="$saved_client"; NAT_PUBLIC_PORT="$saved_nat_public"
    TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"; CREATED_AT="$saved_created"; UPDATED_AT="$saved_updated"
    if [[ "${#issues[@]}" -gt 0 ]]; then
        printf '\n%s\n\n' "$(c_red "导入未完全成功：")"
        local item
        for item in "${issues[@]}"; do
            printf '* %s\n' "$item"
        done
        printf '\n请运行：%s\n' "$(c_cyan "bash install.sh export-diagnostic")"
        return 1
    fi
    return 0
}

print_nat_ingress_import_complete_summary() {
    local profile_id="$1" ingress_host service active_label nft_label rule_count rule_id index=0
    local saved_rule_id="${RULE_ID:-}" saved_note="${RULE_NOTE:-}" saved_enabled="${RULE_ENABLED:-}" saved_client="${CLIENT_PORT:-}" saved_nat_public="${NAT_PUBLIC_PORT:-}"
    local saved_transit="${TRANSIT_PORT:-}" saved_landing_host="${LANDING_HOST:-}" saved_landing_port="${LANDING_PORT:-}" saved_proto="${FORWARD_PROTO:-both}" saved_created="${CREATED_AT:-}" saved_updated="${UPDATED_AT:-}"
    load_profile_or_die "$profile_id"
    normalize_profile_compat_vars
    ingress_host="${INGRESS_PUBLIC_HOST:-公网入口机公网 IP}"
    service="$(profile_service_status "$(profile_service_name "$profile_id")")"
    case "$service" in
        active) active_label="运行中" ;;
        unknown) active_label="无法检查" ;;
        *) active_label="$service" ;;
    esac
    case "$(nft_profile_rule_status "$profile_id")" in
        present) nft_label="正常" ;;
        missing) nft_label="缺失，运行 bash install.sh verify-nft-profiles 查看详情" ;;
        unknown) nft_label="无法检查" ;;
        skipped) nft_label="跳过" ;;
        *) nft_label="未知" ;;
    esac
    rule_count="$(profile_rule_files_count "$profile_id")"

    if ! debug_enabled; then
        printf '\n%s：%s\n' "$(c_green "公网入口线路已完成")" "$profile_id"
        printf '规则数：%s\n' "$rule_count"
        printf 'nftables：%s\n' "$nft_label"
        printf 'EasyTier：%s\n' "$active_label"
        printf '快速检查：bash install.sh diagnose %s\n' "$profile_id"
        RULE_ID="$saved_rule_id"; RULE_NOTE="$saved_note"; RULE_ENABLED="$saved_enabled"; CLIENT_PORT="$saved_client"; NAT_PUBLIC_PORT="$saved_nat_public"
        TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"; CREATED_AT="$saved_created"; UPDATED_AT="$saved_updated"
        return 0
    fi

    printf '\n%s：%s\n\n' "$(c_green "公网入口线路已完成")" "$profile_id"
    printf '%s\n\n' "$(c_bold "客户端连接：")"
    for rule_id in $(profile_rule_ids "$profile_id"); do
        load_rule "$profile_id" "$rule_id" || continue
        [[ "${RULE_ENABLED:-true}" == "true" ]] || continue
        index=$((index + 1))
        printf '%s. [%s] %s:%s\n' "$index" "$(rule_note_display)" "$ingress_host" "$(c_cyan "${CLIENT_PORT:-公网入口端口}")"
    done
    [[ "$index" -gt 0 ]] || printf '暂无启用规则。\n'

    printf '\n%s\n\n' "$(c_bold "转发路径：")"
    index=0
    for rule_id in $(profile_rule_ids "$profile_id"); do
        load_rule "$profile_id" "$rule_id" || continue
        [[ "${RULE_ENABLED:-true}" == "true" ]] || continue
        index=$((index + 1))
        printf '%s. [%s] %s -> %s:%s -> %s:%s -> %s:%s\n' \
            "$index" "$(rule_note_display)" "${CLIENT_PORT:-公网入口端口}" "${NAT_PUBLIC_HOST:-商家 NAT/IX 入口地址}" "$(rule_nat_public_port_display)" "${NAT_ET_IP:-NAT IX 虚拟 IP}" "${TRANSIT_PORT:-虚拟网中转端口}" "${LANDING_HOST:-落地目标}" "${LANDING_PORT:-}"
    done
    [[ "$index" -gt 0 ]] || printf '暂无启用规则。\n'

    cat <<EOF

$(c_bold "状态：")

* EasyTier：${active_label}
* nftables：${nft_label}
* 规则数：${rule_count}
* 健康检查：可运行 $(c_cyan "bash install.sh health ${profile_id}")

$(c_bold "下一步：")

1. 客户端连接上方端口测试。
2. 查看流量：bash install.sh traffic-report
3. 查看详情：bash install.sh show-port-map --compact ${profile_id}
EOF
    RULE_ID="$saved_rule_id"; RULE_NOTE="$saved_note"; RULE_ENABLED="$saved_enabled"; CLIENT_PORT="$saved_client"; NAT_PUBLIC_PORT="${saved_nat_public:-}"
    TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"; CREATED_AT="$saved_created"; UPDATED_AT="$saved_updated"
    return 0
}

show_profile_summary_legacy_tail() {
    local profile_id="${1:-}" listener_port listener_proto remote_port landing_public service active enabled_status
    profile_id="$(resolve_profile_id "$profile_id")"
    load_profile_or_die "$profile_id"
    normalize_profile_compat_vars
    listener_port="${LISTENER_PORT:-${ET_LISTENER_PORT:-}}"
    listener_proto="${ET_LISTENER_PROTO:-${LISTENER_PROTOS:-}}"
    remote_port="${REMOTE_PORT:-${SERVICE_PORT:-}}"
    landing_public="${LANDING_PUBLIC_HOST:-落地 VPS 公网 IP}"
    service="$(profile_service_name "$profile_id")"
    if command_exists systemctl; then
        active="$(systemctl is-active "$service" 2>/dev/null || true)"
        enabled_status="$(systemctl is-enabled "$service" 2>/dev/null || true)"
    else
        active="unknown"
        enabled_status="unknown"
    fi
    case "${ROLE:-}" in
        nat-transit)
            printf '\nCNIX 面板出口填写：\n'
            printf '  出口 IP：%s\n' "$landing_public"
            printf '  出口端口：%s\n' "${listener_port:-LISTENER_PORT}"
            printf '  出口协议：%s\n' "$(proto_display "$listener_proto")"
            printf '\n注意：\n'
            printf '  %s 是 EasyTier listener / WG ListenPort 等价端口。\n' "${listener_port:-LISTENER_PORT}"
            printf '  %s 是落地业务服务端口，不要填到 CNIX 面板出口。\n' "${remote_port:-REMOTE_PORT}"
            printf '\n下一步：\n'
            printf '  1. 在 CNIX 面板出口填：%s:%s\n' "$landing_public" "${listener_port:-LISTENER_PORT}"
            printf '  2. 复制下面接入码到公网入口机。\n'
            printf '  3. 入口机选择“新增入口线路 / 粘贴接入码”。\n'
            ;;
        nat-ingress)
            printf '客户端连接：\n'
            printf '  公网入口 VPS:%s\n' "${LOCAL_PORT:-LOCAL_PORT}"
            printf '\nCNIX 商家入口：\n'
            printf '  %s:%s\n' "${CNIX_ENTRY_HOST:-CNIX_ENTRY_HOST}" "${CNIX_ENTRY_PORT:-CNIX_ENTRY_PORT}"
            printf '\nCNIX 面板出口应为：\n'
            printf '  %s:%s\n' "${CODE_LANDING_PUBLIC_HINT:-落地公网 IP}" "${CODE_LISTENER_PORT:-LISTENER_PORT}"
            printf '\n入口机 nftables 转发目标：\n'
            if [[ "${FORWARD_ENABLED:-true}" == "true" ]]; then
                printf '  %s:%s\n' "${LANDING_ET_IP:-LANDING_ET_IP}" "${REMOTE_PORT:-REMOTE_PORT}"
            else
                printf '  未配置，稍后可运行 bash install.sh configure-forward\n'
            fi
            printf '\nsystemd 实例：%s\n' "$service"
            printf 'systemd 状态：%s（开机自启：%s）\n' "${active:-unknown}" "${enabled_status:-unknown}"
            printf '\n下一步：\n'
            printf '  bash install.sh health %s\n' "$profile_id"
            printf '  bash install.sh verify-nft-profiles\n'
            printf '  bash install.sh show-port-map %s\n' "$profile_id"
            ;;
        *)
            printf '[WARN] Profile 角色未知：%s\n' "${ROLE:-未设置}"
            ;;
    esac
}

show_config() {
    require_root "$@"
    local profile_id="${1:-}" count
    count="$(profile_count)"
    if [[ -n "$profile_id" || "$count" != "0" ]]; then
        if ! profile_id="$(resolve_profile_id_for_cmd "$profile_id" show-config)"; then
            return_or_exit 2 || return $?
        fi
        if ! load_profile "$profile_id"; then
            print_profile_selection_hint "$profile_id" show-config
            return_or_exit 2 || return $?
        fi
        print_config_summary loaded || die_user "没有可显示的已保存配置。"
        return 0
    fi
    if [[ ! -f "$ENV_FILE" ]]; then
        printf '[ERROR] 当前没有线路，请先创建 NAT IX 中转线路或导入接入码。\n' >&2
        return_or_exit 2 || return $?
    fi
    print_config_summary || die_user "没有可显示的已保存配置。"
    return 0
}

nat_guide_profile() {
    local profile_id="${1:-}"
    if ! profile_id="$(resolve_profile_id_for_cmd "$profile_id" nat-guide)"; then
        return_or_exit 2 || return $?
    fi
    if ! load_profile "$profile_id"; then
        print_profile_selection_hint "$profile_id" nat-guide
        return_or_exit 2 || return $?
    fi
    normalize_profile_compat_vars
    case "${ROLE:-}" in
        nat-ingress)
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                cat <<EOF
当前 Profile：${profile_id}（公网入口线路，连接 NAT IX）

公网入口机：
- 商家 NAT/IX 入口：${NAT_PUBLIC_HOST:-NAT_PUBLIC_HOST}:${NAT_LISTENER_PORT:-NAT_LISTENER_PORT}
- 入口机 ET IP：${INGRESS_ET_IP:-INGRESS_ET_IP}
- NAT IX ET IP：${NAT_ET_IP:-NAT_ET_IP}
- nftables 转发：LOCAL_PORT ${LOCAL_PORT:-LOCAL_PORT} -> ${NAT_ET_IP:-NAT_ET_IP}:${TRANSIT_PORT:-TRANSIT_PORT}

NAT IX 机器：
- 商家 NAT/IX 入口：${NAT_PUBLIC_HOST:-NAT_PUBLIC_HOST}:${NAT_LISTENER_PORT:-NAT_LISTENER_PORT}
- nftables 转发：${NAT_ET_IP:-NAT_ET_IP}:${TRANSIT_PORT:-TRANSIT_PORT} -> ${LANDING_HOST:-LANDING_HOST}:${LANDING_PORT:-LANDING_PORT}

客户端：
- 连接 ${INGRESS_PUBLIC_HOST:-公网入口 VPS}:${LOCAL_PORT:-LOCAL_PORT}
EOF
            else
                cat <<EOF
当前 Profile：${profile_id}（NAT-IX 入口）

公网入口机：
- EasyTier listener：${INGRESS_PUBLIC_HOST:-INGRESS_PUBLIC_HOST}:${INGRESS_LISTENER_PORT:-INGRESS_LISTENER_PORT}
- 入口机 ET IP：${INGRESS_ET_IP:-INGRESS_ET_IP}
- NAT IX ET IP：${NAT_ET_IP:-NAT_ET_IP}
- nftables 转发：LOCAL_PORT ${LOCAL_PORT:-LOCAL_PORT} -> ${NAT_ET_IP:-NAT_ET_IP}:${TRANSIT_PORT:-TRANSIT_PORT}

NAT IX 机器：
- 运行 bash install.sh add-nat-transit-profile-from-code
- 粘贴 show-code ${profile_id} 输出的 NAT-IX 接入码。

客户端：
- 连接 ${INGRESS_PUBLIC_HOST:-公网入口 VPS}:${LOCAL_PORT:-LOCAL_PORT}
EOF
            fi
            ;;
        nat-transit)
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                cat <<EOF
当前 Profile：${profile_id}（NAT IX 中转线路）

NAT IX 机器：
- 商家 NAT/IX 入口：${NAT_PUBLIC_HOST:-NAT_PUBLIC_HOST}:${NAT_LISTENER_PORT:-NAT_LISTENER_PORT}
- NAT IX ET IP：${NAT_ET_IP:-NAT_ET_IP}
- 入口机 ET IP：${INGRESS_ET_IP:-INGRESS_ET_IP}
- nftables 转发：${NAT_ET_IP:-NAT_ET_IP}:${TRANSIT_PORT:-TRANSIT_PORT} -> ${LANDING_HOST:-LANDING_HOST}:${LANDING_PORT:-LANDING_PORT}

公网入口机：
- 运行 bash install.sh add-nat-ingress-from-listener-code
- 粘贴 show-code ${profile_id} 输出的 NAT-IX 接入码。

落地机：
- 不需要安装本项目。
- 确保 ${LANDING_HOST:-LANDING_HOST}:${LANDING_PORT:-LANDING_PORT} 可被 NAT IX 机器访问。

客户端：
- 公网入口机导入后，连接入口机公网 IP:LOCAL_PORT
EOF
            else
                cat <<EOF
当前 Profile：${profile_id}（NAT-IX 中转）

NAT IX 机器：
- EasyTier peer：${INGRESS_PUBLIC_HOST:-INGRESS_PUBLIC_HOST}:${INGRESS_LISTENER_PORT:-INGRESS_LISTENER_PORT}
- 中转接收：${NAT_ET_IP:-NAT_ET_IP}:${TRANSIT_PORT:-TRANSIT_PORT}
- nftables 转发：${NAT_ET_IP:-NAT_ET_IP}:${TRANSIT_PORT:-TRANSIT_PORT} -> ${LANDING_HOST:-LANDING_HOST}:${LANDING_PORT:-LANDING_PORT}

落地机：
- 不需要安装本项目。
- 确保 ${LANDING_HOST:-LANDING_HOST}:${LANDING_PORT:-LANDING_PORT} 可被 NAT IX 机器访问。
- 如果只允许特定来源访问，请允许 NAT IX 机器出口 IP。

客户端：
- 连接 ${INGRESS_PUBLIC_HOST:-公网入口 VPS}:${LOCAL_PORT:-LOCAL_PORT}
EOF
            fi
            ;;
        *)
            printf '[WARN] 当前 Profile 不是 NAT-IX 角色：%s\n' "${ROLE:-未设置}"
            ;;
    esac
}

nat_guide_cmd() {
    require_root "$@"
    case "${1:-}" in
        --all)
            local id
            for id in $(profile_ids); do
                printf '\n===== 线路 %s =====\n' "$id"
                nat_guide_profile "$id"
            done
            ;;
        *)
            nat_guide_profile "${1:-}"
            ;;
    esac
}

show_easytier_command() {
    local profile_id="${1:-}" resolved
    if [[ -n "$profile_id" || -d "$PROFILES_DIR" ]]; then
        if ! resolved="$(resolve_profile_id_for_cmd "$profile_id" show-easytier-command)"; then
            return_or_exit 2 || return $?
        fi
        if ! load_profile "$resolved"; then
            print_profile_selection_hint "$resolved" show-easytier-command
            return_or_exit 2 || return $?
        fi
    else
        load_env_or_warn || return 0
    fi
    printf 'EasyTier 启动命令（已脱敏，不执行）：\n'
    render_easytier_args
    printf 'role: %s\n' "${ROLE:-unknown}"
    printf 'profile: %s\n' "${PROFILE_ID:-default}"
    if profile_uses_easytier_listener; then
        print_easytier_listeners
    elif [[ "${ROLE:-}" == "nat-ingress" || "${ROLE:-}" == "nat-ingress" || "${ROLE:-}" == "nat-transit" ]]; then
        print_easytier_peers
    fi
}

status_brief() {
    status_easytier
    if [[ "${ROLE:-}" == "nat-ingress" || "${ROLE:-}" == "nat-ingress" || "${ROLE:-}" == "nat-transit" ]]; then
        if [[ "${FORWARD_ENABLED:-true}" == "true" ]]; then
            status_nft
            if command_exists sysctl; then
                printf 'IPv4 转发：%s\n' "$(sysctl -n net.ipv4.ip_forward 2>/dev/null || printf '未知')"
            fi
        else
            printf '业务转发：未配置\n'
        fi
    fi
}

post_install_summary() {
    local role="$1" listener_state listener_note listener_port listener_proto
    normalize_profile_compat_vars
    listener_port="${LISTENER_PORT:-${ET_LISTENER_PORT:-}}"
    listener_proto="${ET_LISTENER_PROTO:-${LISTENER_PROTOS:-}}"
    printf '\n配置摘要：\n'
    print_config_summary loaded || true
    printf '\nNAT IX 填写指引：\n'
    nat_guide || true
    printf '\n简短状态：\n'
    status_brief || true

    if [[ "$ROLE" == "nat-transit" ]]; then
        listener_note="如 listener 未监听，请先运行 bash install.sh logs 或 bash install.sh doctor。"
        if command_exists ss && check_listener_present >/dev/null 2>&1; then
            listener_note="EasyTier listener 已检测到监听，即使 systemd 暂时显示 activating，也可以继续填写 CNIX 面板；随后运行 logs 确认。"
        fi
        cat <<EOF

【CNIX 面板出口填写】
出口 IP：落地 VPS 公网 IP
出口端口：$(c_cyan "${listener_port:-LISTENER_PORT}")
出口协议：$(proto_display "$listener_proto")

重要：
这个端口是 EasyTier listener，等价于 WG ListenPort。
不要填写 Remnawave / VLESS / Xray / sing-box 的业务端口。
EOF
        if [[ -n "${SERVICE_PORT:-}" ]]; then
            cat <<EOF

【业务端口】
REMOTE_PORT：$(c_cyan "$SERVICE_PORT")
这是落地机业务服务端口，只在 EasyTier 虚拟网内访问。
它不是 CNIX 面板出口端口。
EOF
        fi
        cat <<EOF

下一步：
  1. 在 CNIX 面板出口填写上面的 EasyTier listener 端口。
  2. 复制接入码到入口机。
  3. 入口机选择“粘贴接入码组网”。

${listener_note}
EOF
    else
        if [[ "${FORWARD_ENABLED:-true}" == "true" ]]; then
            cat <<EOF

【客户端填写】
地址：入口 VPS 公网 IP
端口：$(c_cyan "${LOCAL_PORT:-LOCAL_PORT}")

【CNIX 面板入口】
$(c_cyan "${CNIX_ENTRY_HOST}:${CNIX_ENTRY_PORT}")

【CNIX 面板出口】
落地 VPS 公网 IP:$(c_cyan "${CODE_LISTENER_PORT:-LISTENER_PORT}")

【入口机 nftables 转发目标】
$(c_cyan "${LANDING_ET_IP}:${REMOTE_PORT}")

下一步：
  1. 确认 CNIX 面板入口 IP / 端口 / 协议正确。
  2. 入口 VPS 安全组放行 LOCAL_PORT。
  3. 运行：bash install.sh doctor
  4. 运行：bash install.sh self-test
  5. 客户端连接：入口 VPS 公网 IP:${LOCAL_PORT}
EOF
        else
            cat <<EOF

下一步：
  1. 先运行：bash install.sh doctor，确认 EasyTier 互通。
  2. 再运行：bash install.sh configure-forward，配置业务转发。
EOF
        fi
    fi
}

collect_profile_identity() {
    local role_prefix="$1" default_id
    default_id="$(generate_profile_id "$role_prefix")"
    PROFILE_ID="$(prompt_validated "请输入线路 ID" "$default_id" validate_profile_id "线路 ID 只能包含小写字母、数字、短横线，长度 3-32。")" || return 1
    if [[ -f "$(profile_env_path "$PROFILE_ID")" ]]; then
        die_user "线路已存在：${PROFILE_ID}"
    fi
    PROFILE_NAME="$(prompt_required "请输入线路名称" "$PROFILE_ID")" || return 1
    ENABLED="true"
}

add_nat_ingress_profile() {
    require_root "$@"
    run_profile_install_preflight nat-ingress
    require_tty add-nat-ingress-profile
    ensure_profile_dirs
    collect_profile_identity "nat-ingress" || return 1
    collect_nat_ingress_inputs || return 1
    PROFILE_ID="${PROFILE_ID}"
    PROFILE_NAME="${PROFILE_NAME:-$PROFILE_ID}"
    ENABLED="true"
    validate_profile_config "$PROFILE_ID"
    check_profile_conflicts "$PROFILE_ID"
    ensure_systemctl
    ensure_listener_port_available_before_start
    enable_ip_forward
    save_profile_env "$PROFILE_ID"
    save_profile_code_file "$PROFILE_ID" "$(generate_nat_code)"
    render_profile_service_files
    apply_nft_all
    start_profile "$PROFILE_ID"
    show_profile_summary "$PROFILE_ID"
    show_code_skip_security="true"
    show_code "$PROFILE_ID" || true
    show_code_skip_security=""
    print_access_code_security_hint
    printf '\n端口映射：\n'
    show_port_map "$PROFILE_ID" --compact || true
    printf '\n健康检查摘要：\n'
    run_line_health_check "$PROFILE_ID" false || true
    printf '\nnftables：\n'
    print_normal_nft_forwarding_summary || true
    print_nat_ix_troubleshooting_hint "$PROFILE_ID"
    print_profile_next_steps "$PROFILE_ID"
}

add_nat_listener_profile() {
    require_root "$@"
    run_profile_install_preflight nat-transit
    require_tty add-nat-listener-profile
    ensure_profile_dirs
    confirm_recommended_nat_listener_role || return 0
    collect_nat_listener_inputs || return 1
    PROFILE_NAME="${PROFILE_NAME:-$PROFILE_ID}"
    ENABLED="true"
    validate_profile_config "$PROFILE_ID"
    check_profile_conflicts "$PROFILE_ID"
    ensure_systemctl
    ensure_listener_port_available_before_start
    enable_ip_forward
    save_profile_env "$PROFILE_ID"
    save_profile_code_file "$PROFILE_ID" "$(generate_nat_code)"
    render_profile_service_files
    apply_nft_all
    start_profile "$PROFILE_ID"
    print_nat_listener_created_summary "$PROFILE_ID"
}

add_nat_transit_profile_from_code() {
    local profile_id code landing_host landing_port_default
    require_root "$@"
    run_profile_install_preflight nat-transit
    require_tty add-nat-transit-profile-from-code
    ensure_profile_dirs
    collect_profile_identity "nat-transit" || return 1
    profile_id="$PROFILE_ID"
    code="$(read_nat_code_from_args_or_prompt)" || die_user "未读取到 NAT-IX 接入码。"
    parse_nat_code "$code"
    [[ "${CODE_NAT_DIRECTION:-ingress-listener}" == "ingress-listener" ]] || die_user "这是推荐模式的接入码，应在“公网入口机导入 NAT IX 接入码”中使用。"

    ROLE="nat-transit"
    NAT_DIRECTION="ingress-listener"
    PROFILE_ID="$profile_id"
    PROFILE_NAME="${PROFILE_NAME:-$profile_id}"
    ENABLED="true"
    ET_NETWORK_NAME="$CODE_NETWORK_NAME"
    ET_NETWORK_SECRET="$CODE_NETWORK_SECRET"
    ET_HOSTNAME="$(prompt_validated "请输入当前节点名称" "ix-nat-transit-${PROFILE_ID}" validate_hostname_value "请输入 1-64 个字符，仅允许字母、数字、点、下划线或短横线。")" || return 1
    ET_IPV4="$CODE_NAT_ET_CIDR"
    ET_SUBNET="$(cidr_network24 "$ET_IPV4")"
    INGRESS_HOSTNAME="$CODE_INGRESS_HOSTNAME"
    INGRESS_PUBLIC_HOST="$CODE_INGRESS_PUBLIC_HOST"
    INGRESS_ET_IP="$CODE_INGRESS_ET_IP"
    INGRESS_ET_CIDR="$CODE_INGRESS_ET_CIDR"
    INGRESS_LISTENER_PROTO="$CODE_INGRESS_LISTENER_PROTO"
    INGRESS_LISTENER_PROTOS="$CODE_INGRESS_LISTENER_PROTOS"
    INGRESS_LISTENER_PORT="$CODE_INGRESS_LISTENER_PORT"
    NAT_ET_IP="$CODE_NAT_ET_IP"
    NAT_ET_CIDR="$CODE_NAT_ET_CIDR"
    LOCAL_PORT="$CODE_LOCAL_PORT"
    TRANSIT_PORT="$CODE_TRANSIT_PORT"
    landing_host="$(prompt_validated "请输入落地机公网 IP 或域名 LANDING_HOST，例如 landing.example" "" validate_host "请输入 IPv4 或域名。")" || return 1
    LANDING_HOST="$landing_host"
    landing_port_default="50000"
    LANDING_PORT="$(prompt_port "请输入落地机业务端口 LANDING_PORT" "$landing_port_default")" || return 1
    FORWARD_PROTO="$(prompt_forward_proto "请选择业务转发协议（tcp / udp / both / tcp/udp）" "${CODE_FORWARD_PROTO:-both}")" || return 1
    if validate_ipv4 "$LANDING_HOST"; then
        LANDING_IP="$LANDING_HOST"
    else
        LANDING_IP=""
    fi
    ET_PEERS="$(peer_urls_value "$INGRESS_LISTENER_PROTO" "$INGRESS_PUBLIC_HOST" "$INGRESS_LISTENER_PORT")"
    ET_NO_LISTENER="true"
    ET_PRIVATE_MODE="true"
    ET_EXPLICIT_ONLY="true"
    IXTF_EXPLICIT_ONLY="true"
    FORWARD_ENABLED="true"

    validate_profile_config "$PROFILE_ID"
    check_profile_conflicts "$PROFILE_ID"
    ensure_systemctl
    enable_ip_forward
    save_profile_env "$PROFILE_ID"
    render_profile_service_files
    apply_nft_all
    start_profile "$PROFILE_ID"
    print_nat_ingress_created_summary "$PROFILE_ID"
}

suggest_rule_client_port_for_import() (
    local profile_id="$1" rule_id="$2" landing_port="${3:-}" existing
    if load_rule "$profile_id" "$rule_id" >/dev/null 2>&1 && [[ -n "${CLIENT_PORT:-}" ]]; then
        printf '%s\n' "$CLIENT_PORT"
        return 0
    fi
    if validate_port "$landing_port" && ! profile_uses_rule_port_for_conflict "$profile_id" client "$landing_port" "$rule_id"; then
        printf '%s\n' "$landing_port"
        return 0
    fi
    existing="$(pick_random_rule_port "$profile_id" client "$rule_id" || true)"
    [[ -n "$existing" ]] || return 1
    printf '%s\n' "$existing"
)

print_code_rules_import_summary() {
    local profile_id="${1:-${PROFILE_ID:-}}" line rule_id note enabled nat_public_port transit_port landing_host landing_port forward_proto index=0 suggested
    printf '\n%s\n\n' "$(c_bold "接入码包含 ${CODE_RULE_COUNT:-0} 条转发规则：")"
    while IFS=$'\t' read -r -u 3 rule_id note enabled nat_public_port transit_port landing_host landing_port forward_proto || [[ -n "${rule_id:-}" ]]; do
        [[ -n "${rule_id:-}" ]] || continue
        index=$((index + 1))
        suggested="$(suggest_rule_client_port_for_import "$profile_id" "$rule_id" "$landing_port" || true)"
        printf '%s. %s  %s  [%s]\n' "$index" "$rule_id" "$(enabled_label_zh "${enabled:-true}")" "$(rule_note_display "$note")"
        printf '   商家入口端口：%s\n' "$nat_public_port"
        printf '   虚拟网中转端口：%s\n' "$transit_port"
        printf '   落地目标：%s:%s\n' "$landing_host" "$landing_port"
        printf '   完整路径：公网入口机:%s -> %s:%s -> %s:%s -> %s:%s\n' "${suggested:-客户端入口端口}" "${CODE_NAT_PUBLIC_HOST:-商家 NAT/IX 入口地址}" "$nat_public_port" "${CODE_NAT_ET_IP:-NAT IX 虚拟 IP}" "$transit_port" "$landing_host" "$landing_port"
        printf '   建议公网入口端口：%s\n\n' "${suggested:-需手动输入}"
    done 3<<<"${CODE_RULES_TSV:-}"
}

prompt_rule_client_port_for_import() {
    local profile_id="$1" rule_id="$2" note="$3" default_port="${4:-}" landing_host="${5:-}" landing_port="${6:-}" value owner
    while true; do
        printf '\n规则 %s [%s]\n' "$rule_id" "$(rule_note_display "$note")" >&2
        [[ -n "$landing_host" || -n "$landing_port" ]] && printf '落地目标：%s:%s\n' "${landing_host:-落地目标}" "${landing_port:-}" >&2
        if [[ -n "$default_port" ]]; then
            printf '建议公网入口端口：%s\n' "$default_port" >&2
            printf '请输入公网入口端口，直接回车使用 %s（回车即可确认）：' "$default_port" >&2
        else
            printf '请输入公网入口端口（回车随机）：' >&2
        fi
        IFS= read -r value || return 1
        value="$(trim_space "${value%$'\r'}")"
        if [[ -z "$value" ]]; then
            if [[ -n "$default_port" ]]; then
                value="$default_port"
            else
                value="$(pick_random_rule_port "$profile_id" client "$rule_id" || true)"
                [[ -n "$value" ]] || die_user "无法分配未占用的客户端入口端口。"
                printf '已随机分配客户端入口端口：%s\n' "$value" >&2
            fi
        fi
        if ! validate_port "$value"; then
            log_warn "客户端入口端口必须是 1-65535。"
            continue
        fi
        if profile_uses_rule_port_for_conflict "$profile_id" client "$value" "$rule_id"; then
            owner="$(format_rule_port_conflict_owner "$profile_id" client "$value" "$rule_id" 2>/dev/null || true)"
            if [[ -n "$owner" ]]; then
                log_warn "端口 ${value} 已被${owner} 使用。"
            else
                log_warn "端口 ${value} 已被其他规则使用。"
            fi
            continue
        fi
        printf '%s\n' "$value"
        return 0
    done
}

sync_nat_listener_code_rules_to_ingress_profile() {
    local profile_id="$1" line rule_id note enabled nat_public_port transit_port landing_host landing_port forward_proto
    local default_client client_port first="true" remote_ids=" " existing answer local_exists="false"
    local first_client="" first_transit="" first_landing_host="" first_landing_port="" first_proto=""
    local first_rule_id="" added=0 updated=0 disabled=0 kept=0 failed=0 saved_code_count=0 saved_enabled_count=0 missing_rules=""
    local added_ids="" updated_ids=""
    validate_profile_id "$profile_id" || die_user "PROFILE_ID 格式不正确：${profile_id}"
    print_code_rules_import_summary "$profile_id"
    while IFS=$'\t' read -r -u 3 rule_id note enabled nat_public_port transit_port landing_host landing_port forward_proto || [[ -n "${rule_id:-}" ]]; do
        [[ -n "${rule_id:-}" ]] || continue
        remote_ids="${remote_ids}${rule_id} "
        default_client="$(suggest_rule_client_port_for_import "$profile_id" "$rule_id" "$landing_port" || true)"
        local_exists="false"
        if [[ -f "$(rule_env_path "$profile_id" "$rule_id" 2>/dev/null || printf /nonexistent)" ]]; then
            local_exists="true"
        fi
        if [[ "${enabled:-true}" == "true" ]]; then
            client_port="$(prompt_rule_client_port_for_import "$profile_id" "$rule_id" "$note" "$default_client" "$landing_host" "$landing_port")" || return 1
        else
            client_port="$default_client"
            printf '规则 %s [%s] 已在接入码中标记为停止，本地同步为停止。\n' "$rule_id" "$(rule_note_display "$note")" >&2
        fi
        RULE_ID="$rule_id"
        RULE_NOTE="${note:-}"
        RULE_ENABLED="${enabled:-true}"
        CLIENT_PORT="$client_port"
        NAT_PUBLIC_PORT="$nat_public_port"
        TRANSIT_PORT="$transit_port"
        LANDING_HOST="$landing_host"
        LANDING_PORT="$landing_port"
        FORWARD_PROTO="${forward_proto:-both}"
        if ! save_rule_env "$profile_id" "$rule_id"; then
            failed=$((failed + 1))
            die_user "规则 ${rule_id} 写入失败。"
        fi
        if [[ "${enabled:-true}" == "true" ]]; then
            if [[ "$local_exists" == "true" ]]; then
                updated=$((updated + 1))
                updated_ids="${updated_ids}${updated_ids:+ }${rule_id}"
            else
                added=$((added + 1))
                added_ids="${added_ids}${added_ids:+ }${rule_id}"
            fi
        else
            disabled=$((disabled + 1))
        fi
        if [[ "$first" == "true" ]]; then
            first_rule_id="$rule_id"
            first_client="$client_port"
            first_transit="$transit_port"
            first_landing_host="$landing_host"
            first_landing_port="$landing_port"
            first_proto="${forward_proto:-both}"
            first="false"
        fi
    done 3<<<"${CODE_RULES_TSV:-}"

    for existing in $(profile_rule_ids "$profile_id"); do
        [[ "$remote_ids" == *" ${existing} "* ]] && continue
        [[ -f "$(rule_env_path "$profile_id" "$existing" 2>/dev/null || printf /nonexistent)" ]] || continue
        printf '本地规则 %s 已不在 NAT IX 接入码中。\n' "$existing" >&2
        answer="$(prompt_yes_no "是否停用本地规则" "true")" || answer="true"
        if [[ "$answer" == "true" ]]; then
            load_rule "$profile_id" "$existing" || continue
            RULE_ENABLED="false"
            if ! save_rule_env "$profile_id" "$existing"; then
                failed=$((failed + 1))
                die_user "规则 ${existing} 停用写入失败。"
            fi
            disabled=$((disabled + 1))
        else
            kept=$((kept + 1))
        fi
    done

    while IFS=$'\t' read -r -u 3 rule_id note enabled nat_public_port transit_port landing_host landing_port forward_proto || [[ -n "${rule_id:-}" ]]; do
        [[ -n "${rule_id:-}" ]] || continue
        if [[ -f "$(rule_env_path "$profile_id" "$rule_id" 2>/dev/null || printf /nonexistent)" ]]; then
            saved_code_count=$((saved_code_count + 1))
            if load_rule "$profile_id" "$rule_id" >/dev/null 2>&1 && [[ "${RULE_ENABLED:-true}" == "true" ]]; then
                saved_enabled_count=$((saved_enabled_count + 1))
            fi
        else
            missing_rules="${missing_rules}${missing_rules:+ }${rule_id}"
        fi
    done 3<<<"${CODE_RULES_TSV:-}"
    [[ -z "$missing_rules" ]] || die_user "规则写入失败：${missing_rules}"

    if [[ -n "$first_rule_id" ]] && load_rule "$profile_id" "$first_rule_id" >/dev/null 2>&1; then
        LOCAL_PORT="${CLIENT_PORT:-$first_client}"
        TRANSIT_PORT="${TRANSIT_PORT:-$first_transit}"
        LANDING_HOST="${LANDING_HOST:-$first_landing_host}"
        LANDING_PORT="${LANDING_PORT:-$first_landing_port}"
        FORWARD_PROTO="${FORWARD_PROTO:-$first_proto}"
    else
        LOCAL_PORT="$first_client"
        TRANSIT_PORT="$first_transit"
        LANDING_HOST="$first_landing_host"
        LANDING_PORT="$first_landing_port"
        FORWARD_PROTO="$first_proto"
    fi
    printf '\n同步结果：\n\n'
    printf '* 新增规则：%s\n' "$added"
    printf '* 更新规则：%s\n' "$updated"
    printf '* 停用规则：%s\n' "$disabled"
    printf '* 保留规则：%s\n' "$kept"
    printf '* 失败规则：%s\n' "$failed"
    printf '* 实际保存规则：%s\n' "$saved_code_count"
    printf '* 启用规则数：%s\n' "$saved_enabled_count"
    [[ -n "$added_ids" ]] && printf '* 新增规则 ID：%s\n' "$added_ids"
    [[ -n "$updated_ids" ]] && printf '* 更新规则 ID：%s\n' "$updated_ids"
    IXTF_LAST_SYNC_SAVED_RULE_COUNT="$saved_code_count"
}

find_existing_nat_ingress_profile_for_code() (
    local id code_subnet profile_subnet
    code_subnet="$(cidr_network24 "${CODE_INGRESS_ET_CIDR:-}" 2>/dev/null || true)"
    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        [[ "${ROLE:-}" == "nat-ingress" && "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]] || continue
        if [[ -n "${CODE_PROFILE_ID:-}" && "${REMOTE_NAT_PROFILE_ID:-}" == "$CODE_PROFILE_ID" ]]; then
            printf '%s\n' "$id"
            return 0
        fi
        profile_subnet="${ET_SUBNET:-$(cidr_network24 "${ET_IPV4:-}" 2>/dev/null || true)}"
        if [[ -n "$code_subnet" && "$profile_subnet" == "$code_subnet" && "${ET_NETWORK_NAME:-}" == "${CODE_NETWORK_NAME:-}" ]]; then
            printf '%s\n' "$id"
            return 0
        fi
        if [[ -n "${CODE_NAT_PUBLIC_HOST:-}" && "${NAT_PUBLIC_HOST:-}" == "$CODE_NAT_PUBLIC_HOST" && "${ET_NETWORK_SECRET:-}" == "${CODE_NETWORK_SECRET:-}" ]]; then
            printf '%s\n' "$id"
            return 0
        fi
    done
    return 1
)

add_nat_ingress_from_listener_code() {
    local profile_id code detected_public env_public advanced existing_profile_id first_rule_id first_note first_enabled first_nat_public first_transit first_landing_host first_landing_port first_proto
    local code_network_name code_network_secret code_profile_id code_profile_name code_ingress_et_ip code_ingress_et_cidr
    local code_nat_public_host code_nat_public_ports code_nat_public_port_mode code_nat_listener_proto code_nat_listener_protos code_nat_listener_port
    local code_nat_et_ip code_nat_et_cidr code_transit_port code_landing_host code_landing_port code_forward_proto code_rules_tsv code_rules_b64 code_rule_count code_code_schema
    require_root "$@"
    run_profile_install_preflight nat-ingress
    require_tty add-nat-ingress-from-listener-code
    ensure_profile_dirs
    confirm_recommended_ingress_import_role || return 0
    code="$(read_nat_code_from_args_or_prompt)" || die_user "未读取到 NAT-IX 推荐模式接入码。"
    parse_nat_code "$code"
    [[ "${CODE_NAT_DIRECTION:-}" == "nat-listener" ]] || die_user "这是旧模式接入码，请选择兼容旧模式导入，或重新在 NAT IX 机器生成推荐模式接入码。"
    code_network_name="$CODE_NETWORK_NAME"
    code_network_secret="$CODE_NETWORK_SECRET"
    code_profile_id="$CODE_PROFILE_ID"
    code_profile_name="$CODE_PROFILE_NAME"
    code_ingress_et_ip="$CODE_INGRESS_ET_IP"
    code_ingress_et_cidr="$CODE_INGRESS_ET_CIDR"
    code_nat_public_host="$CODE_NAT_PUBLIC_HOST"
    code_nat_public_ports="$CODE_NAT_PUBLIC_PORTS"
    code_nat_public_port_mode="$CODE_NAT_PUBLIC_PORT_MODE"
    code_nat_listener_proto="$CODE_NAT_LISTENER_PROTO"
    code_nat_listener_protos="$CODE_NAT_LISTENER_PROTOS"
    code_nat_listener_port="$CODE_NAT_LISTENER_PORT"
    code_nat_et_ip="$CODE_NAT_ET_IP"
    code_nat_et_cidr="$CODE_NAT_ET_CIDR"
    code_transit_port="$CODE_TRANSIT_PORT"
    code_landing_host="$CODE_LANDING_HOST"
    code_landing_port="$CODE_LANDING_PORT"
    code_forward_proto="$CODE_FORWARD_PROTO"
    code_rules_tsv="$CODE_RULES_TSV"
    code_rules_b64="$CODE_RULES_B64"
    code_rule_count="$CODE_RULE_COUNT"
    code_code_schema="$CODE_CODE_SCHEMA"
    existing_profile_id="$(find_existing_nat_ingress_profile_for_code 2>/dev/null || true)"
    if [[ -n "$existing_profile_id" ]]; then
        load_profile_or_die "$existing_profile_id"
        profile_id="$existing_profile_id"
        PROFILE_ID="$profile_id"
        PROFILE_NAME="${PROFILE_NAME:-$profile_id}"
        ET_HOSTNAME="${ET_HOSTNAME:-ix-nat-ingress-${profile_id}}"
        FORWARD_PROTO="${code_forward_proto:-${FORWARD_PROTO:-both}}"
        printf '检测到已有公网入口线路：%s，将更新该线路的转发规则。\n' "$profile_id" >&2
    else
        advanced="$(prompt_yes_no "是否自定义高级参数" "false")" || return 1
    fi
    CODE_NETWORK_NAME="$code_network_name"
    CODE_NETWORK_SECRET="$code_network_secret"
    CODE_PROFILE_ID="$code_profile_id"
    CODE_PROFILE_NAME="$code_profile_name"
    CODE_INGRESS_ET_IP="$code_ingress_et_ip"
    CODE_INGRESS_ET_CIDR="$code_ingress_et_cidr"
    CODE_NAT_PUBLIC_HOST="$code_nat_public_host"
    CODE_NAT_PUBLIC_PORTS="$code_nat_public_ports"
    CODE_NAT_PUBLIC_PORT_MODE="$code_nat_public_port_mode"
    CODE_NAT_LISTENER_PROTO="$code_nat_listener_proto"
    CODE_NAT_LISTENER_PROTOS="$code_nat_listener_protos"
    CODE_NAT_LISTENER_PORT="$code_nat_listener_port"
    CODE_NAT_ET_IP="$code_nat_et_ip"
    CODE_NAT_ET_CIDR="$code_nat_et_cidr"
    CODE_TRANSIT_PORT="$code_transit_port"
    CODE_LANDING_HOST="$code_landing_host"
    CODE_LANDING_PORT="$code_landing_port"
    CODE_FORWARD_PROTO="$code_forward_proto"
    CODE_RULES_TSV="$code_rules_tsv"
    CODE_RULES_B64="$code_rules_b64"
    CODE_RULE_COUNT="$code_rule_count"
    CODE_CODE_SCHEMA="$code_code_schema"
    if [[ -z "$existing_profile_id" && "$advanced" == "true" ]]; then
        collect_profile_identity "nat-ingress" || return 1
        profile_id="$PROFILE_ID"
        ET_HOSTNAME="$(prompt_validated "请输入节点名" "ix-nat-ingress-${profile_id}" validate_hostname_value "请输入 1-64 个字符，仅允许字母、数字、点、下划线或短横线。")" || return 1
        FORWARD_PROTO="$(prompt_forward_proto "请选择转发协议（tcp / udp / both / tcp/udp）" "${CODE_FORWARD_PROTO:-both}")" || return 1
    elif [[ -z "$existing_profile_id" ]]; then
        assign_auto_profile_identity "nat-ingress"
        profile_id="$PROFILE_ID"
        ET_HOSTNAME="ix-nat-ingress-${PROFILE_ID}"
        FORWARD_PROTO="${CODE_FORWARD_PROTO:-both}"
    fi
    IFS=$'\t' read -r first_rule_id first_note first_enabled first_nat_public first_transit first_landing_host first_landing_port first_proto <<<"$(printf '%s\n' "${CODE_RULES_TSV:-}" | awk 'NF{print; exit}')"

    ROLE="nat-ingress"
    NAT_DIRECTION="nat-listener"
    PROFILE_ID="$profile_id"
    PROFILE_NAME="${PROFILE_NAME:-$profile_id}"
    ENABLED="true"
    ET_NETWORK_NAME="$CODE_NETWORK_NAME"
    ET_NETWORK_SECRET="$CODE_NETWORK_SECRET"
    ET_IPV4="$CODE_INGRESS_ET_CIDR"
    ET_SUBNET="$(cidr_network24 "$ET_IPV4")"
    INGRESS_HOSTNAME="$ET_HOSTNAME"
    INGRESS_ET_IP="$CODE_INGRESS_ET_IP"
    INGRESS_ET_CIDR="$CODE_INGRESS_ET_CIDR"
    NAT_ET_IP="$CODE_NAT_ET_IP"
    NAT_ET_CIDR="$CODE_NAT_ET_CIDR"
    NAT_PUBLIC_HOST="$CODE_NAT_PUBLIC_HOST"
    NAT_PUBLIC_PORTS="$CODE_NAT_PUBLIC_PORTS"
    NAT_PUBLIC_PORT_MODE="${CODE_NAT_PUBLIC_PORT_MODE:-single}"
    NAT_LISTENER_PROTO="$CODE_NAT_LISTENER_PROTO"
    NAT_LISTENER_PROTOS="$CODE_NAT_LISTENER_PROTOS"
    NAT_LISTENER_PORT="$CODE_NAT_LISTENER_PORT"
    REMOTE_NAT_PROFILE_ID="$CODE_PROFILE_ID"
    REMOTE_NAT_PUBLIC_HOST="$CODE_NAT_PUBLIC_HOST"
    TRANSIT_PORT="${first_transit:-$CODE_TRANSIT_PORT}"
    LANDING_HOST="${first_landing_host:-$CODE_LANDING_HOST}"
    LANDING_PORT="${first_landing_port:-$CODE_LANDING_PORT}"
    FORWARD_PROTO="${first_proto:-${FORWARD_PROTO:-both}}"
    if [[ -n "${INGRESS_PUBLIC_HOST:-}" ]]; then
        printf '保留已保存的公网入口地址：%s\n' "$INGRESS_PUBLIC_HOST" >&2
    elif env_public="$(detect_env_ingress_public_host)"; then
        INGRESS_PUBLIC_HOST="$env_public"
        printf '使用环境变量指定的公网入口地址：%s\n' "$INGRESS_PUBLIC_HOST" >&2
    elif detected_public="$(detect_public_ipv4)"; then
        INGRESS_PUBLIC_HOST="$detected_public"
        printf '检测到当前公网 IPv4：%s\n' "$INGRESS_PUBLIC_HOST" >&2
    else
        INGRESS_PUBLIC_HOST=""
        printf '未自动检测到公网入口机公网 IPv4；show-port-map 会用占位符显示客户端地址。\n' >&2
    fi
    ET_PEERS="$(peer_urls_for_ports_value "$NAT_LISTENER_PROTO" "$NAT_PUBLIC_HOST" "${NAT_PUBLIC_PORTS:-$NAT_LISTENER_PORT}")"
    ET_NO_LISTENER="true"
    ET_PRIVATE_MODE="true"
    ET_EXPLICIT_ONLY="true"
    IXTF_EXPLICIT_ONLY="true"
    FORWARD_ENABLED="true"

    sync_nat_listener_code_rules_to_ingress_profile "$PROFILE_ID"
    refresh_nat_public_endpoints_for_profile "$PROFILE_ID"
    validate_profile_config "$PROFILE_ID"
    check_profile_conflicts "$PROFILE_ID"
    printf '\n正在写入配置...\n' >&2
    ensure_systemctl
    enable_ip_forward
    save_profile_env "$PROFILE_ID"
    render_profile_service_files
    printf '正在应用转发规则...\n' >&2
    apply_nft_all
    if ! verify_nft_profiles_core >/dev/null 2>&1; then
        log_warn "nftables 校验未完全通过，可运行 bash install.sh verify-nft-profiles 查看详情。"
    fi
    printf '正在重启 EasyTier...\n' >&2
    restart_profile "$PROFILE_ID" || log_warn "EasyTier 服务重启未完成，请运行 bash install.sh restart-profile ${PROFILE_ID}"
    printf '完成\n' >&2
    if ! verify_nat_ingress_import_consistency "$PROFILE_ID" "${IXTF_LAST_SYNC_SAVED_RULE_COUNT:-0}"; then
        return 1
    fi
    print_nat_ingress_import_complete_summary "$PROFILE_ID"
    return 0
}

refresh_code() {
    require_root
    if [[ -n "${1:-}" || -d "$PROFILES_DIR" ]]; then
        load_profile_or_die "$(resolve_profile_id "${1:-}")"
    else
        load_env_or_warn || die_user "未找到配置，无法刷新接入码。"
    fi
    [[ "${ROLE:-}" == "nat-ingress" || ( "${ROLE:-}" == "nat-transit" && "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ) ]] || die_user "refresh-code 只适用于 nat-ingress 或 nat-transit nat-listener。"
    validate_easytier_args
    ET_NETWORK_SECRET="$(generate_secret)"
    save_profile_env "$PROFILE_ID"
    save_profile_code_file "$PROFILE_ID" "$(generate_nat_code)"
    printf '已生成新的接入码。\n'
    if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
        printf '旧接入码已失效。\n'
        printf '公网入口机需要重新导入新的接入码。\n'
    else
        printf '旧接入码已失效。\n'
        printf 'NAT IX 机器需要重新导入新的接入码。\n'
    fi
    if command_exists systemctl; then
        render_profile_service_files
        restart_profile "$PROFILE_ID" || log_warn "Profile 已保存新 secret，但服务重启未完成；请手动运行：bash install.sh restart-profile ${PROFILE_ID}"
    fi
    show_code "$PROFILE_ID"
}

regenerate_nat_profile_code() {
    local profile_id="${1:-${PROFILE_ID:-}}"
    profile_id="$(resolve_profile_id "$profile_id")"
    load_profile_or_die "$profile_id"
    [[ "${ROLE:-}" == "nat-ingress" || ( "${ROLE:-}" == "nat-transit" && "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ) ]] || die_user "regenerate_nat_profile_code 只适用于 NAT-IX 线路。"
    validate_easytier_args
    refresh_nat_public_endpoints_for_profile "$profile_id"
    save_profile_env "$profile_id"
    save_profile_code_file "$profile_id" "$(generate_nat_code)"
    printf '已生成新的接入码。\n'
    printf '公网入口机需要重新导入新的接入码。\n'
    if [[ "${ROLE:-}" == "nat-transit" && "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
        render_profile_service_files
        restart_profile "$profile_id" || log_warn "接入码已更新，但 EasyTier 服务重启未完成。"
        verify_nat_transit_rule_consistency "$profile_id" || true
    fi
    show_code "$profile_id"
}

refresh_nat_code() {
    refresh_code "$@"
}

enabled_display() {
    [[ "${1:-true}" == "true" ]] && printf 'on\n' || printf 'off\n'
}

forward_display() {
    local role="${1:-}" enabled="${2:-true}" forward="${3:-true}"
    case "$role" in
        nat-ingress|nat-transit) ;;
        *) printf 'n/a\n'; return 0 ;;
    esac
    if [[ "$enabled" != "true" ]]; then
        printf 'off\n'
    elif [[ "$forward" == "true" ]]; then
        printf 'active\n'
    else
        printf 'standby\n'
    fi
}

panel_forward_display() {
    local role="${1:-}" enabled="${2:-true}" forward="${3:-true}"
    if [[ "$role" != "nat-ingress" ]]; then
        printf 'n/a\n'
    elif [[ "$enabled" != "true" ]]; then
        printf 'off\n'
    elif [[ "$forward" == "true" ]]; then
        printf 'active\n'
    else
        printf 'standby\n'
    fi
}

sorted_profile_ids() {
    local id group priority group_key
    for id in $(profile_ids); do
        if load_profile "$id" >/dev/null 2>&1; then
            group="${LINE_GROUP:-}"
            priority="${LINE_PRIORITY:-100}"
            [[ "$priority" =~ ^[0-9]+$ ]] || priority="99999"
            if [[ -n "$group" && "${LINE_ROLE:-standalone}" != "standalone" ]]; then
                group_key="$group"
            else
                group_key="~standalone"
            fi
            printf '%s\t%05d\t%s\n' "$group_key" "$priority" "$id"
        else
            printf '~unreadable\t99999\t%s\n' "$id"
        fi
    done | sort -t $'\t' -k1,1 -k2,2n -k3,3 | cut -f3
}

list_profiles() {
    require_root "$@"
    ensure_profile_dirs
    local id note enabled_label forward_label role_label client_label landing_label
    printf '线路ID\t角色\t启用\t转发\t健康\t客户端入口端口\t落地目标\t备注\n'
    for id in $(sorted_profile_ids); do
        load_profile "$id" || continue
        enabled_label="$(enabled_label_zh "${ENABLED:-true}")"
        forward_label="$(forward_label_zh "${ROLE:-}" "${ENABLED:-true}" "${FORWARD_ENABLED:-true}")"
        note="${SWITCH_NOTE:-${REMARK:-}}"
        [[ -z "$note" ]] && note="—"
        role_label="$(profile_role_label_zh "${ROLE:-}")"
        client_label="$(profile_client_port_summary "$id")"
        landing_label="$(profile_landing_target_summary "$id")"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$id" "$role_label" "$enabled_label" "$forward_label" "$(health_label_zh "${HEALTH_STATUS:-unknown}")" \
            "$client_label" "$landing_label" "$note"
    done
    if [[ "$(profile_count)" == "0" ]]; then
        printf '暂无线路。旧单线路配置可在高级维护中迁移。\n'
    fi
    return 0
}

generate_rule_id() {
    local prefix="${1:-rule}"
    prefix="${prefix,,}"
    prefix="${prefix//[^a-z0-9-]/}"
    [[ -n "$prefix" ]] || prefix="rule"
    printf '%s-%s\n' "$prefix" "$(random_hex 2)"
}

generate_unique_rule_id() {
    local profile_id="$1" prefix="${2:-rule}" id attempt
    for attempt in $(seq 1 30); do
        id="$(generate_rule_id "$prefix")"
        if [[ ! -e "$(rule_env_path "$profile_id" "$id" 2>/dev/null || printf /nonexistent)" ]]; then
            printf '%s\n' "$id"
            return 0
        fi
    done
    return 1
}

port_used_by_profile_rule() {
    local profile_id="$1" field="$2" port="$3" except_rule="${4:-}" rule_id value
    local saved_rule_id="${RULE_ID:-}" saved_note="${RULE_NOTE:-}" saved_enabled="${RULE_ENABLED:-}" saved_client="${CLIENT_PORT:-}" saved_nat_public="${NAT_PUBLIC_PORT:-}" saved_transit="${TRANSIT_PORT:-}" saved_landing_host="${LANDING_HOST:-}" saved_landing_port="${LANDING_PORT:-}" saved_proto="${FORWARD_PROTO:-both}" saved_created="${CREATED_AT:-}" saved_updated="${UPDATED_AT:-}" found=1
    for rule_id in $(profile_rule_ids "$profile_id"); do
        [[ "$rule_id" == "$except_rule" ]] && continue
        load_rule "$profile_id" "$rule_id" || continue
        [[ "${RULE_ENABLED:-true}" == "true" ]] || continue
        case "$field" in
            client) value="${CLIENT_PORT:-}" ;;
            nat-public) value="$(rule_nat_public_port_value 2>/dev/null || true)" ;;
            transit) value="${TRANSIT_PORT:-}" ;;
            *) value="" ;;
        esac
        if [[ -n "$value" && "$value" == "$port" ]]; then
            found=0
            break
        fi
    done
    RULE_ID="$saved_rule_id"; RULE_NOTE="$saved_note"; RULE_ENABLED="$saved_enabled"; CLIENT_PORT="$saved_client"; NAT_PUBLIC_PORT="$saved_nat_public"; TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"; CREATED_AT="$saved_created"; UPDATED_AT="$saved_updated"
    return "$found"
}

rule_port_conflict_owner() (
    local profile_id="$1" field="$2" port="$3" except_rule="${4:-}" id rule_id value seen_profile=" "
    for id in "$profile_id" $(profile_ids); do
        [[ -n "$id" ]] || continue
        [[ "$seen_profile" != *" ${id} "* ]] || continue
        seen_profile="${seen_profile}${id} "
        load_profile "$id" >/dev/null 2>&1 || continue
        profile_supports_forward_rules || continue
        if [[ "$field" == "transit" && "${ROLE:-}" != "nat-transit" ]]; then
            continue
        fi
        for rule_id in $(profile_rule_ids "$id"); do
            [[ "$id" == "$profile_id" && "$rule_id" == "$except_rule" ]] && continue
            load_rule "$id" "$rule_id" || continue
            [[ "${RULE_ENABLED:-true}" == "true" ]] || continue
            case "$field" in
                client) value="${CLIENT_PORT:-}" ;;
                nat-public) value="$(rule_nat_public_port_value 2>/dev/null || true)" ;;
                transit) value="${TRANSIT_PORT:-}" ;;
                *) value="" ;;
            esac
            if [[ -n "$value" && "$value" == "$port" ]]; then
                printf '%s\t%s\t%s\n' "$id" "$rule_id" "$(rule_note_display)"
                return 0
            fi
        done
    done
    return 1
)

format_rule_port_conflict_owner() {
    local profile_id="$1" field="$2" port="$3" except_rule="${4:-}" owner owner_profile owner_rule owner_note
    owner="$(rule_port_conflict_owner "$profile_id" "$field" "$port" "$except_rule")" || return 1
    IFS=$'\t' read -r owner_profile owner_rule owner_note <<<"$owner"
    if [[ "$owner_profile" == "$profile_id" ]]; then
        printf '规则 %s [%s]' "$owner_rule" "$owner_note"
    else
        printf '线路 %s 的规则 %s [%s]' "$owner_profile" "$owner_rule" "$owner_note"
    fi
}

pick_random_rule_port() {
    local profile_id="$1" field="$2" except_rule="${3:-}" port tries=0
    while (( tries < 60 )); do
        port="$(pick_random_port || true)"
        if [[ -n "$port" ]] && ! profile_uses_rule_port_for_conflict "$profile_id" "$field" "$port" "$except_rule"; then
            printf '%s\n' "$port"
            return 0
        fi
        tries=$((tries + 1))
    done
    return 1
}

list_rules() {
    require_root "$@"
    local profile_id rule_id saved_local saved_nat_public saved_transit saved_landing_host saved_landing_port saved_proto
    profile_id="$(resolve_profile_id "${1:-}")"
    load_profile_or_die "$profile_id"
    profile_supports_forward_rules || die_user "当前线路不支持转发规则管理：${ROLE:-unknown}"
    saved_local="${LOCAL_PORT:-}"; saved_nat_public="${NAT_PUBLIC_PORT:-}"; saved_transit="${TRANSIT_PORT:-}"; saved_landing_host="${LANDING_HOST:-}"; saved_landing_port="${LANDING_PORT:-}"; saved_proto="${FORWARD_PROTO:-both}"
    printf '规则ID\t状态\t备注\t客户端入口端口\t商家入口端口\t虚拟网中转端口\t落地目标\t协议\n'
    for rule_id in $(profile_rule_ids "$profile_id"); do
        load_rule "$profile_id" "$rule_id" || continue
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s:%s\t%s\n' \
            "$rule_id" "$(profile_rule_status_display)" "$(rule_note_display)" "$(rule_client_port_display)" "$(rule_nat_public_port_display)" "${TRANSIT_PORT:-}" "${LANDING_HOST:-}" "${LANDING_PORT:-}" "$(proto_display_user "${FORWARD_PROTO:-both}")"
    done
    LOCAL_PORT="$saved_local"; NAT_PUBLIC_PORT="$saved_nat_public"; TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
    return 0
}

rule_id_by_number() {
    local profile_id="$1" wanted="$2" wanted_num rule_id index=0
    [[ "$wanted" =~ ^[0-9]+$ ]] || return 1
    wanted_num=$((10#$wanted))
    for rule_id in $(profile_rule_ids "$profile_id"); do
        index=$((index + 1))
        if [[ "$index" -eq "$wanted_num" ]]; then
            printf '%s\n' "$rule_id"
            return 0
        fi
    done
    return 1
}

rule_menu_rule_count() {
    local profile_id="$1"
    profile_rule_count "$profile_id"
}

enabled_rule_count() {
    local profile_id="$1" rule_id count=0
    local saved_rule_id="${RULE_ID:-}" saved_note="${RULE_NOTE:-}" saved_enabled="${RULE_ENABLED:-}" saved_client="${CLIENT_PORT:-}" saved_nat_public="${NAT_PUBLIC_PORT:-}"
    local saved_transit="${TRANSIT_PORT:-}" saved_landing_host="${LANDING_HOST:-}" saved_landing_port="${LANDING_PORT:-}" saved_proto="${FORWARD_PROTO:-both}" saved_created="${CREATED_AT:-}" saved_updated="${UPDATED_AT:-}"
    for rule_id in $(profile_rule_ids "$profile_id"); do
        load_rule "$profile_id" "$rule_id" || continue
        [[ "${RULE_ENABLED:-true}" == "true" ]] && count=$((count + 1))
    done
    RULE_ID="$saved_rule_id"; RULE_NOTE="$saved_note"; RULE_ENABLED="$saved_enabled"; CLIENT_PORT="$saved_client"; NAT_PUBLIC_PORT="$saved_nat_public"
    TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"; CREATED_AT="$saved_created"; UPDATED_AT="$saved_updated"
    printf '%s\n' "$count"
}

print_rule_menu_header() {
    local profile_id="$1"
    load_profile_or_die "$profile_id"
    printf '当前线路：%s（%s）\n' "$profile_id" "$(profile_role_label_zh "${ROLE:-}")"
}

print_rule_menu_rules() {
    local profile_id="$1" rule_id index=0 target
    local saved_rule_id="${RULE_ID:-}" saved_note="${RULE_NOTE:-}" saved_enabled="${RULE_ENABLED:-}" saved_client="${CLIENT_PORT:-}" saved_nat_public="${NAT_PUBLIC_PORT:-}"
    local saved_transit="${TRANSIT_PORT:-}" saved_landing_host="${LANDING_HOST:-}" saved_landing_port="${LANDING_PORT:-}" saved_proto="${FORWARD_PROTO:-both}" saved_created="${CREATED_AT:-}" saved_updated="${UPDATED_AT:-}"
    printf '\n当前转发规则：\n\n'
    for rule_id in $(profile_rule_ids "$profile_id"); do
        load_rule "$profile_id" "$rule_id" || continue
        index=$((index + 1))
        if [[ -n "${LANDING_HOST:-}" && -n "${LANDING_PORT:-}" ]]; then
            target="${LANDING_HOST}:${LANDING_PORT}"
        else
            target="未配置"
        fi
        printf '%s. %s  %s  [%s]\n' "$index" "$rule_id" "$(profile_rule_status_display)" "$(rule_note_display)"
        printf '   公网入口端口：%s\n' "$(rule_client_port_display)"
        printf '   商家入口端口：%s\n' "$(rule_nat_public_port_display)"
        printf '   虚拟网中转端口：%s\n' "${TRANSIT_PORT:-未配置}"
        printf '   落地目标：%s\n' "$target"
        printf '   完整路径：%s\n' "$(profile_rule_path_display)"
        printf '   协议：%s\n\n' "$(proto_display_user "${FORWARD_PROTO:-both}")"
    done
    if [[ "$index" -eq 0 ]]; then
        printf '暂无转发规则。\n\n'
    fi
    RULE_ID="$saved_rule_id"; RULE_NOTE="$saved_note"; RULE_ENABLED="$saved_enabled"; CLIENT_PORT="$saved_client"; NAT_PUBLIC_PORT="$saved_nat_public"
    TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"; CREATED_AT="$saved_created"; UPDATED_AT="$saved_updated"
}

print_rule_choice_list() {
    local profile_id="$1" rule_id index=0
    local saved_rule_id="${RULE_ID:-}" saved_note="${RULE_NOTE:-}" saved_enabled="${RULE_ENABLED:-}" saved_client="${CLIENT_PORT:-}" saved_nat_public="${NAT_PUBLIC_PORT:-}"
    local saved_transit="${TRANSIT_PORT:-}" saved_landing_host="${LANDING_HOST:-}" saved_landing_port="${LANDING_PORT:-}" saved_proto="${FORWARD_PROTO:-both}" saved_created="${CREATED_AT:-}" saved_updated="${UPDATED_AT:-}"
    printf '请选择转发规则：\n\n' >&2
    for rule_id in $(profile_rule_ids "$profile_id"); do
        load_rule "$profile_id" "$rule_id" || continue
        index=$((index + 1))
        printf '%s. %s  %s  [%s]\n' "$index" "$rule_id" "$(profile_rule_status_display)" "$(rule_note_display)" >&2
    done
    printf '\n' >&2
    RULE_ID="$saved_rule_id"; RULE_NOTE="$saved_note"; RULE_ENABLED="$saved_enabled"; CLIENT_PORT="$saved_client"; NAT_PUBLIC_PORT="$saved_nat_public"
    TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"; CREATED_AT="$saved_created"; UPDATED_AT="$saved_updated"
}

select_rule_from_menu() {
    local profile_id="$1" count choice rule_id
    count="$(rule_menu_rule_count "$profile_id")"
    if [[ "$count" -eq 0 ]]; then
        log_warn "当前线路没有转发规则。"
        return 1
    fi
    while true; do
        print_rule_choice_list "$profile_id"
        printf '请输入序号 [0 返回 / 1-%s]：' "$count" >&2
        IFS= read -r choice || return 1
        choice="$(normalize_menu_choice "$choice")"
        if [[ -z "$choice" ]]; then
            continue
        fi
        if [[ "$choice" == "0" ]]; then
            return 1
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            if rule_id="$(rule_id_by_number "$profile_id" "$choice")"; then
                printf '%s\n' "$rule_id"
                return 0
            fi
            log_warn "无效选择，请输入列表中的序号。"
            continue
        fi
        if [[ -n "$choice" ]] && validate_rule_id "$choice" && load_rule "$profile_id" "$choice" >/dev/null 2>&1; then
            printf '%s\n' "$choice"
            return 0
        fi
        log_warn "无效选择，请输入列表中的序号。"
    done
}

select_profile_for_rule_menu() {
    local count choice choice_num id index selected
    local -a menu_ids=()
    count="$(profile_count)"
    if [[ "$count" -eq 0 ]]; then
        printf '当前没有线路，请先创建 NAT IX 中转线路或导入接入码。\n' >&2
        return 2
    fi
    if [[ "$count" -eq 1 ]]; then
        profile_ids | head -n 1
        return 0
    fi
    printf '请选择线路：\n\n' >&2
    index=0
    for id in $(sorted_profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        menu_ids+=("$id")
        index=$((index + 1))
        printf '%s. %s（%s，规则数：%s）\n' "$index" "$id" "$(profile_role_label_zh "${ROLE:-}")" "$(rule_menu_rule_count "$id")" >&2
    done
    if [[ "$index" -eq 0 ]]; then
        printf '当前没有可读取的线路，请检查线路配置文件权限。\n' >&2
        return 2
    fi
    printf '\n' >&2
    while true; do
        printf '请选择线路 [0 返回 / 1-%s]：' "$index" >&2
        IFS= read -r choice || return 1
        choice="$(normalize_menu_choice "$choice")"
        if [[ -z "$choice" ]]; then
            continue
        fi
        if [[ "$choice" == "0" ]]; then
            return 1
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            choice_num=$((10#$choice))
            if (( choice_num >= 1 && choice_num <= index )); then
                selected="${menu_ids[$((choice_num - 1))]}"
                printf '%s\n' "$selected"
                return 0
            fi
            log_warn "无效选择，请输入列表中的序号。"
            continue
        fi
        if [[ -n "$choice" ]] && validate_profile_id "$choice" && [[ -f "$(profile_env_path "$choice" 2>/dev/null || printf /nonexistent)" ]]; then
            printf '%s\n' "$choice"
            return 0
        fi
        log_warn "无效选择，请输入列表中的序号。"
    done
}

prompt_forward_proto_menu() {
    local choice default_proto="${1:-both}" default_choice=1
    require_tty
    case "$default_proto" in
        tcp) default_choice=2 ;;
        udp) default_choice=3 ;;
        *) default_proto="both"; default_choice=1 ;;
    esac
    cat >&2 <<'EOF'
转发协议：

1. TCP/UDP（推荐）
2. TCP
3. UDP
EOF
    while true; do
        printf '请选择 [1-3]，默认 %s：' "$(proto_display_user "$default_proto")" >&2
        IFS= read -r choice || return 1
        choice="$(normalize_menu_choice "$choice")"
        [[ -z "$choice" ]] && choice="$default_choice"
        case "$choice" in
            1) printf 'both\n'; return 0 ;;
            2) printf 'tcp\n'; return 0 ;;
            3) printf 'udp\n'; return 0 ;;
            *) log_warn "请选择 1、2 或 3。" ;;
        esac
    done
}

menu_add_rule() {
    local profile_id="$1" rule_id default_transit custom
    load_profile_or_die "$profile_id"
    profile_supports_forward_rules || die_user "当前线路不支持转发规则管理：${ROLE:-unknown}"
    if [[ "${ROLE:-}" == "nat-ingress" ]]; then
        cat <<'EOF'
公网入口机不建议直接新增落地规则。
请先在 NAT IX 机器新增转发规则，刷新接入码，然后在公网入口机重新导入。
公网入口机侧只负责为远端规则指定客户端入口端口。
EOF
        prompt_yes_no "是否返回" "true" >/dev/null || true
        return 0
    fi
    [[ "${ROLE:-}" == "nat-transit" ]] || die_user "新增落地规则请在 NAT IX 机器执行。"
    printf '\nNAT IX 机器新增转发规则\n\n'
    rule_id="$(generate_unique_rule_id "$profile_id" rule)"
    RULE_ID="$rule_id"
    RULE_NOTE="$(prompt_optional_text "请输入规则备注，例如：游戏、网页、备用落地" "")" || return 1
    LANDING_HOST="$(prompt_validated "请输入落地机地址" "" validate_host "请输入 IPv4 或域名。")" || return 1
    LANDING_PORT="$(prompt_port "请输入落地业务端口" "")" || return 1
    FORWARD_PROTO="$(prompt_forward_proto_menu both)" || return 1
    default_transit="$(pick_random_rule_port "$profile_id" transit || true)"
    custom="$(prompt_yes_no "是否自定义虚拟网中转端口" "false")" || return 1
    if [[ "$custom" == "true" || -z "$default_transit" ]]; then
        TRANSIT_PORT="$(prompt_port "请输入虚拟网中转端口" "$default_transit")" || return 1
        port_used_by_profile_rule "$profile_id" transit "$TRANSIT_PORT" && die_user "虚拟网中转端口已被同线路其他规则使用：${TRANSIT_PORT}"
    else
        TRANSIT_PORT="$default_transit"
    fi
    NAT_PUBLIC_PORT="$(pick_next_nat_public_port "$profile_id" "$rule_id" || true)"
    [[ -n "$NAT_PUBLIC_PORT" ]] || die_user "商家入口端口段已用完，请扩展 NAT_PUBLIC_PORTS 后再新增规则。"
    printf '自动分配商家入口端口：%s\n' "$NAT_PUBLIC_PORT" >&2
    CLIENT_PORT=""
    RULE_ENABLED="true"
    save_rule_env "$profile_id" "$rule_id"
    apply_nft_all
    refresh_profile_after_rule_change "$profile_id"
    load_rule "$profile_id" "$rule_id" || die_user "新增规则已保存，但无法重新读取：${rule_id}"
    printf '\n转发规则已新增：\n\n'
    printf '* 规则：%s\n' "$rule_id"
    printf '* 备注：%s\n' "$(rule_note_display)"
    printf '* 商家入口端口：%s\n' "$(rule_nat_public_port_display)"
    printf '* 虚拟网中转：%s:%s -> %s:%s\n' "${NAT_ET_IP:-NAT IX 虚拟 IP}" "$TRANSIT_PORT" "$LANDING_HOST" "$LANDING_PORT"
    printf '* 协议：%s\n' "$(proto_display_user "${FORWARD_PROTO:-both}")"
    printf '* 状态：%s\n\n' "$(profile_rule_status_display)"
    printf '快速检查：bash install.sh diagnose %s\n\n' "$profile_id"
    prompt_refresh_access_code_after_rule_change "$profile_id"
    return 0
}

prompt_refresh_access_code_after_rule_change() {
    local profile_id="$1"
    [[ -n "${IXTF_TEST_SOURCE:-}" ]] && return 0
    load_profile_or_die "$profile_id"
    [[ "${ROLE:-}" == "nat-transit" && "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]] || return 0
    printf '\n公网入口机需要重新导入接入码才能同步该规则。\n'
    printf '说明：NAT IX 侧 listener 已更新；公网入口需重新导入后新增/变更规则才生效。\n'
    if [[ "$(prompt_yes_no "是否现在生成新的接入码" "true")" == "true" ]]; then
        regenerate_nat_profile_code "$profile_id"
    else
        printf '稍后可在"转发规则管理 -> 刷新接入码"中生成。\n'
    fi
    return 0
}

refresh_profile_after_rule_change() {
    local profile_id="$1"
    load_profile_or_die "$profile_id"
    refresh_nat_public_endpoints_for_profile "$profile_id"
    save_profile_env "$profile_id" >/dev/null
    if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" && ( "${ROLE:-}" == "nat-transit" || "${ROLE:-}" == "nat-ingress" ) ]]; then
        render_profile_service_files
        restart_profile "$profile_id" || log_warn "规则已保存，但 EasyTier 服务重启未完成。"
        if [[ "${ROLE:-}" == "nat-transit" ]]; then
            verify_nat_transit_rule_consistency "$profile_id" || true
        fi
    fi
}

menu_edit_rule() {
    local profile_id="$1" rule_id choice value changed=0
    rule_id="$(select_rule_from_menu "$profile_id")" || return 0
    load_profile_or_die "$profile_id"
    load_rule "$profile_id" "$rule_id" || die_user "未找到规则：${rule_id}"
    while true; do
        printf '\n修改规则：%s [%s]\n\n' "$rule_id" "$(rule_note_display)" >&2
        cat >&2 <<'EOF'
可修改：

1. 备注
2. 落地机地址
3. 落地业务端口
4. 转发协议
5. 虚拟网中转端口
6. 商家入口端口
7. 客户端入口端口
8. 返回
EOF
        printf '请选择：' >&2
        IFS= read -r choice || return 1
        choice="$(normalize_menu_choice "$choice")"
        [[ -z "$choice" ]] && continue
        case "$choice" in
            1)
                RULE_NOTE="$(prompt_optional_text "请输入规则备注" "${RULE_NOTE:-}")" || return 1
                changed=1
                ;;
            2)
                if [[ "${ROLE:-}" == "nat-transit" ]]; then
                    LANDING_HOST="$(prompt_validated "请输入落地机地址" "${LANDING_HOST:-}" validate_host "请输入 IPv4 或域名。")" || return 1
                    changed=1
                else
                    printf '公网入口线路不允许修改落地地址。请到 NAT IX 机器修改并刷新接入码。\n'
                    return 0
                fi
                ;;
            3)
                if [[ "${ROLE:-}" == "nat-transit" ]]; then
                    LANDING_PORT="$(prompt_port "请输入落地业务端口" "${LANDING_PORT:-}")" || return 1
                    changed=1
                else
                    printf '公网入口线路不允许修改落地业务端口。请到 NAT IX 机器修改并刷新接入码。\n'
                    return 0
                fi
                ;;
            4)
                if [[ "${ROLE:-}" == "nat-transit" ]]; then
                    FORWARD_PROTO="$(prompt_forward_proto_menu "${FORWARD_PROTO:-both}")" || return 1
                    changed=1
                else
                    printf '公网入口线路不允许修改转发协议。请到 NAT IX 机器修改并刷新接入码。\n'
                    return 0
                fi
                ;;
            5)
                if [[ "${ROLE:-}" == "nat-transit" ]]; then
                    value="$(prompt_port "请输入新的虚拟网中转端口" "${TRANSIT_PORT:-}")" || return 1
                    port_used_by_profile_rule "$profile_id" transit "$value" "$rule_id" && die_user "虚拟网中转端口已被同线路其他规则使用：${value}"
                    TRANSIT_PORT="$value"
                    changed=1
                else
                    printf '公网入口线路不允许修改虚拟网中转端口。请到 NAT IX 机器修改并刷新接入码。\n'
                    return 0
                fi
                ;;
            6)
                if [[ "${ROLE:-}" == "nat-transit" && "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                    value="$(prompt_port "请输入新的商家入口端口" "$(rule_nat_public_port_value 2>/dev/null || true)")" || return 1
                    nat_public_port_in_pool "$value" || die_user "商家入口端口不在 NAT_PUBLIC_PORTS 中：${value}"
                    port_used_by_profile_rule "$profile_id" nat-public "$value" "$rule_id" && die_user "商家入口端口已被同线路其他规则使用：${value}"
                    NAT_PUBLIC_PORT="$value"
                    changed=1
                else
                    printf '公网入口线路不能修改商家入口端口；请在 NAT IX 机器修改并刷新接入码。\n'
                    return 0
                fi
                ;;
            7)
                if [[ "${ROLE:-}" == "nat-ingress" ]]; then
                    value="$(prompt_port "请输入新的客户端入口端口" "${CLIENT_PORT:-}")" || return 1
                    port_used_by_profile_rule "$profile_id" client "$value" "$rule_id" && die_user "客户端入口端口已被同线路其他规则使用：${value}"
                    CLIENT_PORT="$value"
                    changed=1
                else
                    printf 'NAT IX 中转线路的客户端入口端口由公网入口机侧指定。\n'
                    return 0
                fi
                ;;
            8|0|"")
                return 0
                ;;
            *)
                log_warn "未知选项，请重新选择。"
                continue
                ;;
        esac
        if [[ "$changed" -eq 1 ]]; then
            save_rule_env "$profile_id" "$rule_id"
            refresh_profile_after_rule_change "$profile_id"
            apply_nft_all
            log_ok "已修改转发规则：${rule_id}"
            if [[ "${ROLE:-}" == "nat-transit" ]]; then
                prompt_refresh_access_code_after_rule_change "$profile_id"
            fi
            return 0
        fi
    done
}

menu_enable_rule() {
    local profile_id="$1" rule_id
    rule_id="$(select_rule_from_menu "$profile_id")" || return 0
    load_profile_or_die "$profile_id"
    load_rule "$profile_id" "$rule_id" || die_user "未找到规则：${rule_id}"
    if [[ "${RULE_ENABLED:-true}" == "true" ]]; then
        printf '转发规则已启用：%s\n' "$rule_id"
        return 0
    fi
    RULE_ENABLED="true"
    save_rule_env "$profile_id" "$rule_id"
    refresh_profile_after_rule_change "$profile_id"
    apply_nft_all
    printf '转发规则已启用：%s\n' "$rule_id"
    prompt_refresh_access_code_after_rule_change "$profile_id"
    return 0
}

menu_disable_rule() {
    local profile_id="$1" rule_id answer
    rule_id="$(select_rule_from_menu "$profile_id")" || return 0
    load_profile_or_die "$profile_id"
    load_rule "$profile_id" "$rule_id" || die_user "未找到规则：${rule_id}"
    if [[ "${RULE_ENABLED:-true}" != "true" ]]; then
        printf '转发规则已停止：%s\n' "$rule_id"
        return 0
    fi
    if [[ "$(enabled_rule_count "$profile_id")" -le 1 ]]; then
        printf '这是当前线路最后一条启用规则，停止后该线路不会转发流量。\n'
        answer="$(prompt_yes_no "是否继续" "false")" || return 1
        [[ "$answer" == "true" ]] || { log_warn "已取消停止规则。"; return 0; }
    fi
    RULE_ENABLED="false"
    save_rule_env "$profile_id" "$rule_id"
    refresh_profile_after_rule_change "$profile_id"
    apply_nft_all
    printf '转发规则已停止：%s\n' "$rule_id"
    if [[ "${ROLE:-}" == "nat-transit" ]]; then
        prompt_refresh_access_code_after_rule_change "$profile_id"
    fi
    return 0
}

menu_delete_rule() {
    local profile_id="$1" rule_id note path
    rule_id="$(select_rule_from_menu "$profile_id")" || return 0
    load_profile_or_die "$profile_id"
    load_rule "$profile_id" "$rule_id" || die_user "未找到规则：${rule_id}"
    note="$(rule_note_display)"
    if ! read_exact_confirmation "确认删除规则 ${rule_id} [${note}]？请输入 DELETE：" "DELETE"; then
        log_warn "已取消删除规则。"
        return 0
    fi
    path="$(rule_env_path "$profile_id" "$rule_id")"
    [[ -f "$path" ]] || die_user "未找到规则文件：${rule_id}"
    rm -f -- "$path"
    refresh_profile_after_rule_change "$profile_id"
    apply_nft_all
    printf '已删除转发规则：%s\n' "$rule_id"
    prompt_refresh_access_code_after_rule_change "$profile_id"
    return 0
}

menu_refresh_rule_code() {
    local profile_id="$1"
    load_profile_or_die "$profile_id"
    if [[ "${ROLE:-}" != "nat-transit" || "${NAT_DIRECTION:-ingress-listener}" != "nat-listener" ]]; then
        printf '接入码应在 NAT IX 机器上刷新。\n'
        printf '请到 NAT IX 机器运行“刷新接入码”，然后回到公网入口机重新导入。\n'
        return 0
    fi
    refresh_nat_code "$profile_id"
    printf '公网入口机需要重新导入该接入码才能同步最新规则。\n'
    return 0
}

menu_apply_rules() {
    local profile_id="$1"
    load_profile_or_die "$profile_id"
    apply_rules "$profile_id"
    printf '已重新应用项目转发规则。\n'
    printf '本操作只渲染 ix-transit-fabric 项目表，不会重置全局 nftables 规则集。\n'
    return 0
}

show_rule() {
    require_root "$@"
    local profile_id rule_id
    profile_id="$(resolve_profile_id "${1:-}")"
    rule_id="${2:-}"
    [[ -n "$rule_id" ]] || die_user "用法：show-rule 线路ID 规则ID"
    load_profile_or_die "$profile_id"
    load_rule "$profile_id" "$rule_id" || die_user "未找到规则：${rule_id}"
    cat <<EOF
规则 ID：${RULE_ID}
备注：$(rule_note_display)
状态：$(profile_rule_status_display)
客户端入口端口：$(rule_client_port_display)
商家入口端口：$(rule_nat_public_port_display)
虚拟网中转端口：${TRANSIT_PORT:-}
落地机地址：${LANDING_HOST:-}
落地业务端口：${LANDING_PORT:-}
转发协议：${FORWARD_PROTO:-both}
创建时间：${CREATED_AT:-}
更新时间：${UPDATED_AT:-}
EOF
}

add_rule() {
    require_root "$@"
    require_tty add-rule
    local profile_id rule_id default_transit default_client custom note
    profile_id="$(resolve_profile_id "${1:-}")"
    load_profile_or_die "$profile_id"
    profile_supports_forward_rules || die_user "当前线路不支持转发规则管理：${ROLE:-unknown}"
    printf '新增转发规则\n'
    note="$(prompt_optional_text "请输入规则备注" "")" || return 1
    rule_id="$(prompt_optional_text "请输入规则 ID（回车自动生成）" "$(generate_unique_rule_id "$profile_id" rule)")" || return 1
    [[ -n "$rule_id" ]] || rule_id="$(generate_unique_rule_id "$profile_id" rule)"
    validate_rule_id "$rule_id" || die_user "RULE_ID 格式不正确：${rule_id}"
    if [[ -e "$(rule_env_path "$profile_id" "$rule_id" 2>/dev/null || printf /nonexistent)" ]]; then
        die_user "规则已存在：${rule_id}"
    fi
    RULE_ID="$rule_id"
    RULE_NOTE="$note"
    RULE_ENABLED="true"
    FORWARD_PROTO="$(prompt_forward_proto "请选择转发协议（默认 TCP/UDP）" "both")" || return 1
    default_transit="$(pick_random_rule_port "$profile_id" transit || true)"
    custom="$(prompt_yes_no "是否自定义虚拟网中转端口" "false")" || return 1
    if [[ "$custom" == "true" ]]; then
        TRANSIT_PORT="$(prompt_port "请输入虚拟网中转端口" "$default_transit")" || return 1
        port_used_by_profile_rule "$profile_id" transit "$TRANSIT_PORT" && die_user "虚拟网中转端口已被同线路其他规则使用：${TRANSIT_PORT}"
    else
        TRANSIT_PORT="$default_transit"
    fi
    if [[ "${ROLE:-}" == "nat-transit" ]]; then
        LANDING_HOST="$(prompt_validated "请输入落地机地址" "" validate_host "请输入 IPv4 或域名。")" || return 1
        LANDING_PORT="$(prompt_port "请输入落地业务端口" "")" || return 1
        NAT_PUBLIC_PORT="$(pick_next_nat_public_port "$profile_id" "$rule_id" || true)"
        [[ -n "$NAT_PUBLIC_PORT" ]] || die_user "商家入口端口段已用完，请扩展 NAT_PUBLIC_PORTS 后再新增规则。"
        printf '自动分配商家入口端口：%s\n' "$NAT_PUBLIC_PORT" >&2
        CLIENT_PORT=""
    else
        default_client="$(pick_random_rule_port "$profile_id" client || true)"
        CLIENT_PORT="$(prompt_random_port "请输入客户端入口端口" "$default_client")" || return 1
        port_used_by_profile_rule "$profile_id" client "$CLIENT_PORT" && die_user "客户端入口端口已被同线路其他规则使用：${CLIENT_PORT}"
        LANDING_HOST="${LANDING_HOST:-}"
        LANDING_PORT="${LANDING_PORT:-}"
    fi
    save_rule_env "$profile_id" "$rule_id"
    apply_nft_all || true
    refresh_profile_after_rule_change "$profile_id"
    load_rule "$profile_id" "$rule_id" || die_user "新增规则已保存，但无法重新读取：${rule_id}"
    printf '转发规则已新增：\n'
    printf '规则：%s\n' "$rule_id"
    printf '备注：%s\n' "$(rule_note_display)"
    [[ "${ROLE:-}" == "nat-transit" ]] && printf '商家入口端口：%s\n' "$(rule_nat_public_port_display)"
    printf '虚拟网中转：%s:%s -> %s:%s\n' "${NAT_ET_IP:-NAT IX 虚拟 IP}" "$TRANSIT_PORT" "${LANDING_HOST:-NAT IX 接入码中的落地目标}" "${LANDING_PORT:-}"
    printf '协议：%s\n' "$(proto_display_user "${FORWARD_PROTO:-both}")"
    printf '状态：%s\n' "$(profile_rule_status_display)"
    prompt_refresh_access_code_after_rule_change "$profile_id"
    return 0
}

edit_rule() {
    require_root "$@"
    require_tty edit-rule
    local profile_id rule_id answer value
    profile_id="$(resolve_profile_id "${1:-}")"
    rule_id="${2:-}"
    [[ -n "$rule_id" ]] || die_user "用法：edit-rule 线路ID 规则ID"
    load_profile_or_die "$profile_id"
    load_rule "$profile_id" "$rule_id" || die_user "未找到规则：${rule_id}"
    answer="$(prompt_yes_no "是否修改备注" "false")" || return 1
    [[ "$answer" == "true" ]] && RULE_NOTE="$(prompt_required "请输入规则备注" "${RULE_NOTE:-}")"
    answer="$(prompt_yes_no "是否修改转发协议" "false")" || return 1
    [[ "$answer" == "true" ]] && FORWARD_PROTO="$(prompt_forward_proto "请选择转发协议（tcp / udp / both）" "${FORWARD_PROTO:-both}")"
    answer="$(prompt_yes_no "是否修改启用状态" "false")" || return 1
    if [[ "$answer" == "true" ]]; then
        [[ "$(prompt_yes_no "是否启用该规则" "$([[ "${RULE_ENABLED:-true}" == "true" ]] && printf true || printf false)")" == "true" ]] && RULE_ENABLED="true" || RULE_ENABLED="false"
    fi
    if [[ "${ROLE:-}" == "nat-transit" ]]; then
        answer="$(prompt_yes_no "是否修改落地机地址" "false")" || return 1
        [[ "$answer" == "true" ]] && LANDING_HOST="$(prompt_validated "请输入落地机地址" "${LANDING_HOST:-}" validate_host "请输入 IPv4 或域名。")"
        answer="$(prompt_yes_no "是否修改落地业务端口" "false")" || return 1
        [[ "$answer" == "true" ]] && LANDING_PORT="$(prompt_port "请输入落地业务端口" "${LANDING_PORT:-}")"
        answer="$(prompt_yes_no "是否修改虚拟网中转端口" "false")" || return 1
        if [[ "$answer" == "true" ]]; then
            value="$(prompt_port "请输入新的虚拟网中转端口" "${TRANSIT_PORT:-}")" || return 1
            port_used_by_profile_rule "$profile_id" transit "$value" "$rule_id" && die_user "虚拟网中转端口已被同线路其他规则使用：${value}"
            TRANSIT_PORT="$value"
            log_warn "该修改会影响公网入口机，请刷新接入码并重新导入。"
        fi
        if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
            answer="$(prompt_yes_no "是否修改商家入口端口" "false")" || return 1
            if [[ "$answer" == "true" ]]; then
                value="$(prompt_port "请输入新的商家入口端口" "$(rule_nat_public_port_value 2>/dev/null || true)")" || return 1
                nat_public_port_in_pool "$value" || die_user "商家入口端口不在 NAT_PUBLIC_PORTS 中：${value}"
                port_used_by_profile_rule "$profile_id" nat-public "$value" "$rule_id" && die_user "商家入口端口已被同线路其他规则使用：${value}"
                NAT_PUBLIC_PORT="$value"
                log_warn "该修改会影响公网入口机，请刷新接入码并重新导入。"
            fi
        fi
    else
        answer="$(prompt_yes_no "是否修改客户端入口端口" "false")" || return 1
        if [[ "$answer" == "true" ]]; then
            value="$(prompt_port "请输入新的客户端入口端口" "${CLIENT_PORT:-}")" || return 1
            port_used_by_profile_rule "$profile_id" client "$value" "$rule_id" && die_user "客户端入口端口已被同线路其他规则使用：${value}"
            CLIENT_PORT="$value"
        fi
        printf '落地目标应以 NAT IX 机器为准；如需修改落地地址，请在 NAT IX 机器修改规则后刷新接入码并重新导入。\n'
    fi
    save_rule_env "$profile_id" "$rule_id"
    refresh_profile_after_rule_change "$profile_id"
    apply_nft_all || true
    log_ok "已修改转发规则：${rule_id}"
    if [[ "${ROLE:-}" == "nat-transit" ]]; then
        prompt_refresh_access_code_after_rule_change "$profile_id"
    fi
    return 0
}

set_rule_enabled() {
    local profile_id="$1" rule_id="$2" value="$3"
    load_profile_or_die "$profile_id"
    load_rule "$profile_id" "$rule_id" || die_user "未找到规则：${rule_id}"
    RULE_ENABLED="$value"
    save_rule_env "$profile_id" "$rule_id"
    refresh_profile_after_rule_change "$profile_id"
    apply_nft_all || true
    return 0
}

enable_rule() {
    require_root "$@"
    local profile_id rule_id
    profile_id="$(resolve_profile_id "${1:-}")"
    rule_id="${2:-}"
    [[ -n "$rule_id" ]] || die_user "用法：enable-rule 线路ID 规则ID"
    set_rule_enabled "$profile_id" "$rule_id" true
    printf '转发规则已启用：%s\n' "$rule_id"
    load_profile_or_die "$profile_id"
    if [[ "${ROLE:-}" == "nat-transit" ]]; then
        prompt_refresh_access_code_after_rule_change "$profile_id"
    fi
    return 0
}

disable_rule() {
    require_root "$@"
    local profile_id rule_id role=""
    profile_id="$(resolve_profile_id "${1:-}")"
    rule_id="${2:-}"
    [[ -n "$rule_id" ]] || die_user "用法：disable-rule 线路ID 规则ID"
    load_profile_or_die "$profile_id"
    role="${ROLE:-}"
    set_rule_enabled "$profile_id" "$rule_id" false
    printf '转发规则已停止：%s\n' "$rule_id"
    if [[ "$role" == "nat-transit" ]]; then
        prompt_refresh_access_code_after_rule_change "$profile_id"
    fi
    return 0
}

delete_rule() {
    require_root "$@"
    require_tty delete-rule
    local profile_id rule_id answer path
    profile_id="$(resolve_profile_id "${1:-}")"
    rule_id="${2:-}"
    [[ -n "$rule_id" ]] || die_user "用法：delete-rule 线路ID 规则ID"
    load_profile_or_die "$profile_id"
    path="$(rule_env_path "$profile_id" "$rule_id")"
    [[ -f "$path" ]] || die_user "未找到规则文件：${rule_id}"
    answer="$(prompt_yes_no "确认删除转发规则 ${rule_id}" "false")" || return 1
    [[ "$answer" == "true" ]] || die_user "已取消删除。"
    rm -f -- "$path"
    refresh_profile_after_rule_change "$profile_id"
    apply_nft_all || true
    printf '已删除转发规则：%s\n' "$rule_id"
    load_profile_or_die "$profile_id"
    if [[ "${ROLE:-}" == "nat-transit" ]]; then
        prompt_refresh_access_code_after_rule_change "$profile_id"
    else
        printf '如果公网入口机仍有对应规则，请重新导入接入码或停用本地规则。\n'
    fi
    return 0
}

apply_rules() {
    require_root "$@"
    local profile_id="${1:-}"
    [[ -z "$profile_id" ]] || load_profile_or_die "$(resolve_profile_id "$profile_id")"
    apply_nft_all
    return 0
}

show_profile() {
    require_root "$@"
    local profile_id
    profile_id="$(resolve_profile_id "${1:-}")"
    load_profile_or_die "$profile_id"
    print_config_summary loaded
    return 0
}

set_profile_enabled() {
    local profile_id="$1" value="$2"
    load_profile_or_die "$profile_id"
    ENABLED="$value"
    if [[ "$value" == "true" ]]; then
        validate_profile_config "$profile_id"
        check_profile_conflicts "$profile_id"
    fi
    save_profile_env "$profile_id"
    if [[ "$value" == "true" ]]; then
        start_profile "$profile_id"
    else
        stop_profile "$profile_id"
    fi
    apply_nft_all || true
}

enable_profile() {
    require_root "$@"
    local profile_id
    profile_id="$(resolve_profile_id "${1:-}")"
    set_profile_enabled "$profile_id" true
}

disable_profile() {
    require_root "$@"
    local profile_id
    profile_id="$(resolve_profile_id "${1:-}")"
    set_profile_enabled "$profile_id" false
}

delete_profile() {
    require_root "$@"
    local profile_id answer service
    profile_id="$(resolve_profile_id "${1:-}")"
    require_tty delete-profile
    answer="$(prompt_yes_no "确认删除 Profile ${profile_id}" "false")" || return 1
    [[ "$answer" == "true" ]] || die_user "已取消删除。"
    service="$(profile_service_name "$profile_id")"
    if command_exists systemctl; then
        systemctl stop "$service" >/dev/null 2>&1 || true
        systemctl disable "$service" >/dev/null 2>&1 || true
    fi
    rm -f -- "$(profile_env_path "$profile_id")" "$(profile_code_path "$profile_id")"
    apply_nft_all || true
    log_ok "已删除 Profile：${profile_id}"
}

rename_profile() {
    require_root "$@"
    local profile_id="${1:-}" new_name="${2:-}"
    profile_id="$(resolve_profile_id "$profile_id")"
    [[ -n "$new_name" ]] || die_user "请提供新的 Profile 名称。"
    load_profile_or_die "$profile_id"
    PROFILE_NAME="$new_name"
    save_profile_env "$profile_id"
}

wait_for_et_ip() {
    local profile_id="${1:-}" max_wait="${2:-30}" interval="${3:-2}" elapsed=0 et_ip
    profile_id="$(resolve_profile_id "$profile_id")"
    load_profile_or_die "$profile_id"
    et_ip="${ET_IPV4%%/*}"
    log_info "等待 ET_IP ${et_ip} 就绪（最多 ${max_wait}s）..."
    while [[ "$elapsed" -lt "$max_wait" ]]; do
        if check_et_ip_present "$et_ip" >/dev/null 2>&1; then
            log_ok "ET_IP ${et_ip} 已就绪"
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    log_warn "ET_IP ${et_ip} 在 ${max_wait}s 内未确认（超时）"
    return 1
}

profile_peer_route_target() {
    case "${ROLE:-}" in
        nat-ingress)
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                printf '%s\n' "${NAT_ET_IP:-}"
            else
                printf '%s\n' "${LANDING_ET_IP:-}"
            fi
            ;;
        nat-transit)
            printf '%s\n' "${INGRESS_ET_IP:-}"
            ;;
        *)
            printf '%s\n' "${NAT_ET_IP:-${INGRESS_ET_IP:-${LANDING_ET_IP:-}}}"
            ;;
    esac
}

profile_peer_route_label_zh() {
    case "${ROLE:-}" in
        nat-ingress)
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                printf '到 NAT IX 虚拟 IP 的路由/peer\n'
            else
                printf '到落地虚拟 IP 的路由/peer\n'
            fi
            ;;
        nat-transit)
            printf '到公网入口虚拟 IP 的路由/peer\n'
            ;;
        *)
            printf '路由/peer\n'
            ;;
    esac
}

wait_for_peer_or_route() {
    local profile_id="${1:-}" max_wait="${2:-30}" interval="${3:-2}" elapsed=0 target_ip
    profile_id="$(resolve_profile_id "$profile_id")"
    load_profile_or_die "$profile_id"
    target_ip="$(profile_peer_route_target)"
    [[ -n "$target_ip" ]] || return 0
    log_debug "等待 peer 路由 ${target_ip} 就绪（最多 ${max_wait}s）..."
    while [[ "$elapsed" -lt "$max_wait" ]]; do
        if command_exists ip && ip route get "$target_ip" >/dev/null 2>&1; then
            log_debug "peer 路由 ${target_ip} 已就绪"
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    log_warn "peer 路由 ${target_ip} 在 ${max_wait}s 内未确认（超时）"
    return 1
}

wait_for_easytier_ready() {
    local profile_id="${1:-}" service max_wait="${2:-30}" interval=2 elapsed=0 remaining active proc_ok="false" et_ip rc
    profile_id="$(resolve_profile_id "$profile_id")"
    load_profile_or_die "$profile_id"
    service="$(profile_service_name "$profile_id")"
    et_ip="${ET_IPV4%%/*}"
    log_debug "等待 EasyTier 服务就绪（最多 ${max_wait}s）..."
    while [[ "$elapsed" -lt "$max_wait" ]]; do
        active="$(profile_service_status "$service")"
        proc_ok="false"
        check_easytier_process && proc_ok="true"
        if [[ ( "$active" == "active" || "$active" == "activating" ) && "$proc_ok" == "true" ]]; then
            set +e
            assess_et_ip_health "$et_ip"
            rc=$?
            set -e
            [[ "$rc" -eq 0 || "$rc" -eq 3 ]] || { sleep "$interval"; elapsed=$((elapsed + interval)); continue; }
            log_debug "EasyTier 虚拟网已就绪（${et_ip}，assess=${rc}）"
            remaining=$((max_wait - elapsed))
            [[ "$remaining" -gt 0 ]] || remaining="$interval"
            case "${ROLE:-}" in
                nat-ingress|nat-transit) wait_for_peer_or_route "$profile_id" "$remaining" "$interval" || true ;;
            esac
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    log_warn "EasyTier 本机虚拟 IP 尚未出现或 peer 未建立，请查看："
    printf '  journalctl -u %s -n 100 --no-pager\n' "$service" >&2
    return 1
}

start_profile() {
    local profile_id="${1:-}" service
    profile_id="$(resolve_profile_id "$profile_id")"
    load_profile_or_die "$profile_id"
    if [[ "${_IXTF_PROFILE_SERVICE_FILES_READY:-false}" != "true" ]]; then
        render_profile_service_files
    fi
    service="$(profile_service_name "$profile_id")"
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable --now "$service" >/dev/null 2>&1
    wait_for_easytier_ready "$profile_id" 30 || true
    ensure_ddns_timer_enabled
    log_debug "已启动 Profile 服务：${service}"
}

stop_profile() {
    local profile_id="${1:-}" service
    profile_id="$(resolve_profile_id "$profile_id")"
    service="$(profile_service_name "$profile_id")"
    if command_exists systemctl; then
        systemctl stop "$service" >/dev/null 2>&1 || true
        log_ok "已停止 Profile 服务：${service}"
    fi
}

restart_profile() {
    local profile_id="${1:-}" service
    profile_id="$(resolve_profile_id "$profile_id")"
    load_profile_or_die "$profile_id"
    if [[ "${_IXTF_PROFILE_SERVICE_FILES_READY:-false}" != "true" ]]; then
        render_profile_service_files
    fi
    service="$(profile_service_name "$profile_id")"
    systemctl daemon-reload >/dev/null 2>&1
    if ! systemctl restart "$service" >/dev/null 2>&1; then
        log_warn "Profile 服务重启失败：${service}，请运行 bash install.sh export-diagnostic"
        return 1
    fi
    wait_for_easytier_ready "$profile_id" 30 || log_warn "EasyTier 重启后未在预期时间内就绪，请运行 bash install.sh show-easytier-status ${profile_id}"
    log_debug "已重启 Profile 服务：${service}"
}

set_easytier_protocol() {
    require_root "$@"
    require_tty set-easytier-protocol
    local profile_id proto
    profile_id="$(resolve_profile_id "${1:-}")"
    load_profile_or_die "$profile_id"
    proto="$(prompt_easytier_protocol_choice 1)" || return 1
    case "${ROLE:-}:${NAT_DIRECTION:-ingress-listener}" in
        nat-transit:nat-listener)
            NAT_LISTENER_PROTO="$proto"
            NAT_LISTENER_PROTOS="$(normalize_listener_protos "$proto" "both")"
            refresh_nat_public_endpoints_for_profile "$profile_id"
            ;;
        nat-ingress:nat-listener)
            NAT_LISTENER_PROTO="$proto"
            NAT_LISTENER_PROTOS="$(normalize_peer_protos "$proto" "both")"
            refresh_nat_public_endpoints_for_profile "$profile_id"
            ;;
        nat-ingress:ingress-listener)
            INGRESS_LISTENER_PROTO="$proto"
            INGRESS_LISTENER_PROTOS="$(normalize_listener_protos "$proto" "both")"
            ET_LISTENER_PROTO="$INGRESS_LISTENER_PROTO"
            ET_LISTENER_PORT="$INGRESS_LISTENER_PORT"
            ET_LISTENERS="$(listener_urls_value "$INGRESS_LISTENER_PROTO" "$INGRESS_LISTENER_PORT")"
            ;;
        nat-transit:ingress-listener)
            INGRESS_LISTENER_PROTO="$proto"
            INGRESS_LISTENER_PROTOS="$(normalize_peer_protos "$proto" "both")"
            ET_PEERS="$(peer_urls_value "$INGRESS_LISTENER_PROTO" "$INGRESS_PUBLIC_HOST" "$INGRESS_LISTENER_PORT")"
            ;;
        *)
            die_user "set-easytier-protocol 仅支持 NAT-IX 线路。"
            ;;
    esac
    validate_profile_config "$profile_id"
    save_profile_env "$profile_id"
    render_profile_service_files
    restart_profile "$profile_id"
    printf 'EasyTier 组网协议已更新：%s\n' "$(proto_display "$proto")"
    printf '如果该协议需要公网入口机和 NAT IX 双端一致，请刷新接入码并在对端重新导入。\n'
    printf '如果 EasyTier 当前版本不支持该协议，请查看 journalctl 日志中的启动失败原因。\n'
}

status_profile() {
    require_root "$@"
    local profile_id service active enabled_status
    if ! profile_id="$(resolve_profile_id_for_cmd "${1:-}" status-profile)"; then
        return_or_exit 2 || return $?
    fi
    if ! load_profile "$profile_id"; then
        print_profile_selection_hint "$profile_id" status-profile
        return_or_exit 2 || return $?
    fi
    print_config_summary loaded
    service="$(profile_service_name "$profile_id")"
    printf '\nsystemd 实例：%s\n' "$service"
    if command_exists systemctl; then
        active="$(systemctl is-active "$service" 2>/dev/null || true)"
        enabled_status="$(systemctl is-enabled "$service" 2>/dev/null || true)"
        printf 'systemd 状态：%s（开机自启：%s）\n' "${active:-unknown}" "${enabled_status:-unknown}"
        printf '\nEasyTier 详细状态：\n'
        status_easytier_detailed "$service" || true
    else
        printf 'systemd 状态：unknown（systemctl 不可用）\n'
    fi
}

logs_profile() {
    require_root "$@"
    local profile_id service secret line
    profile_id="$(resolve_profile_id "${1:-}")"
    load_profile_or_die "$profile_id"
    service="$(profile_service_name "$profile_id")"
    secret="${ET_NETWORK_SECRET:-}"
    journalctl -u "$service" -n 120 --no-pager 2>&1 | while IFS= read -r line; do
        [[ -n "$secret" ]] && line="${line//$secret/[hidden]}"
        printf '%s\n' "$line"
    done || true
}

validate_line_role() {
    case "${1:-}" in
        primary|backup|standalone) return 0 ;;
        *) return 1 ;;
    esac
}

validate_health_status_value() {
    case "${1:-}" in
        unknown|healthy|warning|down) return 0 ;;
        *) return 1 ;;
    esac
}

validate_line_priority() {
    [[ "${1:-}" =~ ^[0-9]{1,5}$ ]]
}

utc_now() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

health_rank() {
    case "${1:-unknown}" in
        healthy) printf '0\n' ;;
        unknown) printf '1\n' ;;
        warning) printf '2\n' ;;
        down) printf '3\n' ;;
        *) printf '1\n' ;;
    esac
}

pending_peer=""
EasyTier_peer_not_established="EasyTier peer 未建立，请检查对端服务状态和 show-easytier-command。"
EasyTier_peer_not_established_reason="NAT IX 机器可能尚未连接，或 EasyTier peer 未就绪。提示：检查 NAT IX 机器上的 EasyTier 服务状态（systemctl status ix-transit-easytier@...）和 show-easytier-command。"

health_mark() {
    local status="$1" reason="$2" current_rank next_rank
    current_rank="$(health_rank "${_IXTF_HEALTH_STATUS:-healthy}")"
    next_rank="$(health_rank "$status")"
    if (( next_rank > current_rank )); then
        _IXTF_HEALTH_STATUS="$status"
    fi
    if [[ -n "$reason" ]]; then
        if [[ -n "${_IXTF_HEALTH_REASON:-}" ]]; then
            _IXTF_HEALTH_REASON="${_IXTF_HEALTH_REASON}; ${reason}"
        else
            _IXTF_HEALTH_REASON="$reason"
        fi
    fi
}

health_line() {
    printf '  %-30s %s\n' "$1" "$2"
}

profile_service_status() {
    local service="$1"
    if ! command_exists systemctl; then
        printf 'unknown\n'
        return 0
    fi
    systemctl is-active "$service" 2>/dev/null || true
}

nft_profile_rule_present() {
    local profile_id="$1" output expected actual missing
    profile_needs_nft_forward || return 3
    output="$(nft_table_text 2>/dev/null || true)"
    [[ -n "$output" ]] || return 2
    expected="$(profile_expected_nft_rules)"
    [[ -n "$expected" ]] || return 2
    actual="$(nft_dnat_rules_from_text "$output")"
    missing="$(comm -23 <(printf '%s\n' "$expected" | awk 'NF' | sort -u) <(printf '%s\n' "$actual" | awk 'NF' | sort -u) || true)"
    [[ -z "$missing" ]]
}

nft_profile_rule_label() {
    local profile_id="$1"
    nft_profile_rule_status "$profile_id"
}

enabled_forwarding_ingress_count() {
    local id count=0
    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        profile_needs_nft_forward || continue
        count=$((count + 1))
    done
    printf '%s\n' "$count"
}

profile_role_counts() {
    local id landing=0 ingress=0 transit=0 other=0
    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        case "${ROLE:-}" in
            nat-transit) landing=$((landing + 1)) ;;
            nat-transit) transit=$((transit + 1)) ;;
            nat-ingress) ingress=$((ingress + 1)) ;;
            *) other=$((other + 1)) ;;
        esac
    done
    printf '%s %s %s %s\n' "$landing" "$ingress" "$transit" "$other"
}

nft_profile_rule_status() {
    local profile_id="$1" text expected_rules actual_rules missing_rules
    if [[ -n "$profile_id" ]]; then
        load_profile "$profile_id" >/dev/null 2>&1 || { printf 'unknown\n'; return 0; }
    fi
    profile_needs_nft_forward || { printf 'skipped\n'; return 0; }
    expected_rules="$(profile_expected_nft_rules)"
    [[ -n "$expected_rules" ]] || { printf 'unknown\n'; return 0; }
    text="$(nft_table_text 2>/dev/null || true)"
    [[ -n "$text" ]] || { printf 'unknown\n'; return 0; }
    actual_rules="$(nft_dnat_rules_from_text "$text")"
    missing_rules="$(comm -23 <(printf '%s\n' "$expected_rules" | awk 'NF' | sort -u) <(printf '%s\n' "$actual_rules" | awk 'NF' | sort -u) || true)"
    [[ -z "$missing_rules" ]] && printf 'present\n' || printf 'missing\n'
}

nft_forwarding_verify_status() {
    local text expected_rules actual_rules missing_rules extra_rules
    if [[ "$(enabled_forwarding_ingress_count)" -eq 0 ]]; then
        printf 'skipped\n'
        return 0
    fi
    text="$(nft_table_text 2>/dev/null || true)"
    if [[ -z "$text" ]]; then
        printf 'unavailable\n'
        return 0
    fi
    expected_rules="$(expected_forwarding_nft_rules)"
    actual_rules="$(nft_dnat_rules_from_text "$text")"
    missing_rules="$(comm -23 <(printf '%s\n' "$expected_rules" | awk 'NF' | sort -u) <(printf '%s\n' "$actual_rules" | awk 'NF' | sort -u) || true)"
    extra_rules="$(comm -13 <(printf '%s\n' "$expected_rules" | awk 'NF' | sort -u) <(printf '%s\n' "$actual_rules" | awk 'NF' | sort -u) || true)"
    [[ -z "$missing_rules" && -z "$extra_rules" ]] && printf 'ok\n' || printf 'mismatch\n'
}

print_normal_nft_forwarding_summary() {
    local status
    status="$(nft_forwarding_verify_status 2>/dev/null || printf 'unavailable')"
    case "$status" in
        ok|skipped) printf 'nftables 转发规则：正常\n' ;;
        mismatch) printf 'nftables 转发规则：需要查看\n' ;;
        *) printf 'nftables 转发规则：未确认\n' ;;
    esac
    printf '查看详细 nftables 校验：\n'
    printf 'bash install.sh verify-nft-profiles\n'
}

nft_table_text() {
    if command_exists nft && nft list table ip "$NFT_TABLE" >/dev/null 2>&1; then
        nft list table ip "$NFT_TABLE" 2>/dev/null
        return 0
    fi
    if [[ -r "$NFT_FILE" ]]; then
        cat "$NFT_FILE" 2>/dev/null
        return 0
    fi
    return 1
}

nft_text_has_dnat_rule() {
    local text="$1" proto="$2" local_port="$3" landing_ip="$4" remote_port="$5" daddr="${6:-}"
    [[ -n "$local_port" && -n "$landing_ip" && -n "$remote_port" ]] || return 1
    if [[ -n "$daddr" ]]; then
        grep -Eq "ip[[:space:]]+daddr[[:space:]]+${daddr}[[:space:]]+${proto}[[:space:]]+dport[[:space:]]+${local_port}([[:space:]]+counter([[:space:]]+packets[[:space:]]+[0-9]+[[:space:]]+bytes[[:space:]]+[0-9]+)?)?[[:space:]]+dnat[[:space:]]+to[[:space:]]+${landing_ip}:${remote_port}" <<<"$text" || return 1
    else
        grep -Eq "${proto}[[:space:]]+dport[[:space:]]+${local_port}([[:space:]]+counter([[:space:]]+packets[[:space:]]+[0-9]+[[:space:]]+bytes[[:space:]]+[0-9]+)?)?[[:space:]]+dnat[[:space:]]+to[[:space:]]+${landing_ip}:${remote_port}" <<<"$text" || return 1
    fi
}

nft_text_has_profile_rule() {
    local text="$1" proto="${FORWARD_PROTO:-both}" ok=1 dport target ip port daddr_ip="" rule_id
    local saved_local="${LOCAL_PORT:-}" saved_transit="${TRANSIT_PORT:-}" saved_landing_host="${LANDING_HOST:-}" saved_landing_port="${LANDING_PORT:-}" saved_proto="${FORWARD_PROTO:-both}"
    if profile_supports_forward_rules; then
        for rule_id in $(profile_rule_ids "${PROFILE_ID:-default}"); do
            load_rule "${PROFILE_ID:-default}" "$rule_id" || continue
            dport="$(profile_rule_nft_dport 2>/dev/null || true)"
            target="$(profile_rule_nft_target 2>/dev/null || true)"
            [[ -n "$dport" && -n "$target" ]] || continue
            ip="${target%:*}"
            port="${target##*:}"
            daddr_ip=""
            [[ "${ROLE:-}" == "nat-transit" ]] && daddr_ip="${NAT_ET_IP:-}"
            proto="${FORWARD_PROTO:-both}"
            case "$proto" in
                tcp) nft_text_has_dnat_rule "$text" tcp "$dport" "$ip" "$port" "$daddr_ip" && ok=0 ;;
                udp) nft_text_has_dnat_rule "$text" udp "$dport" "$ip" "$port" "$daddr_ip" && ok=0 ;;
                *)
                    nft_text_has_dnat_rule "$text" tcp "$dport" "$ip" "$port" "$daddr_ip" && ok=0
                    nft_text_has_dnat_rule "$text" udp "$dport" "$ip" "$port" "$daddr_ip" && ok=0
                    ;;
            esac
        done
        LOCAL_PORT="$saved_local"; TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
        return "$ok"
    fi
    dport="$(profile_nft_dport 2>/dev/null || true)"
    target="$(profile_nft_target 2>/dev/null || true)"
    [[ -n "$dport" && -n "$target" ]] || return 1
    ip="${target%:*}"
    port="${target##*:}"
    [[ "${ROLE:-}" == "nat-transit" ]] && daddr_ip="${NAT_ET_IP:-}"
    case "$proto" in
        tcp)
            nft_text_has_dnat_rule "$text" tcp "$dport" "$ip" "$port" "$daddr_ip" || ok=1
            ;;
        udp)
            nft_text_has_dnat_rule "$text" udp "$dport" "$ip" "$port" "$daddr_ip" || ok=1
            ;;
        *)
            ok=0
            nft_text_has_dnat_rule "$text" tcp "$dport" "$ip" "$port" "$daddr_ip" || ok=1
            nft_text_has_dnat_rule "$text" udp "$dport" "$ip" "$port" "$daddr_ip" || ok=1
            ;;
    esac
    return "$ok"
}

active_forwarding_local_ports() {
    local id rule_id saved_local saved_transit saved_landing_host saved_landing_port saved_proto
    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        profile_needs_nft_forward || continue
        if profile_supports_forward_rules; then
            saved_local="${LOCAL_PORT:-}"; saved_transit="${TRANSIT_PORT:-}"; saved_landing_host="${LANDING_HOST:-}"; saved_landing_port="${LANDING_PORT:-}"; saved_proto="${FORWARD_PROTO:-both}"
            for rule_id in $(profile_rule_ids "$id"); do
                load_rule "$id" "$rule_id" || continue
                [[ "${RULE_ENABLED:-true}" == "true" ]] || continue
                profile_rule_nft_dport 2>/dev/null || true
            done
            LOCAL_PORT="$saved_local"; TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
        else
            profile_nft_dport 2>/dev/null || true
        fi
    done | sort -u
}

nft_dnat_local_ports_from_text() {
    local text="$1"
    { grep -Eo 'dport[[:space:]]+[0-9]+([[:space:]]+counter([[:space:]]+packets[[:space:]]+[0-9]+[[:space:]]+bytes[[:space:]]+[0-9]+)?)?[[:space:]]+dnat[[:space:]]+to' <<<"$text" 2>/dev/null || true; } | awk '{print $2}' | sort -u
    return 0
}

nft_dnat_rules_from_text() {
    local text="$1"
    { grep -E '^[[:space:]]*((ip[[:space:]]+daddr[[:space:]]+[0-9.]+[[:space:]]+)?(tcp|udp))[[:space:]]+dport[[:space:]]+[0-9]+([[:space:]]+counter([[:space:]]+packets[[:space:]]+[0-9]+[[:space:]]+bytes[[:space:]]+[0-9]+)?)?[[:space:]]+dnat[[:space:]]+to[[:space:]]+' <<<"$text" 2>/dev/null || true; } |
        sed -E 's/^[[:space:]]+//; s/[[:space:]]+counter( packets [0-9]+ bytes [0-9]+)?//g; s/[[:space:]]+/ /g' | sort -u
    return 0
}

profile_expected_nft_rules() {
    local proto="${FORWARD_PROTO:-both}" dport target daddr rule_id saved_local saved_transit saved_landing_host saved_landing_port saved_proto
    profile_needs_nft_forward || return 0
    if profile_supports_forward_rules; then
        saved_local="${LOCAL_PORT:-}"; saved_transit="${TRANSIT_PORT:-}"; saved_landing_host="${LANDING_HOST:-}"; saved_landing_port="${LANDING_PORT:-}"; saved_proto="${FORWARD_PROTO:-both}"
        for rule_id in $(profile_rule_ids "${PROFILE_ID:-default}"); do
            load_rule "${PROFILE_ID:-default}" "$rule_id" || continue
            [[ "${RULE_ENABLED:-true}" == "true" ]] || continue
            proto="${FORWARD_PROTO:-both}"
            dport="$(profile_rule_nft_dport 2>/dev/null || true)"
            target="$(profile_rule_nft_target 2>/dev/null || true)"
            [[ -n "$dport" && -n "$target" ]] || continue
            daddr="$(profile_rule_nft_daddr_match || true)"
            if [[ "$proto" == "tcp" || "$proto" == "both" ]]; then
                printf '%stcp dport %s dnat to %s\n' "$daddr" "$dport" "$target"
            fi
            if [[ "$proto" == "udp" || "$proto" == "both" ]]; then
                printf '%sudp dport %s dnat to %s\n' "$daddr" "$dport" "$target"
            fi
        done
        LOCAL_PORT="$saved_local"; TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
    else
        dport="$(profile_nft_dport 2>/dev/null || true)"
        target="$(profile_nft_target 2>/dev/null || true)"
        [[ -n "$dport" && -n "$target" ]] || return 0
        daddr="$(profile_nft_daddr_match || true)"
        if [[ "$proto" == "tcp" || "$proto" == "both" ]]; then
            printf '%stcp dport %s dnat to %s\n' "$daddr" "$dport" "$target"
        fi
        if [[ "$proto" == "udp" || "$proto" == "both" ]]; then
            printf '%sudp dport %s dnat to %s\n' "$daddr" "$dport" "$target"
        fi
    fi
}

expected_forwarding_nft_rules() {
    local id
    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        profile_needs_nft_forward || continue
        profile_expected_nft_rules
    done | sort -u
}

group_expected_nft_rules() {
    local group="$1" id
    for id in $(list_group_ingress_profiles "$group"); do
        load_profile "$id" >/dev/null 2>&1 || continue
        [[ "${ENABLED:-true}" == "true" && "${FORWARD_ENABLED:-true}" == "true" ]] || continue
        profile_expected_nft_rules
    done | sort -u
}

group_actual_nft_rules() {
    local group="$1" text="${2:-}" id local_port
    [[ -n "$text" ]] || text="$(nft_table_text 2>/dev/null || true)"
    [[ -n "$text" ]] || return 0
    for id in $(list_group_ingress_profiles "$group"); do
        load_profile "$id" >/dev/null 2>&1 || continue
        local_port="${LOCAL_PORT:-}"
        [[ -n "$local_port" ]] || continue
        nft_dnat_rules_from_text "$text" | grep -E "^(tcp|udp) dport ${local_port} dnat to " || true
    done | sort -u
}

print_rule_list() {
    local rules="$1"
    if [[ -n "$rules" ]]; then
        while IFS= read -r rule; do
            [[ -n "$rule" ]] && printf '  - %s\n' "$rule"
        done <<<"$rules"
    else
        printf '  - none\n'
    fi
}

verify_nft_profiles_core() {
    local text source id issues=0 expected=0 expected_rules actual_rules missing_rules extra_rules
    local expected_ports actual_ports port unknown_count=0 disabled_residue=0 standby_residue=0 rule
    local forwarding_count landing_count ingress_count transit_count other_count
    local rule_id saved_local saved_transit saved_landing_host saved_landing_port saved_proto

    read -r landing_count ingress_count transit_count other_count < <(profile_role_counts)
    forwarding_count="$(enabled_forwarding_ingress_count)"
    if [[ "$forwarding_count" -eq 0 ]]; then
        printf 'nftables 转发规则校验\n'
        printf '当前机器没有启用中的入口转发 Profile，nftables 转发校验已跳过。\n'
        return 0
    fi

    if command_exists nft && nft list table ip "$NFT_TABLE" >/dev/null 2>&1; then
        source="运行时表 ip ${NFT_TABLE}"
        text="$(nft list table ip "$NFT_TABLE" 2>/dev/null || true)"
    elif [[ -r "$NFT_FILE" ]]; then
        source="$NFT_FILE"
        text="$(cat "$NFT_FILE" 2>/dev/null || true)"
    else
        printf 'nftables 转发规则校验\n'
        printf '数据源：不可用（无运行时表且无法读取 %s）\n' "$NFT_FILE"
        printf '[WARN] 入口转发 Profile 已启用，但当前没有可读取的 nftables 项目表。\n'
        printf '建议修复：bash install.sh apply-nft-all\n'
        return 1
    fi

    expected_rules="$(expected_forwarding_nft_rules)"
    actual_rules="$(nft_dnat_rules_from_text "$text")"

    printf 'nftables 转发规则校验\n'
    printf '数据源：%s\n' "$source"
    printf '\n期望规则：\n'
    print_rule_list "$expected_rules"
    printf '\n实际规则：\n'
    print_rule_list "$actual_rules"

    printf '\n期望转发规则明细：\n'
    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        profile_needs_nft_forward || continue
        if profile_supports_forward_rules; then
            saved_local="${LOCAL_PORT:-}"; saved_transit="${TRANSIT_PORT:-}"; saved_landing_host="${LANDING_HOST:-}"; saved_landing_port="${LANDING_PORT:-}"; saved_proto="${FORWARD_PROTO:-both}"
            for rule_id in $(profile_rule_ids "$id"); do
                load_rule "$id" "$rule_id" || continue
                [[ "${RULE_ENABLED:-true}" == "true" ]] || continue
                expected=$((expected + 1))
                printf '  - %s rule=%s ROLE=%s %s -> %s proto=%s\n' "$id" "$rule_id" "${ROLE:-missing}" "$(profile_rule_nft_dport 2>/dev/null || printf missing)" "$(profile_rule_nft_target 2>/dev/null || printf missing)" "${FORWARD_PROTO:-both}"
            done
            LOCAL_PORT="$saved_local"; TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
        else
            expected=$((expected + 1))
            printf '  - %s ROLE=%s %s -> %s proto=%s\n' "$id" "${ROLE:-missing}" "$(profile_nft_dport 2>/dev/null || printf missing)" "$(profile_nft_target 2>/dev/null || printf missing)" "${FORWARD_PROTO:-both}"
        fi
    done
    if [[ "$expected" -eq 0 ]]; then
        printf '  - 无\n'
        if [[ -n "$actual_rules" ]]; then
            printf '[WARN] 当前没有启用且开启转发的入口 Profile，但项目表中仍有转发规则。\n'
        else
            printf '[OK] 无启用转发 Profile，且实际无转发规则。\n'
        fi
    fi

    missing_rules="$(comm -23 <(printf '%s\n' "$expected_rules" | awk 'NF' | sort -u) <(printf '%s\n' "$actual_rules" | awk 'NF' | sort -u) || true)"
    extra_rules="$(comm -13 <(printf '%s\n' "$expected_rules" | awk 'NF' | sort -u) <(printf '%s\n' "$actual_rules" | awk 'NF' | sort -u) || true)"
    printf '\n缺失规则：\n'
    print_rule_list "$missing_rules"
    if [[ -n "$missing_rules" ]]; then
        issues=$((issues + $(printf '%s\n' "$missing_rules" | awk 'NF{c++} END{print c+0}')))
    fi
    printf '\n多余规则：\n'
    print_rule_list "$extra_rules"
    if [[ -n "$extra_rules" ]]; then
        issues=$((issues + $(printf '%s\n' "$extra_rules" | awk 'NF{c++} END{print c+0}')))
    fi

    printf '\n已停用线路残留规则：\n'
    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        case "${ROLE:-}" in nat-ingress|nat-transit) ;; *) continue ;; esac
        profile_nft_dport >/dev/null 2>&1 || continue
        profile_nft_target >/dev/null 2>&1 || continue
        if [[ "${ENABLED:-true}" != "true" ]] && nft_text_has_profile_rule "$text"; then
            disabled_residue=$((disabled_residue + 1))
            printf '[FAIL] 已停用线路 %s 仍有 nft 规则（端口=%s）\n' "$id" "$(profile_nft_dport 2>/dev/null || printf missing)"
        fi
    done
    [[ "$disabled_residue" -gt 0 ]] || printf '  - 无\n'
    issues=$((issues + disabled_residue))

    printf '\n转发已关闭线路残留规则：\n'
    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        case "${ROLE:-}" in nat-ingress|nat-transit) ;; *) continue ;; esac
        profile_nft_dport >/dev/null 2>&1 || continue
        profile_nft_target >/dev/null 2>&1 || continue
        if [[ "${ENABLED:-true}" == "true" && "${FORWARD_ENABLED:-true}" != "true" ]] && nft_text_has_profile_rule "$text"; then
            standby_residue=$((standby_residue + 1))
            printf '[FAIL] 转发已关闭线路 %s 仍有 nft 规则（端口=%s）\n' "$id" "$(profile_nft_dport 2>/dev/null || printf missing)"
        fi
    done
    [[ "$standby_residue" -gt 0 ]] || printf '  - 无\n'
    issues=$((issues + standby_residue))

    expected_ports="$(active_forwarding_local_ports)"
    actual_ports="$(nft_dnat_local_ports_from_text "$text")"
    printf '\n未知 LOCAL_PORT 规则：\n'
    while IFS= read -r port; do
        [[ -n "$port" ]] || continue
        if ! grep -qxF "$port" <<<"$expected_ports"; then
            printf '[FAIL] nftables 表包含未知 LOCAL_PORT 规则：%s\n' "$port"
            unknown_count=$((unknown_count + 1))
        fi
    done <<<"$actual_ports"
    [[ "$unknown_count" -gt 0 ]] || printf '  - 无\n'
    issues=$((issues + unknown_count))

    if [[ "$issues" -eq 0 ]]; then
        printf '\n[OK] nftables 规则与启用中的入口转发 Profile 一致。\n'
        return 0
    fi
    printf '\n[FAIL] nftables 规则与 Profile 状态不一致。\n'
    printf '建议修复：bash install.sh apply-nft-all\n'
    return 1
}

verify_nft_profiles() {
    require_root "$@"
    local rc
    if verify_nft_profiles_core; then
        return 0
    fi
    rc=$?
    return_or_exit "$rc" || return $?
}

port_owner_has_easytier() {
    local proto="$1" port="$2" output=""
    command_exists ss || return 2
    case "$proto" in
        tcp) output="$(ss -lntp 2>/dev/null | grep -E "[:.]${port}[[:space:]]" || true)" ;;
        udp) output="$(ss -lnup 2>/dev/null | grep -E "[:.]${port}[[:space:]]" || true)" ;;
        both)
            output="$({
                ss -lntp 2>/dev/null | grep -E "[:.]${port}[[:space:]]" || true
                ss -lnup 2>/dev/null | grep -E "[:.]${port}[[:space:]]" || true
            })"
            ;;
    esac
    [[ -n "$output" ]] || return 1
    grep -qi 'easytier' <<<"$output" && return 0
    return 3
}

profile_service_owns_port() {
    local service="$1" proto="$2" port="$3" control_group cg_path service_pids port_pids pid output=""
    command_exists systemctl && command_exists ss || return 2
    control_group="$(systemctl show -p ControlGroup --value "$service" 2>/dev/null || true)"
    [[ -n "$control_group" && "$control_group" != "/" ]] || return 2
    cg_path="/sys/fs/cgroup${control_group}"
    [[ -r "${cg_path}/cgroup.procs" ]] || return 2
    service_pids="$(cat "${cg_path}/cgroup.procs" 2>/dev/null || true)"
    [[ -n "$service_pids" ]] || return 2
    case "$proto" in
        tcp) output="$(ss -lntp 2>/dev/null | grep -E "[:.]${port}[[:space:]]" || true)" ;;
        udp) output="$(ss -lnup 2>/dev/null | grep -E "[:.]${port}[[:space:]]" || true)" ;;
        both)
            output="$({
                ss -lntp 2>/dev/null | grep -E "[:.]${port}[[:space:]]" || true
                ss -lnup 2>/dev/null | grep -E "[:.]${port}[[:space:]]" || true
            })"
            ;;
    esac
    port_pids="$(grep -oE 'pid=[0-9]+' <<<"$output" | cut -d= -f2 | sort -u)"
    [[ -n "$port_pids" ]] || return 2
    while IFS= read -r pid; do
        [[ -n "$pid" ]] || continue
        grep -qx "$pid" <<<"$service_pids" && return 0
    done <<<"$port_pids"
    return 1
}

profile_port_map_complete() {
    case "${ROLE:-}" in
        nat-transit)
            [[ -n "${LISTENER_PORT:-${ET_LISTENER_PORT:-}}" && -n "${ET_LISTENERS:-}" ]]
            ;;
        nat-ingress)
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                [[ -n "${ET_PEERS:-}" && -n "${NAT_PUBLIC_HOST:-}" && -n "${NAT_LISTENER_PORT:-}" && -n "${INGRESS_ET_IP:-}" && -n "${NAT_ET_IP:-}" ]] || return 1
            else
                [[ -n "${CNIX_ENTRY_HOST:-}" && -n "${CNIX_ENTRY_PORT:-}" && -n "${ET_PEERS:-}" ]] || return 1
                [[ -n "${ET_LISTENERS:-}" && -n "${INGRESS_PUBLIC_HOST:-}" && -n "${INGRESS_ET_IP:-}" && -n "${NAT_ET_IP:-}" ]] || return 1
            fi
            if [[ "${FORWARD_ENABLED:-true}" == "true" ]]; then
                if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                    [[ -n "${LOCAL_PORT:-}" && -n "${TRANSIT_PORT:-}" && -n "${LANDING_HOST:-}" && -n "${LANDING_PORT:-}" && -n "${FORWARD_PROTO:-}" ]]
                else
                    [[ -n "${LOCAL_PORT:-}" && -n "${LANDING_ET_IP:-}" && -n "${REMOTE_PORT:-}" && -n "${FORWARD_PROTO:-}" ]]
                fi
            fi
            ;;
        nat-transit)
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                [[ -n "${ET_LISTENERS:-}" && -n "${NAT_PUBLIC_HOST:-}" && -n "${NAT_LISTENER_PORT:-}" && -n "${INGRESS_ET_IP:-}" && -n "${NAT_ET_IP:-}" ]] || return 1
            else
                [[ -n "${ET_PEERS:-}" && -n "${INGRESS_PUBLIC_HOST:-}" && -n "${INGRESS_ET_IP:-}" && -n "${NAT_ET_IP:-}" ]] || return 1
            fi
            if [[ "${FORWARD_ENABLED:-true}" == "true" ]]; then
                [[ -n "${TRANSIT_PORT:-}" && -n "${LANDING_HOST:-}" && -n "${LANDING_PORT:-}" && -n "${FORWARD_PROTO:-}" ]]
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

profile_counter_health_status() {
    local text packets bytes state
    text="$(nft_table_text 2>/dev/null || true)"
    if [[ -z "$text" ]]; then
        printf 'unavailable\t-\t-\n'
        return 0
    fi
    IFS=$'\t' read -r packets bytes state <<<"$(profile_counter_from_text "$text")"
    if [[ "$state" == "ok" ]]; then
        if [[ "$packets" =~ ^[0-9]+$ && "$packets" -gt 0 ]]; then
            printf 'hit\t%s\t%s\n' "$packets" "$bytes"
        else
            printf 'readable\t%s\t%s\n' "${packets:-0}" "${bytes:-0}"
        fi
        return 0
    fi
    if nft_text_has_profile_rule "$text"; then
        printf 'readable\t-\t-\n'
        return 0
    fi
    printf 'missing\t-\t-\n'
}

now_ms() {
    local value
    value="$(date +%s%3N 2>/dev/null || true)"
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "$value"
    else
        awk 'BEGIN { printf "%d\n", systime() * 1000 }'
    fi
}

parse_ping_summary() {
    local text="${1:-}" loss stats min avg max mdev
    if [[ -z "$text" ]]; then
        text="$(cat 2>/dev/null || true)"
    fi
    loss="$(sed -nE 's/.* ([0-9]+(\.[0-9]+)?)% packet loss.*/\1%/p' <<<"$text" | tail -n 1)"
    stats="$(awk -F'= ' '/(rtt|round-trip).*min\/avg\/max/ { print $2; exit }' <<<"$text" 2>/dev/null || true)"
    stats="${stats%% ms*}"
    stats="${stats%%ms*}"
    IFS='/' read -r min avg max mdev <<<"$stats"
    printf 'loss=%s min=%s avg=%s max=%s mdev=%s\n' \
        "${loss:-unknown}" "${min:--}" "${avg:--}" "${max:--}" "${mdev:--}"
}

ping_summary() {
    local host="${1:-}" count="${2:-5}" output rc
    if [[ -z "$host" ]]; then
        printf 'skipped\n'
        return 0
    fi
    [[ "$count" =~ ^[0-9]+$ && "$count" -gt 0 ]] || count=5
    if ! command_exists ping; then
        printf 'skipped reason=ping-unavailable\n'
        return 0
    fi
    set +e
    output="$(ping -c "$count" -W 2 "$host" 2>&1)"
    rc=$?
    set -e
    if [[ -n "$output" ]]; then
        parse_ping_summary "$output"
    else
        printf 'loss=unknown min=- avg=- max=- mdev=-\n'
    fi
    [[ "$rc" -eq 0 ]] || return 0
}

print_latency_metric() {
    local label="$1" metric="${2:-}"
    [[ -n "$metric" ]] || metric="$(cat 2>/dev/null || true)"
    printf '%s: %s\n' "$label" "${metric:-skipped}"
}

nc_connect_time() {
    local host="$1" port="$2" timeout="${3:-3}" nc_cmd start end rc elapsed
    nc_cmd="$(detect_nc_cmd 2>/dev/null || true)"
    [[ -n "$nc_cmd" ]] || return 2
    start="$(now_ms)"
    set +e
    "$nc_cmd" -z -w "$timeout" "$host" "$port" >/dev/null 2>&1
    rc=$?
    set -e
    end="$(now_ms)"
    elapsed=$((end - start))
    if [[ "$rc" -eq 0 ]]; then
        printf 'tcp_connect=success time_ms=%s method=%s\n' "$elapsed" "$nc_cmd"
    else
        printf 'tcp_connect=failed reason=%s_exit_%s time_ms=%s\n' "$nc_cmd" "$rc" "$elapsed"
    fi
    return 0
}

bash_tcp_connect_time() {
    local host="$1" port="$2" timeout="${3:-3}" start end rc elapsed
    command_exists bash || { printf 'tcp_connect=failed reason=bash-unavailable\n'; return 0; }
    command_exists timeout || { printf 'tcp_connect=failed reason=timeout-unavailable\n'; return 0; }
    start="$(now_ms)"
    set +e
    timeout "$timeout" bash -c ': >/dev/tcp/$1/$2' _ "$host" "$port" >/dev/null 2>&1
    rc=$?
    set -e
    end="$(now_ms)"
    elapsed=$((end - start))
    if [[ "$rc" -eq 0 ]]; then
        printf 'tcp_connect=success time_ms=%s method=bash-dev-tcp\n' "$elapsed"
    else
        printf 'tcp_connect=failed reason=bash_dev_tcp_exit_%s time_ms=%s\n' "$rc" "$elapsed"
    fi
    return 0
}

tcp_connect_time() {
    local host="${1:-}" port="${2:-}" timeout="${3:-3}"
    if [[ -z "$host" || -z "$port" ]]; then
        printf 'tcp_connect=failed reason=missing-host-or-port\n'
        return 0
    fi
    [[ "$timeout" =~ ^[0-9]+$ && "$timeout" -gt 0 ]] || timeout=3
    if detect_nc_cmd >/dev/null 2>&1; then
        nc_connect_time "$host" "$port" "$timeout"
    else
        bash_tcp_connect_time "$host" "$port" "$timeout"
    fi
}

redact_sensitive_text() {
    local text="${1:-}" secret="${ET_NETWORK_SECRET:-}"
    if [[ -z "$text" ]]; then
        text="$(cat 2>/dev/null || true)"
    fi
    if [[ -n "$secret" ]]; then
        text="${text//$secret/[hidden]}"
    fi
    sed -E \
        -e 's/(network[_-]?secret[=: ]+)[^ ]+/\1[hidden]/g' \
        -e 's/(--network-secret[= ]+)[^ ]+/\1[hidden]/g' \
        <<<"$text"
}

print_service_status_short() {
    local service="$1" active enabled
    if command_exists systemctl; then
        active="$(systemctl is-active "$service" 2>/dev/null || true)"
        enabled="$(systemctl is-enabled "$service" 2>/dev/null || true)"
        printf 'systemd：运行=%s 自启=%s 服务=%s\n' "${active:-未知}" "${enabled:-未知}" "$service"
    else
        printf 'systemd：不可用 服务=%s\n' "$service"
    fi
}

print_easytier_peer_hints() {
    local service="$1" logs filtered latest
    printf 'EasyTier 运行日志摘要：\n'
    if command_exists journalctl; then
        logs="$(journalctl -u "$service" -n 80 --no-pager 2>&1 || true)"
        logs="$(redact_sensitive_text "$logs")"
        filtered="$(grep -Eai 'new peer|peer connection|tunnel_type|tcp|udp|latency|error|timeout' <<<"$logs" 2>/dev/null || true)"
        grep -Eqi 'tunnel_type.*tcp' <<<"$filtered" && printf '* 检测到 tunnel_type=tcp\n'
        grep -Eqi 'tunnel_type.*udp' <<<"$filtered" && printf '* 检测到 tunnel_type=udp\n'
        latest="$(grep -Eai 'new peer|peer connection|tunnel_type|latency|error|timeout' <<<"$filtered" 2>/dev/null | tail -n 1 || true)"
        if [[ -n "$latest" ]]; then
            printf '* 最近连接日志：%s\n' "$latest"
        else
            printf '* journalctl 中无近期 peer/隧道日志\n'
        fi
    else
        printf '* journalctl 不可用\n'
    fi
    if command_exists easytier-cli; then
        printf 'easytier-cli 摘要：\n'
        set +e
        easytier-cli peer 2>&1 | redact_sensitive_text | sed -n '1,20p'
        easytier-cli route 2>&1 | redact_sensitive_text | sed -n '1,20p'
        easytier-cli node 2>&1 | redact_sensitive_text | sed -n '1,20p'
        set -e
    else
        printf '* easytier-cli 不可用\n'
    fi
}

show_easytier_status() {
    require_root "$@"
    local profile_id="${1:-}" service rc target_ip route_label
    if ! profile_id="$(resolve_profile_id_for_cmd "$profile_id" show-easytier-status)"; then
        return_or_exit 2 || return $?
    fi
    if ! load_profile "$profile_id"; then
        print_profile_selection_hint "$profile_id" show-easytier-status
        return_or_exit 2 || return $?
    fi
    refresh_nat_public_endpoints_for_profile "$profile_id"
    service="$(profile_service_name "$profile_id")"
    printf 'EasyTier 状态：%s\n' "$profile_id"
    print_service_status_short "$service"
    if check_easytier_process; then
        printf 'easytier-core 进程：存在\n'
    else
        printf 'easytier-core 进程：未检测到\n'
    fi
    set +e
    assess_et_ip_health
    rc=$?
    set -e
    case "$rc" in
        0) printf '本机 ET IP：存在（%s）\n' "${ET_IPV4:-}" ;;
        3) printf '本机 ET IP：未挂网卡但虚拟网可用（%s）\n' "${ET_IPV4:-}" ;;
        2) printf '本机 ET IP：无法检查（ip 命令不可用）\n' ;;
        *) printf '本机 ET IP：不存在（%s）\n' "${ET_IPV4:-未配置}" ;;
    esac
    printf '\n'
    print_easytier_endpoint_summary
    printf '\n'
    target_ip="$(profile_peer_route_target)"
    route_label="$(profile_peer_route_label_zh)"
    if [[ -n "$target_ip" ]] && command_exists ip; then
        if ip route get "$target_ip" >/dev/null 2>&1; then
            printf '%s：已确认（%s）\n' "$route_label" "$target_ip"
        else
            printf '%s：未确认（%s）\n' "$route_label" "$target_ip"
        fi
    elif [[ -n "$target_ip" ]]; then
        printf '%s：无法检查（ip 命令不可用）\n' "$route_label"
    fi
    printf '\n'
    print_easytier_peer_hints "$service"
}

diagnose_profile() {
    local profile_id="$1" rc=0
    load_profile_or_die "$profile_id"
    normalize_profile_compat_vars
    printf '\n===== ix-transit-fabric 诊断：%s =====\n' "$profile_id"
    printf '线路类型：%s\n' "$(profile_role_label_zh)"
    if [[ "${ROLE:-}" == "nat-ingress" || "${ROLE:-}" == "nat-transit" ]]; then
        printf '线路模式：%s\n' "$(nat_direction_label "${NAT_DIRECTION:-ingress-listener}")"
    fi

    printf '\n--- EasyTier ---\n'
    show_easytier_status "$profile_id" || rc=1

    case "${ROLE:-}:${NAT_DIRECTION:-ingress-listener}" in
        nat-ingress:nat-listener)
            printf '\n--- nftables 转发 ---\n'
            verify_nft_profiles_core || rc=1
            printf '\n提示：客户端应连接 %s:CLIENT_PORT。\n' "${INGRESS_PUBLIC_HOST:-公网入口机公网 IP}"
            printf '该端口由 nftables DNAT 转发，ss -lntp 通常看不到监听。\n'
            ;;
        nat-transit:nat-listener)
            printf '\n--- NAT IX 规则一致性 ---\n'
            verify_nat_transit_rule_consistency "$profile_id" || rc=1
            printf '\n提示：商家入口 %s:NAT_PUBLIC_PORT 应在 ss -lntp 中看到 EasyTier 监听。\n' "${NAT_PUBLIC_HOST:-商家 NAT/IX 地址}"
            ;;
    esac

    printf '\n--- 转发规则 ---\n'
    print_forward_rule_health_summary "$profile_id"

    printf '\n更多命令：\n'
    printf '  bash install.sh show-port-map --compact %s\n' "$profile_id"
    printf '  bash install.sh export-diagnostic\n'
    return "$rc"
}

diagnose() {
    require_root "$@"
    local profile_id="${1:-}" count
    count="$(profile_count)"
    [[ "$count" != "0" ]] || die_user "当前没有线路。"
    if [[ -z "$profile_id" ]]; then
        if ! profile_id="$(resolve_profile_id_for_cmd "" diagnose)"; then
            return_or_exit 2 || return $?
        fi
    elif ! load_profile "$profile_id" 2>/dev/null; then
        print_profile_selection_hint "$profile_id" diagnose
        return_or_exit 2 || return $?
    fi
    diagnose_profile "$profile_id"
}

parse_sample_seconds() {
    local sample="${1:-0}"
    [[ "$sample" =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "$sample"
}

profile_counter_line_from_text() {
    local text="$1" packets bytes state
    IFS=$'\t' read -r packets bytes state <<<"$(profile_counter_from_text "$text")"
    printf '%s\t%s\t%s\n' "$packets" "$bytes" "$state"
}

print_profile_counter_sample() {
    local sample="${1:-0}" before_text after_text before_packets before_bytes before_state after_packets after_bytes after_state delta_packets delta_bytes
    before_text="$(nft_table_text 2>/dev/null || true)"
    IFS=$'\t' read -r before_packets before_bytes before_state <<<"$(profile_counter_line_from_text "$before_text")"
    if [[ "$sample" =~ ^[0-9]+$ && "$sample" -gt 0 ]]; then
        printf 'counter before: packets=%s bytes=%s state=%s\n' "$before_packets" "$before_bytes" "$before_state"
        sleep "$sample"
        after_text="$(nft_table_text 2>/dev/null || true)"
        IFS=$'\t' read -r after_packets after_bytes after_state <<<"$(profile_counter_line_from_text "$after_text")"
        printf 'counter after: packets=%s bytes=%s state=%s\n' "$after_packets" "$after_bytes" "$after_state"
        if [[ "$before_packets" =~ ^[0-9]+$ && "$after_packets" =~ ^[0-9]+$ && "$before_bytes" =~ ^[0-9]+$ && "$after_bytes" =~ ^[0-9]+$ ]]; then
            delta_packets=$((after_packets - before_packets))
            delta_bytes=$((after_bytes - before_bytes))
            printf 'counter delta: packets=%s bytes=%s\n' "$delta_packets" "$delta_bytes"
            if [[ "$delta_packets" -gt 0 || "$delta_bytes" -gt 0 ]]; then
                printf 'counter hint: 测试期间有流量命中项目 nftables 规则。\n'
            else
                printf 'counter hint: 没有观察到项目规则流量命中；请确认客户端正在连接正确 LOCAL_PORT。\n'
            fi
        else
            printf 'counter delta: unavailable\n'
        fi
    else
        printf 'counter current: packets=%s bytes=%s state=%s\n' "$before_packets" "$before_bytes" "$before_state"
    fi
}

print_listener_check() {
    local port="${1:-}" proto="${2:-both}" output=""
    if [[ -z "$port" ]]; then
        printf 'listener check: skipped\n'
        return 0
    fi
    if ! command_exists ss; then
        printf 'listener check: skipped reason=ss-unavailable\n'
        return 0
    fi
    case "$proto" in
        tcp) output="$(ss -lntp 2>/dev/null | grep -E "[:.]${port}[[:space:]]" || true)" ;;
        udp) output="$(ss -lnup 2>/dev/null | grep -E "[:.]${port}[[:space:]]" || true)" ;;
        *) output="$({ ss -lntp 2>/dev/null; ss -lnup 2>/dev/null; } | grep -E "[:.]${port}[[:space:]]" || true)" ;;
    esac
    if [[ -n "$output" ]]; then
        printf 'listener check: listening port=%s proto=%s\n' "$port" "$proto"
        printf '%s\n' "$output"
    else
        printf 'listener check: not-listening port=%s proto=%s\n' "$port" "$proto"
    fi
}

print_local_port_conflict() {
    local port="${1:-}"
    if [[ -z "$port" ]]; then
        printf 'LOCAL_PORT conflict: skipped\n'
        return 0
    fi
    if ! command_exists ss; then
        printf 'LOCAL_PORT conflict: skipped reason=ss-unavailable\n'
        return 0
    fi
    if ss -lntup 2>/dev/null | grep -Eq "[:.]${port}[[:space:]]"; then
        printf 'LOCAL_PORT conflict: detected port=%s\n' "$port"
    else
        printf 'LOCAL_PORT conflict: none port=%s\n' "$port"
    fi
}

print_latency_hints() {
    cat <<'EOF'
latency hints:
- ICMP ping 是基础 RTT，不等于业务延迟。
- TCP connect time 只表示 TCP 建连参考，不替代完整业务延迟。
- 如果业务延迟明显高于分段 RTT，可能是 TCP-over-TCP / EasyTier 传输协议选择、业务协议握手、NAT IX 到落地路径绕路、落地服务处理慢、客户端测量完整应用延迟等原因。
- 可新建测试 Profile 对比 EasyTier listener proto：tcp / udp / tcp+udp；不建议直接覆盖生产 Profile，先用新端口做协议 A/B 测试。
EOF
}

latency_report_parse_args() {
    local profile_id="" rule_id="" sample=0
    while (($#)); do
        case "$1" in
            --sample)
                shift
                [[ -n "${1:-}" ]] || die_user "--sample 后面必须跟秒数。"
                sample="$(parse_sample_seconds "$1")" || die_user "--sample 必须是非负整数秒。"
                ;;
            *)
                if [[ -z "$profile_id" ]]; then
                    profile_id="$1"
                elif [[ -z "$rule_id" ]]; then
                    rule_id="$1"
                else
                    die_user "用法：latency-report PROFILE_ID [规则ID] [--sample N]"
                fi
                ;;
        esac
        shift || true
    done
    [[ -n "$profile_id" ]] || die_user "用法：latency-report PROFILE_ID [规则ID] [--sample N]"
    printf '%s\t%s\t%s\n' "$profile_id" "$sample" "$rule_id"
}

print_nat_latency_basic_info() {
    case "${ROLE:-}" in
        nat-ingress)
            printf 'ROLE=%s\n' "${ROLE:-}"
            printf 'NAT_DIRECTION=%s\n' "${NAT_DIRECTION:-ingress-listener}"
            [[ -n "${INGRESS_PUBLIC_HOST:-}" ]] && printf 'INGRESS_PUBLIC_HOST=%s\n' "${INGRESS_PUBLIC_HOST:-}"
            [[ -n "${NAT_PUBLIC_HOST:-}" ]] && printf 'NAT_PUBLIC_HOST=%s\n' "${NAT_PUBLIC_HOST:-}"
            [[ -n "${NAT_LISTENER_PORT:-}" ]] && printf 'NAT_LISTENER_PORT=%s\n' "${NAT_LISTENER_PORT:-}"
            printf 'LOCAL_PORT=%s\n' "${LOCAL_PORT:-}"
            printf 'INGRESS_ET_IP=%s\n' "${INGRESS_ET_IP:-}"
            printf 'NAT_ET_IP=%s\n' "${NAT_ET_IP:-}"
            printf 'TRANSIT_PORT=%s\n' "${TRANSIT_PORT:-}"
            [[ -n "${INGRESS_LISTENER_PORT:-}" ]] && printf 'INGRESS_LISTENER_PORT=%s\n' "${INGRESS_LISTENER_PORT:-}"
            printf 'FORWARD_PROTO=%s\n' "${FORWARD_PROTO:-both}"
            ;;
        nat-transit)
            printf 'ROLE=%s\n' "${ROLE:-}"
            printf 'NAT_DIRECTION=%s\n' "${NAT_DIRECTION:-ingress-listener}"
            [[ -n "${INGRESS_PUBLIC_HOST:-}" ]] && printf 'INGRESS_PUBLIC_HOST=%s\n' "${INGRESS_PUBLIC_HOST:-}"
            [[ -n "${INGRESS_LISTENER_PORT:-}" ]] && printf 'INGRESS_LISTENER_PORT=%s\n' "${INGRESS_LISTENER_PORT:-}"
            [[ -n "${NAT_PUBLIC_HOST:-}" ]] && printf 'NAT_PUBLIC_HOST=%s\n' "${NAT_PUBLIC_HOST:-}"
            [[ -n "${NAT_LISTENER_PORT:-}" ]] && printf 'NAT_LISTENER_PORT=%s\n' "${NAT_LISTENER_PORT:-}"
            printf 'INGRESS_ET_IP=%s\n' "${INGRESS_ET_IP:-}"
            printf 'NAT_ET_IP=%s\n' "${NAT_ET_IP:-}"
            printf 'TRANSIT_PORT=%s\n' "${TRANSIT_PORT:-}"
            printf 'LANDING_HOST=%s\n' "${LANDING_HOST:-}"
            printf 'LANDING_PORT=%s\n' "${LANDING_PORT:-}"
            ;;
    esac
}

print_formal_counter_sample() {
    local sample="${1:-0}" before_text after_text before_packets before_bytes before_state after_packets after_bytes after_state
    local delta_packets delta_bytes
    before_text="$(nft_table_text 2>/dev/null || true)"
    IFS=$'\t' read -r before_packets before_bytes before_state <<<"$(profile_counter_line_from_text "$before_text")"
    if [[ "$sample" =~ ^[0-9]+$ && "$sample" -gt 0 ]]; then
        printf '* nftables 计数器：采样前 packets=%s bytes=%s state=%s\n' "$before_packets" "$before_bytes" "$before_state"
        sleep "$sample"
        after_text="$(nft_table_text 2>/dev/null || true)"
        IFS=$'\t' read -r after_packets after_bytes after_state <<<"$(profile_counter_line_from_text "$after_text")"
        printf '* nftables 计数器：采样后 packets=%s bytes=%s state=%s\n' "$after_packets" "$after_bytes" "$after_state"
        if [[ "$before_packets" =~ ^[0-9]+$ && "$after_packets" =~ ^[0-9]+$ && "$before_bytes" =~ ^[0-9]+$ && "$after_bytes" =~ ^[0-9]+$ ]]; then
            delta_packets=$((after_packets - before_packets))
            delta_bytes=$((after_bytes - before_bytes))
            printf '* sample delta：packets=%s bytes=%s\n' "$delta_packets" "$delta_bytes"
        else
            printf '* sample delta：unavailable\n'
        fi
    else
        printf '* nftables 计数器：packets=%s bytes=%s state=%s\n' "$before_packets" "$before_bytes" "$before_state"
        printf '* sample delta：未采样\n'
    fi
}

formal_nat_latency_report() {
    local profile_id="$1" sample="${2:-0}" rule_filter="${3:-}" peer_ip landing_host landing_port rule_id
    local saved_local="${LOCAL_PORT:-}" saved_transit="${TRANSIT_PORT:-}" saved_landing_host="${LANDING_HOST:-}" saved_landing_port="${LANDING_PORT:-}" saved_proto="${FORWARD_PROTO:-both}"
    printf 'NAT-IX 延迟诊断：%s\n' "$profile_id"

    printf '\n分段 1：公网入口机 -> NAT IX 虚拟 IP\n'
    if [[ "${ROLE:-}" == "nat-ingress" ]]; then
        print_latency_metric "ICMP RTT" "$(ping_summary "${NAT_ET_IP:-}" 5)"
        printf '* TCP 建连耗时：%s\n' "$(tcp_connect_time "${NAT_ET_IP:-}" "${TRANSIT_PORT:-}" 3)"
    else
        peer_ip="${INGRESS_ET_IP:-}"
        print_latency_metric "ICMP RTT（反向参考）" "$(ping_summary "$peer_ip" 5)"
        printf '* TCP 建连耗时：请在公网入口机运行同一命令查看完整方向\n'
    fi

    printf '\n分段 2：NAT IX 机器 -> 落地机\n'
    if [[ "${ROLE:-}" == "nat-transit" ]]; then
        for rule_id in $(profile_rule_ids "$profile_id"); do
            [[ -z "$rule_filter" || "$rule_id" == "$rule_filter" ]] || continue
            load_rule "$profile_id" "$rule_id" || continue
            [[ "${RULE_ENABLED:-true}" == "true" ]] || continue
            landing_host="${LANDING_HOST:-}"
            landing_port="${LANDING_PORT:-}"
            printf '* 规则 %s [%s]：%s:%s\n' "$rule_id" "${RULE_NOTE:-}" "$landing_host" "$landing_port"
            print_latency_metric "  ICMP RTT" "$(ping_summary "$landing_host" 5)"
            printf '  TCP connect time：%s\n' "$(tcp_connect_time "$landing_host" "$landing_port" 3)"
        done
    else
        printf '* ICMP RTT：请在 NAT IX 机器运行同一命令查看\n'
        printf '* TCP connect time：请在 NAT IX 机器运行同一命令查看\n'
    fi

    printf '\n分段 3：客户端流量命中\n'
    print_formal_counter_sample "$sample"

    cat <<'EOF'

提示：
客户端显示的节点延迟可能包含代理协议握手、TLS/REALITY、重传和应用处理，不等同于 ping。
EOF
    LOCAL_PORT="$saved_local"; TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
}

print_forward_rule_health_summary() {
    local profile_id="$1" text rule_id total=0 enabled=0 disabled=0 abnormal=0 packets bytes state target nc_cmd tcp_state
    local saved_local="${LOCAL_PORT:-}" saved_transit="${TRANSIT_PORT:-}" saved_landing_host="${LANDING_HOST:-}" saved_landing_port="${LANDING_PORT:-}" saved_proto="${FORWARD_PROTO:-both}"
    text="$(nft_table_text 2>/dev/null || true)"
    printf '\n转发规则：\n'
    for rule_id in $(profile_rule_ids "$profile_id"); do
        load_rule "$profile_id" "$rule_id" || continue
        total=$((total + 1))
        if [[ "${RULE_ENABLED:-true}" == "true" ]]; then
            enabled=$((enabled + 1))
        else
            disabled=$((disabled + 1))
            printf '* %s [%s] %s\n' "$rule_id" "$(rule_note_display)" "$(profile_rule_status_display)"
            printf '  状态：已停止，不参与转发。\n'
            continue
        fi
        target="$(profile_rule_path_display)"
        IFS=$'\t' read -r packets bytes state <<<"$(profile_rule_counter_from_text "$text")"
        tcp_state="未探测"
        if [[ "${FORWARD_PROTO:-both}" != "udp" ]]; then
            case "${ROLE:-}" in
                nat-transit)
                    if nc_cmd="$(detect_nc_cmd 2>/dev/null)" && "$nc_cmd" -vz -w 3 "${LANDING_HOST:-}" "${LANDING_PORT:-}" >/dev/null 2>&1; then
                        tcp_state="可达"
                    else
                        tcp_state="不可达"
                        abnormal=$((abnormal + 1))
                    fi
                    ;;
                nat-ingress)
                    if nc_cmd="$(detect_nc_cmd 2>/dev/null)" && "$nc_cmd" -vz -w 3 "${NAT_ET_IP:-}" "${TRANSIT_PORT:-}" >/dev/null 2>&1; then
                        tcp_state="可达"
                    else
                        tcp_state="不可达"
                        abnormal=$((abnormal + 1))
                    fi
                    ;;
            esac
        fi
        printf '* %s [%s] %s\n' "$rule_id" "$(rule_note_display)" "$(profile_rule_status_display)"
        printf '  完整路径：%s\n' "$target"
        printf '  nftables 规则：%s\n' "$(nft_rule_state_display "$state")"
        printf '  落地 TCP 可达：%s\n' "$tcp_state"
        printf '  流量计数器：数据包=%s 字节=%s\n' "$packets" "$bytes"
    done
    printf '\n规则汇总：总规则数=%s 启用规则数=%s 停止规则数=%s 异常规则数=%s\n' "$total" "$enabled" "$disabled" "$abnormal"
    if [[ "$enabled" -gt 0 && "$abnormal" -gt 0 && "$abnormal" -lt "$enabled" ]]; then
        health_mark warning "部分转发规则异常"
    elif [[ "$enabled" -gt 0 && "$abnormal" -ge "$enabled" ]]; then
        health_mark down "所有启用转发规则异常"
    fi
    LOCAL_PORT="$saved_local"; TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
}

profile_enabled_rule_count() {
    local profile_id="$1" rule_id count=0
    local saved_rule_id="${RULE_ID:-}" saved_note="${RULE_NOTE:-}" saved_enabled="${RULE_ENABLED:-}" saved_client="${CLIENT_PORT:-}" saved_nat_public="${NAT_PUBLIC_PORT:-}"
    local saved_transit="${TRANSIT_PORT:-}" saved_landing_host="${LANDING_HOST:-}" saved_landing_port="${LANDING_PORT:-}" saved_proto="${FORWARD_PROTO:-both}"
    for rule_id in $(profile_rule_ids "$profile_id"); do
        load_rule "$profile_id" "$rule_id" || continue
        [[ "${RULE_ENABLED:-true}" == "true" ]] && count=$((count + 1))
    done
    RULE_ID="$saved_rule_id"; RULE_NOTE="$saved_note"; RULE_ENABLED="$saved_enabled"; CLIENT_PORT="$saved_client"; NAT_PUBLIC_PORT="$saved_nat_public"
    TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
    printf '%s\n' "$count"
}

print_nat_transit_local_listener_health() {
    local profile_id="$1" rule_id nat_port rc ok=0 bad=0 total=0
    local saved_rule_id="${RULE_ID:-}" saved_note="${RULE_NOTE:-}" saved_enabled="${RULE_ENABLED:-}" saved_client="${CLIENT_PORT:-}" saved_nat_public="${NAT_PUBLIC_PORT:-}"
    local saved_transit="${TRANSIT_PORT:-}" saved_landing_host="${LANDING_HOST:-}" saved_landing_port="${LANDING_PORT:-}" saved_proto="${FORWARD_PROTO:-both}"
    local proto="${NAT_LISTENER_PROTO:-${ET_LISTENER_PROTO:-both}}"
    for rule_id in $(profile_rule_ids "$profile_id"); do
        load_rule "$profile_id" "$rule_id" || continue
        [[ "${RULE_ENABLED:-true}" == "true" ]] || continue
        nat_port="$(rule_nat_public_port_value 2>/dev/null || true)"
        [[ -n "$nat_port" ]] || continue
        total=$((total + 1))
        set +e
        check_listener_proto_port "$proto" "$nat_port"
        rc=$?
        set -e
        case "$rc" in
            0)
                ok=$((ok + 1))
                printf '* [%s] 商家入口 %s：监听正常\n' "$rule_id" "$nat_port"
                ;;
            2)
                printf '* [%s] 商家入口 %s：无法检查\n' "$rule_id" "$nat_port"
                health_mark warning "无法检查商家入口监听"
                ;;
            *)
                bad=$((bad + 1))
                printf '* [%s] 商家入口 %s：未检测到监听\n' "$rule_id" "$nat_port"
                ;;
        esac
    done
    if [[ "$total" -eq 0 ]]; then
        printf '* 商家入口监听：无启用规则\n'
        health_mark down "无启用转发规则"
    elif [[ "$bad" -gt 0 && "$bad" -ge "$total" ]]; then
        health_mark down "所有商家入口均未监听"
    elif [[ "$bad" -gt 0 ]]; then
        health_mark warning "部分商家入口未监听"
    else
        printf '* 商家入口监听汇总：%s/%s 正常\n' "$ok" "$total"
    fi
    RULE_ID="$saved_rule_id"; RULE_NOTE="$saved_note"; RULE_ENABLED="$saved_enabled"; CLIENT_PORT="$saved_client"; NAT_PUBLIC_PORT="$saved_nat_public"
    TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
}

print_nat_ingress_nat_peer_health() {
    local profile_id="$1" rule_id nat_port nc_cmd reachable=0 bad=0 total=0 host="${NAT_PUBLIC_HOST:-}"
    local saved_rule_id="${RULE_ID:-}" saved_note="${RULE_NOTE:-}" saved_enabled="${RULE_ENABLED:-}" saved_client="${CLIENT_PORT:-}" saved_nat_public="${NAT_PUBLIC_PORT:-}"
    local saved_transit="${TRANSIT_PORT:-}" saved_landing_host="${LANDING_HOST:-}" saved_landing_port="${LANDING_PORT:-}" saved_proto="${FORWARD_PROTO:-both}"
    [[ -n "$host" ]] || {
        printf '* 商家 NAT/IX 入口：未配置\n'
        health_mark down "商家入口未配置"
        RULE_ID="$saved_rule_id"; RULE_NOTE="$saved_note"; RULE_ENABLED="$saved_enabled"; CLIENT_PORT="$saved_client"; NAT_PUBLIC_PORT="$saved_nat_public"
        TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
        return 0
    }
    nc_cmd="$(detect_nc_cmd 2>/dev/null || true)"
    for rule_id in $(profile_rule_ids "$profile_id"); do
        load_rule "$profile_id" "$rule_id" || continue
        [[ "${RULE_ENABLED:-true}" == "true" ]] || continue
        nat_port="$(rule_nat_public_port_value 2>/dev/null || true)"
        [[ -n "$nat_port" ]] || continue
        total=$((total + 1))
        if [[ -n "$nc_cmd" && "${NAT_LISTENER_PROTO:-both}" != "udp" ]]; then
            if "$nc_cmd" -vz -w 3 "$host" "$nat_port" >/dev/null 2>&1; then
                reachable=$((reachable + 1))
                printf '* [%s] 商家入口 %s:%s：可达\n' "$rule_id" "$host" "$nat_port"
            else
                bad=$((bad + 1))
                printf '* [%s] 商家入口 %s:%s：不可达\n' "$rule_id" "$host" "$nat_port"
            fi
        elif et_peer_contains_port "$nat_port"; then
            reachable=$((reachable + 1))
            printf '* [%s] 商家入口 %s:%s：已配置 peer\n' "$rule_id" "$host" "$nat_port"
        else
            bad=$((bad + 1))
            printf '* [%s] 商家入口 %s:%s：EasyTier peer 未包含该端口\n' "$rule_id" "$host" "$nat_port"
        fi
    done
    if [[ "$total" -eq 0 ]]; then
        printf '* 商家 NAT/IX 入口：无启用规则\n'
        health_mark down "无启用转发规则"
    elif [[ "$bad" -gt 0 && "$bad" -ge "$total" ]]; then
        health_mark warning "所有商家入口均不可达或未配置 peer"
    elif [[ "$bad" -gt 0 ]]; then
        health_mark warning "部分商家入口不可达或未配置 peer"
    else
        printf '* 商家入口汇总：%s/%s 正常\n' "$reachable" "$total"
    fi
    RULE_ID="$saved_rule_id"; RULE_NOTE="$saved_note"; RULE_ENABLED="$saved_enabled"; CLIENT_PORT="$saved_client"; NAT_PUBLIC_PORT="$saved_nat_public"
    TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
}

latency_report() {
    require_root "$@"
    local parsed profile_id sample rule_id metric
    local args=("$@")
    if [[ ${#args[@]} -eq 0 || -z "${args[0]:-}" ]]; then
        if ! profile_id="$(resolve_profile_id_for_cmd "" latency-report)"; then
            return_or_exit 2 || return $?
        fi
        args=("$profile_id" "${args[@]:1}")
    fi
    parsed="$(latency_report_parse_args "${args[@]}")" || return $?
    IFS=$'\t' read -r profile_id sample rule_id <<<"$parsed"
    load_profile_or_die "$profile_id"
    case "${ROLE:-}" in
        nat-ingress|nat-transit) ;;
        *) die_user "latency-report 仅支持 NAT-IX Profile（nat-ingress / nat-transit）。当前 ROLE=${ROLE:-unknown}" ;;
    esac
    normalize_profile_compat_vars
    if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
        formal_nat_latency_report "$profile_id" "$sample" "$rule_id"
        return 0
    fi
    printf 'NAT-IX latency-report: %s\n' "$profile_id"
    printf 'read-only: no switching, no service restart, no nftables apply\n'
    if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
        printf '当前连接方向：NAT IX 机器监听，公网入口机连接 NAT IX。\n'
        printf '这与 Realm-xwPF 服务端模式接近。\n'
    else
        printf '当前连接方向：公网入口机 listener，NAT IX 机器 peer to ingress。\n'
    fi

    printf '\n===== 线路基本信息 =====\n'
    print_nat_latency_basic_info

    printf '\n===== EasyTier 本机状态 =====\n'
    show_easytier_status "$profile_id" || true

    case "${ROLE:-}" in
        nat-ingress)
            printf '\n===== EasyTier 组网延迟 =====\n'
            metric="$(ping_summary "${NAT_ET_IP:-}" 5)"
            print_latency_metric "ping NAT_ET_IP (${NAT_ET_IP:-})" "$metric"
            if [[ "$metric" == *"loss=100%"* || "$metric" == *"loss=unknown"* || "$metric" == skipped* ]]; then
                printf 'warning: ICMP ping 不通可能是被屏蔽，不直接判失败。\n'
            fi
            printf 'tcp NAT_ET_IP:TRANSIT_PORT (%s:%s): %s\n' "${NAT_ET_IP:-}" "${TRANSIT_PORT:-}" "$(tcp_connect_time "${NAT_ET_IP:-}" "${TRANSIT_PORT:-}" 3)"

            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                printf '\n===== 商家入口可达性 =====\n'
                printf 'tcp NAT_PUBLIC_HOST:NAT_LISTENER_PORT (%s:%s): %s\n' "${NAT_PUBLIC_HOST:-}" "${NAT_LISTENER_PORT:-}" "$(tcp_connect_time "${NAT_PUBLIC_HOST:-}" "${NAT_LISTENER_PORT:-}" 3)"
                printf 'EasyTier peer target: %s\n' "${ET_PEERS:-}"
            else
                printf '\n===== 入口公网 listener 可达性 =====\n'
                print_listener_check "${INGRESS_LISTENER_PORT:-}" "${INGRESS_LISTENER_PROTO:-both}"
                if [[ "${INGRESS_LISTENER_PROTO:-both}" != "udp" ]]; then
                    printf 'tcp 127.0.0.1:INGRESS_LISTENER_PORT reference: %s\n' "$(tcp_connect_time 127.0.0.1 "${INGRESS_LISTENER_PORT:-}" 2)"
                fi
            fi

            printf '\n===== 业务入口端口 LOCAL_PORT =====\n'
            print_local_port_conflict "${LOCAL_PORT:-}"
            printf 'nftables rule: %s\n' "$(nft_profile_rule_status "$profile_id")"
            print_profile_counter_sample "$sample"
            ;;
        nat-transit)
            printf '\n===== EasyTier 组网延迟 =====\n'
            metric="$(ping_summary "${INGRESS_ET_IP:-}" 5)"
            print_latency_metric "ping INGRESS_ET_IP (${INGRESS_ET_IP:-})" "$metric"
            if [[ "$metric" == *"loss=100%"* || "$metric" == *"loss=unknown"* || "$metric" == skipped* ]]; then
                printf 'warning: ICMP ping 不通但 route/peer 可能存在；不单独判失败。\n'
            fi
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                printf '\n===== NAT IX 监听本机检查 =====\n'
                print_listener_check "${NAT_LISTENER_PORT:-}" "${NAT_LISTENER_PROTO:-both}"
                if [[ "${NAT_LISTENER_PROTO:-both}" != "udp" ]]; then
                    printf 'tcp 127.0.0.1:NAT_LISTENER_PORT reference: %s\n' "$(tcp_connect_time 127.0.0.1 "${NAT_LISTENER_PORT:-}" 2)"
                fi
                printf 'tcp NAT_PUBLIC_HOST:NAT_LISTENER_PORT (%s:%s): %s\n' "${NAT_PUBLIC_HOST:-}" "${NAT_LISTENER_PORT:-}" "$(tcp_connect_time "${NAT_PUBLIC_HOST:-}" "${NAT_LISTENER_PORT:-}" 3)"
            else
                printf 'tcp INGRESS_PUBLIC_HOST:INGRESS_LISTENER_PORT (%s:%s): %s\n' "${INGRESS_PUBLIC_HOST:-}" "${INGRESS_LISTENER_PORT:-}" "$(tcp_connect_time "${INGRESS_PUBLIC_HOST:-}" "${INGRESS_LISTENER_PORT:-}" 3)"
            fi

            printf '\n===== NAT IX 到落地延迟 =====\n'
            print_latency_metric "ping LANDING_HOST (${LANDING_HOST:-})" "$(ping_summary "${LANDING_HOST:-}" 5)"
            printf 'tcp LANDING_HOST:LANDING_PORT (%s:%s): %s\n' "${LANDING_HOST:-}" "${LANDING_PORT:-}" "$(tcp_connect_time "${LANDING_HOST:-}" "${LANDING_PORT:-}" 3)"
            if command_exists mtr; then
                printf 'mtr hint: mtr -rwzc 20 %s\n' "${LANDING_HOST:-LANDING_HOST}"
            else
                printf 'mtr hint: install mtr if you need route detail, then run: mtr -rwzc 20 %s\n' "${LANDING_HOST:-LANDING_HOST}"
            fi

            printf '\n===== nftables 转发 =====\n'
            printf 'verify-nft-profiles status: %s\n' "$(nft_forwarding_verify_status)"
            printf 'nftables rule: %s\n' "$(nft_profile_rule_status "$profile_id")"
            print_profile_counter_sample "$sample"

            printf '\n===== NAT_ET_IP:TRANSIT_PORT 本机自测说明 =====\n'
            printf 'NAT IX 本机直连 NAT_ET_IP:TRANSIT_PORT 可能不命中 PREROUTING DNAT，失败不代表入口侧流量失败。\n'
            printf '这个测试不作为核心失败项；请结合入口侧 traffic-report --sample N 与客户端业务连接判断。\n'
            ;;
    esac

    printf '\n===== 延迟判断提示 =====\n'
    print_latency_hints
}

nat_latency() {
    latency_report "$@"
}

latency_all() {
    require_root "$@"
    local sample=0 id found=0
    while (($#)); do
        case "$1" in
            --sample)
                shift
                [[ -n "${1:-}" ]] || die_user "--sample 后面必须跟秒数。"
                sample="$(parse_sample_seconds "$1")" || die_user "--sample 必须是非负整数秒。"
                ;;
            *) die_user "用法：latency-all [--sample N]" ;;
        esac
        shift || true
    done
    for id in $(sorted_profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        case "${ROLE:-}" in nat-ingress|nat-transit) ;; *) continue ;; esac
        found=1
        printf '\n===== 线路 %s =====\n' "$id"
        latency_report "$id" --sample "$sample" || true
    done
    [[ "$found" -eq 1 ]] || printf '未找到 NAT-IX Profile。\n'
}

run_formal_nat_health_check() {
    local profile_id="$1" write_back="${2:-false}" service active rc nft_label nc_cmd now
    local route_target="" tcp_target_host="" tcp_target_port="" counter_state counter_packets counter_bytes

    service="$(profile_service_name "$profile_id")"
    _IXTF_HEALTH_STATUS="healthy"
    _IXTF_HEALTH_REASON=""

    printf '线路健康检查：%s\n' "$profile_id"

    printf '\n基础状态：\n'
    if ( validate_profile_config "$profile_id" ) >/dev/null 2>&1; then
        printf '* 配置文件：存在\n'
    else
        printf '* 配置文件：不完整\n'
        health_mark down "配置文件不完整"
    fi

    active="$(profile_service_status "$service")"
    case "$active" in
        active) printf '* 服务状态：运行中\n' ;;
        unknown) printf '* 服务状态：无法检查\n'; health_mark warning "无法检查 systemd 服务状态" ;;
        *) printf '* 服务状态：%s\n' "$active"; health_mark down "服务未运行" ;;
    esac

    if check_easytier_process; then
        printf '* EasyTier 进程：存在\n'
    else
        printf '* EasyTier 进程：未检测到\n'
        health_mark down "EasyTier 进程不存在"
    fi

    set +e
    assess_et_ip_health
    rc=$?
    set -e
    printf '* 本机虚拟 IP：%s' "$(et_ip_health_label "$rc")"
    apply_et_ip_health_mark "$rc"

    printf '\n转发状态：\n'
    nft_label="$(nft_profile_rule_status "$profile_id")"
    case "$nft_label" in
        present) printf '* nftables 规则：正常\n' ;;
        missing) printf '* nftables 规则：缺失\n'; health_mark down "nftables 规则缺失" ;;
        unknown) printf '* nftables 规则：无法检查\n'; health_mark warning "无法检查 nftables 规则" ;;
        skipped) printf '* nftables 规则：跳过\n' ;;
        *) printf '* nftables 规则：%s\n' "$nft_label" ;;
    esac

    case "${ROLE:-}" in
        nat-transit)
            print_nat_transit_local_listener_health "$profile_id"

            route_target="${INGRESS_ET_IP:-}"
            if command_exists ip && [[ -n "$route_target" ]]; then
                if ip route get "$route_target" >/dev/null 2>&1; then
                    printf '* 公网入口虚拟网：路由已建立（%s）\n' "$route_target"
                else
                    printf '* 公网入口虚拟网：等待公网入口机接入（%s）\n' "$route_target"
                    health_mark warning "公网入口机尚未接入或路由未建立"
                fi
            else
                printf '* 公网入口虚拟网：无法检查\n'
                health_mark warning "无法检查公网入口虚拟网"
            fi
            ;;
        nat-ingress)
            print_nat_ingress_nat_peer_health "$profile_id"
            ;;
    esac

    enabled_rules="$(profile_enabled_rule_count "$profile_id")"
    if [[ "${enabled_rules:-0}" -gt 1 ]]; then
        printf '* 落地服务：%s 条启用规则，详见下方「转发规则」\n' "$enabled_rules"
    elif [[ "${ROLE:-}" == "nat-transit" && -n "${LANDING_HOST:-}" && -n "${LANDING_PORT:-}" ]]; then
        if nc_cmd="$(detect_nc_cmd 2>/dev/null)" && [[ "${FORWARD_PROTO:-both}" != "udp" ]]; then
            if "$nc_cmd" -vz -w 3 "${LANDING_HOST:-}" "${LANDING_PORT:-}" >/dev/null 2>&1; then
                printf '* 落地服务：可达\n'
            else
                printf '* 落地服务：不可达\n'
                health_mark warning "落地服务 TCP 探测失败"
            fi
        else
            printf '* 落地服务：已配置\n'
        fi
    elif [[ "${ROLE:-}" == "nat-ingress" && -n "${NAT_ET_IP:-}" && -n "${TRANSIT_PORT:-}" ]]; then
        if nc_cmd="$(detect_nc_cmd 2>/dev/null)" && [[ "${FORWARD_PROTO:-both}" != "udp" ]]; then
            if "$nc_cmd" -vz -w 3 "${NAT_ET_IP:-}" "${TRANSIT_PORT:-}" >/dev/null 2>&1; then
                printf '* 虚拟网中转：可达\n'
            else
                printf '* 虚拟网中转：不可达\n'
                health_mark warning "虚拟网中转 TCP 探测失败"
            fi
        else
            printf '* 虚拟网中转：已配置\n'
        fi
    else
        printf '* 落地/中转：未配置或详见下方「转发规则」\n'
    fi

    IFS=$'\t' read -r counter_state counter_packets counter_bytes <<<"$(profile_counter_health_status)"
    case "$counter_state" in
        hit) printf '* 客户端流量命中：有（packets=%s bytes=%s）\n' "$counter_packets" "$counter_bytes" ;;
        readable) printf '* 客户端流量命中：等待流量\n' ;;
        unavailable) printf '* 客户端流量命中：无法读取\n' ;;
        *) printf '* 客户端流量命中：未找到计数器\n' ;;
    esac

    print_forward_rule_health_summary "$profile_id"

    [[ -n "$_IXTF_HEALTH_REASON" ]] || _IXTF_HEALTH_REASON="检查通过"
    printf '\n结果：\n'
    printf 'HEALTH_STATUS=%s\n' "$_IXTF_HEALTH_STATUS"
    printf '说明：%s\n' "$_IXTF_HEALTH_REASON"
    printf '\n高级详情：\n'
    printf 'bash install.sh export-diagnostic\n'
    printf 'bash install.sh show-config %s\n' "$profile_id"

    if [[ "$write_back" == "true" ]]; then
        now="$(utc_now)"
        HEALTH_STATUS="$_IXTF_HEALTH_STATUS"
        LAST_HEALTH_REASON="$_IXTF_HEALTH_REASON"
        LAST_HEALTH_CHECK_AT="$now"
        if ( validate_profile_config "$profile_id" ) >/dev/null 2>&1; then
            if ! save_profile_runtime_state "$profile_id"; then
                save_profile_env "$profile_id"
            fi
        fi
    fi
}

run_line_health_check() {
    local profile_id="$1" write_back="${2:-false}" service active rc nft_label tcp_needed="false" nc_cmd business_port
    local saved_status saved_reason now role_text line_role_text
    require_root "$@"
    if ! profile_id="$(resolve_profile_id_for_cmd "$profile_id" health)"; then
        return_or_exit 2 || return $?
    fi
    if ! load_profile "$profile_id"; then
        print_profile_selection_hint "$profile_id" health
        return_or_exit 2 || return $?
    fi
    normalize_profile_compat_vars
    case "${ROLE:-}" in
        nat-ingress) role_text="公网入口线路" ;;
        nat-transit) role_text="NAT IX 中转线路" ;;
        *) role_text="${ROLE:-未知}" ;;
    esac
    case "${LINE_ROLE:-standalone}" in
        primary) line_role_text="主线路" ;;
        backup) line_role_text="备用线路" ;;
        standalone) line_role_text="独立线路" ;;
        *) line_role_text="${LINE_ROLE:-独立线路}" ;;
    esac
    if [[ ( "${ROLE:-}" == "nat-ingress" || "${ROLE:-}" == "nat-transit" ) && "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
        run_formal_nat_health_check "$profile_id" "$write_back"
        return 0
    fi
    service="$(profile_service_name "$profile_id")"
    _IXTF_HEALTH_STATUS="healthy"
    _IXTF_HEALTH_REASON=""

    printf '线路健康检查：%s\n' "$profile_id"
    health_line "线路配置" "存在"
    health_line "线路类型" "$role_text"
    health_line "线路分组" "${LINE_GROUP:-未分组}"
    health_line "主备角色" "$line_role_text"
    health_line "优先级" "${LINE_PRIORITY:-100}"
    health_line "启用状态" "$([[ "${ENABLED:-true}" == "true" ]] && printf 已启用 || printf 已停用)"
    health_line "业务转发" "$([[ "${FORWARD_ENABLED:-true}" == "true" ]] && printf 已启用 || printf 未启用)"

    if ! ( validate_profile_config "$profile_id" ) >/dev/null 2>&1; then
        health_line "配置校验" "失败"
        health_mark down "线路配置不完整"
    else
        health_line "配置校验" "通过"
    fi

    if [[ "${ENABLED:-true}" != "true" ]]; then
        health_line "启用状态" "已停用"
        health_mark warning "线路已停用"
    fi

    active="$(profile_service_status "$service")"
    health_line "systemd 实例" "${service} / ${active}"
    if [[ "$active" == "active" ]]; then
        :
    elif [[ "$active" == "unknown" ]]; then
        health_mark warning "无法检查 systemd"
    else
        health_mark down "线路服务未运行：${active}"
    fi

    if check_easytier_process; then
        health_line "easytier-core 进程" "存在"
    else
        health_line "easytier-core 进程" "未检测到"
        health_mark down "easytier-core 进程不存在"
    fi

    set +e
    assess_et_ip_health
    rc=$?
    set -e
    case "$rc" in
        0) health_line "本机虚拟 IP" "存在" ;;
        3) health_line "本机虚拟 IP" "未挂网卡但虚拟网可用" ;;
        2) health_line "本机虚拟 IP" "无法检查（ip 命令不可用）" ;;
        *) health_line "本机虚拟 IP" "不存在" ;;
    esac
    apply_et_ip_health_mark "$rc"

    if profile_port_map_complete; then
        health_line "四端口信息" "完整"
    else
        health_line "四端口信息" "不完整"
        health_mark down "show-port-map 信息不完整"
    fi

    nft_label="$(nft_profile_rule_status "$profile_id")"
    health_line "nftables 规则" "$nft_label"
    if profile_needs_nft_forward; then
        case "$nft_label" in
            present) ;;
            missing) health_mark down "nftables 缺少转发规则" ;;
            unknown) health_mark warning "无法检查 nftables 项目表" ;;
            skipped) ;;
        esac
    fi

    case "${ROLE:-}" in
        nat-transit)
            health_line "CNIX 面板出口端口" "${LISTENER_PORT:-${ET_LISTENER_PORT:-未配置}}"
            set +e
            check_listener_proto_port "${ET_LISTENER_PROTO:-tcp}" "${ET_LISTENER_PORT:-${LISTENER_PORT:-0}}"
            rc=$?
            set -e
            case "$rc" in
                0) health_line "listener 监听" "已检测到" ;;
                2) health_line "listener 监听" "无法检查（ss 命令不可用）"; health_mark warning "无法检查 listener" ;;
                *) health_line "listener 监听" "未检测到"; health_mark down "listener 未监听" ;;
            esac
            set +e
            profile_service_owns_port "$service" "${ET_LISTENER_PROTO:-tcp}" "${ET_LISTENER_PORT:-${LISTENER_PORT:-0}}"
            rc=$?
            set -e
            case "$rc" in
                0) health_line "listener 归属" "本项目线路服务" ;;
                1) health_line "listener 归属" "不是本项目线路服务"; health_mark warning "listener 端口可能被其他进程占用" ;;
                *)
                    set +e
                    port_owner_has_easytier "${ET_LISTENER_PROTO:-tcp}" "${ET_LISTENER_PORT:-${LISTENER_PORT:-0}}"
                    rc=$?
                    set -e
                    case "$rc" in
                        0) health_line "listener 归属" "疑似 easytier-core" ;;
                        2) health_line "listener 归属" "无法检查" ;;
                        3) health_line "listener 归属" "不是 easytier-core 或无法确认"; health_mark warning "listener 端口可能被其他进程占用" ;;
                    esac
                    ;;
            esac
            if [[ -n "${SERVICE_PORT:-}" ]]; then
                if command_exists ss; then
                    if ss -lntup 2>/dev/null | grep -Eq "[:.]${SERVICE_PORT}[[:space:]]"; then
                        health_line "业务端口监听" "已检测到（${SERVICE_PORT}）"
                    else
                        health_line "业务端口监听" "未检测到（${SERVICE_PORT}）"
                        health_mark warning "业务端口未监听"
                    fi
                else
                    health_line "业务端口监听" "无法检查"
                    health_mark warning "无法检查业务端口"
                fi
            fi
            ;;
        nat-ingress)
            if [[ -n "${ET_PEERS:-}" ]]; then
                health_line "EasyTier peers" "存在"
            else
                health_line "EasyTier peers" "不存在"
                health_mark down "EasyTier peer 不存在"
            fi
            if command_exists ip && [[ -n "${LANDING_ET_IP:-}" ]]; then
                if ip route get "$LANDING_ET_IP" >/dev/null 2>&1; then
                    health_line "落地机虚拟 IP 路由" "存在"
                else
                    health_line "落地机虚拟 IP 路由" "未找到"
                    health_mark warning "到落地机虚拟 IP 的路由未确认"
                fi
            else
                health_line "落地机虚拟 IP 路由" "无法检查"
                health_mark warning "无法检查落地机虚拟 IP 路由"
            fi
            if command_exists ping && [[ -n "${LANDING_ET_IP:-}" ]]; then
                if ping -c 1 -W 3 "$LANDING_ET_IP" >/dev/null 2>&1; then
                    health_line "落地机虚拟 IP ping" "成功"
                else
                    health_line "落地机虚拟 IP ping" "失败"
                    health_mark down "ping 落地机虚拟 IP 失败"
                fi
            else
                health_line "落地机虚拟 IP ping" "跳过"
            fi
            [[ "${FORWARD_PROTO:-both}" == "tcp" || "${FORWARD_PROTO:-both}" == "both" ]] && tcp_needed="true"
            if [[ "$tcp_needed" == "true" && -n "${LANDING_ET_IP:-}" && -n "${REMOTE_PORT:-}" ]]; then
                if nc_cmd="$(detect_nc_cmd 2>/dev/null)"; then
                    if "$nc_cmd" -vz -w 3 "$LANDING_ET_IP" "$REMOTE_PORT" >/dev/null 2>&1; then
                        health_line "落地机业务 TCP" "可达"
                    else
                        health_line "落地机业务 TCP" "不可达"
                        health_mark warning "TCP 业务探测失败"
                    fi
                else
                    health_line "落地机业务 TCP" "nc 不可用"
                    suggest_install_nc | sed 's/^/  /'
                    health_mark warning "nc 不可用，跳过 TCP 业务端口探测"
                fi
            fi
            if [[ "${FORWARD_PROTO:-both}" == "udp" || "${FORWARD_PROTO:-both}" == "both" ]]; then
                health_line "UDP 探测" "跳过（UDP 不可靠）"
            fi
            if [[ "${FORWARD_ENABLED:-true}" == "true" && -n "${LOCAL_PORT:-}" ]] && command_exists ss; then
                if ss -lntup 2>/dev/null | grep -Eq "[:.]${LOCAL_PORT}[[:space:]]"; then
                    health_line "入口端口本机监听冲突" "检测到"
                    health_mark warning "入口端口被本机进程监听"
                else
                    health_line "入口端口本机监听冲突" "未检测到"
                fi
            fi
            if [[ -n "${CNIX_ENTRY_HOST:-}" && -n "${CNIX_ENTRY_PORT:-}" ]]; then
                if [[ "${CNIX_ENTRY_PROTO:-both}" == "tcp" || "${CNIX_ENTRY_PROTO:-both}" == "both" ]]; then
                    if nc_cmd="$(detect_nc_cmd 2>/dev/null)"; then
                        if "$nc_cmd" -vz -w 3 "$CNIX_ENTRY_HOST" "$CNIX_ENTRY_PORT" >/dev/null 2>&1; then
                            health_line "CNIX TCP 可达性" "可达"
                        else
                            health_line "CNIX TCP 可达性" "不可达"
                            health_mark warning "CNIX TCP 探测失败"
                        fi
                    else
                        health_line "CNIX TCP 可达性" "nc 不可用"
                        health_mark warning "nc 不可用，跳过 CNIX TCP 探测"
                    fi
                fi
                if [[ "${CNIX_ENTRY_PROTO:-both}" == "udp" || "${CNIX_ENTRY_PROTO:-both}" == "both" ]]; then
                    health_line "CNIX UDP 探测" "跳过（UDP 不可靠）"
                fi
            fi
            ;;
        nat-ingress)
            local nat_route_ok="false" nat_tcp_ok="false" nat_counter_state nat_counter_packets nat_counter_bytes
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                if [[ -n "${ET_PEERS:-}" ]]; then
                    health_line "连接 NAT IX" "存在（${NAT_PUBLIC_HOST:-}:${NAT_LISTENER_PORT:-}）"
                else
                    health_line "连接 NAT IX" "不存在"
                    health_mark down "EasyTier peer 不存在"
                fi
                if [[ -n "${NAT_PUBLIC_HOST:-}" && -n "${NAT_LISTENER_PORT:-}" ]]; then
                    if [[ "${NAT_LISTENER_PROTO:-both}" == "tcp" || "${NAT_LISTENER_PROTO:-both}" == "both" ]]; then
                        if nc_cmd="$(detect_nc_cmd 2>/dev/null)"; then
                            if "$nc_cmd" -vz -w 3 "$NAT_PUBLIC_HOST" "$NAT_LISTENER_PORT" >/dev/null 2>&1; then
                                health_line "商家入口 TCP" "可达"
                            else
                                health_line "商家入口 TCP" "不可达"
                                health_mark warning "NAT IX 监听 TCP 探测失败；请检查商家入口端口和 NAT IX 机器监听。"
                            fi
                        else
                            health_line "商家入口 TCP" "nc 不可用"
                            health_mark warning "nc 不可用，跳过 NAT IX 监听 TCP 探测"
                        fi
                    fi
                    if [[ "${NAT_LISTENER_PROTO:-both}" == "udp" || "${NAT_LISTENER_PROTO:-both}" == "both" ]]; then
                        health_line "NAT IX 监听 UDP 探测" "跳过（UDP 不可靠）"
                    fi
                fi
                if command_exists ip && [[ -n "${NAT_ET_IP:-}" ]]; then
                    if ip route get "$NAT_ET_IP" >/dev/null 2>&1; then
                        health_line "NAT IX 虚拟 IP 路由" "存在"
                        nat_route_ok="true"
                    else
                        health_line "NAT IX 虚拟 IP 路由" "未找到"
                        health_mark warning "到 NAT IX 虚拟 IP 的 route/peer 未确认"
                    fi
                else
                    health_line "NAT IX 虚拟 IP 路由" "无法检查"
                    health_mark warning "无法检查 NAT IX 虚拟 IP 路由"
                fi
                if command_exists ping && [[ -n "${NAT_ET_IP:-}" ]]; then
                    if ping -c 1 -W 3 "$NAT_ET_IP" >/dev/null 2>&1; then
                        health_line "NAT IX 虚拟 IP ping" "成功"
                    else
                        health_line "NAT IX 虚拟 IP ping" "ICMP ping 不通不单独判失败"
                    fi
                else
                    health_line "NAT IX 虚拟 IP ping" "跳过"
                fi
                [[ "${FORWARD_PROTO:-both}" == "tcp" || "${FORWARD_PROTO:-both}" == "both" ]] && tcp_needed="true"
                if [[ "$tcp_needed" == "true" && -n "${NAT_ET_IP:-}" && -n "${TRANSIT_PORT:-}" ]]; then
                    if nc_cmd="$(detect_nc_cmd 2>/dev/null)"; then
                        if "$nc_cmd" -vz -w 3 "$NAT_ET_IP" "$TRANSIT_PORT" >/dev/null 2>&1; then
                            health_line "虚拟网中转 TCP" "可达"
                            nat_tcp_ok="true"
                        else
                            health_line "虚拟网中转 TCP" "不可达"
                            health_mark warning "虚拟网中转 TCP 不可达；请检查 EasyTier route、NAT IX nftables 或落地服务。"
                        fi
                    else
                        health_line "虚拟网中转 TCP" "nc 不可用"
                        suggest_install_nc | sed 's/^/  /'
                        health_mark warning "nc 不可用，跳过虚拟网中转 TCP 探测"
                    fi
                fi
                IFS=$'\t' read -r nat_counter_state nat_counter_packets nat_counter_bytes <<<"$(profile_counter_health_status)"
                case "$nat_counter_state" in
                    hit) health_line "nftables counter" "有命中（packets=${nat_counter_packets} bytes=${nat_counter_bytes}），说明入口转发规则正在接收流量" ;;
                    readable) health_line "nftables counter" "可读（等待客户端流量命中）" ;;
                    unavailable) health_line "nftables counter" "不可读" ;;
                    *) health_line "nftables counter" "未找到" ;;
                esac
                if [[ "$nat_route_ok" != "true" && "$nat_tcp_ok" != "true" && "$nat_counter_state" != "hit" ]]; then
                    health_mark warning "EasyTier peer/route 未完全确认，请检查 NAT IX 监听和商家入口端口。"
                fi
                if [[ "${FORWARD_ENABLED:-true}" == "true" && -n "${LOCAL_PORT:-}" ]] && command_exists ss; then
                    if ss -lntup 2>/dev/null | grep -Eq "[:.]${LOCAL_PORT}[[:space:]]"; then
                        health_line "入口端口本机监听冲突" "检测到"
                        health_mark warning "入口端口被本机进程监听"
                    else
                        health_line "入口端口本机监听冲突" "未检测到"
                    fi
                fi
            else
            if [[ -n "${ET_LISTENERS:-}" ]]; then
                health_line "EasyTier listener" "存在（${INGRESS_PUBLIC_HOST:-}:${INGRESS_LISTENER_PORT:-}）"
            else
                health_line "EasyTier listener" "不存在"
                health_mark down "EasyTier listener 不存在"
            fi
            set +e
            check_listener_proto_port "${INGRESS_LISTENER_PROTO:-${ET_LISTENER_PROTO:-tcp}}" "${INGRESS_LISTENER_PORT:-${ET_LISTENER_PORT:-0}}"
            rc=$?
            set -e
            case "$rc" in
                0) health_line "listener 监听" "已检测到" ;;
                2) health_line "listener 监听" "无法检查（ss 命令不可用）"; health_mark warning "无法检查 listener" ;;
                *) health_line "listener 监听" "未检测到"; health_mark down "listener 未监听" ;;
            esac
            if command_exists ip && [[ -n "${NAT_ET_IP:-}" ]]; then
                if ip route get "$NAT_ET_IP" >/dev/null 2>&1; then
                    health_line "NAT IX 虚拟 IP 路由" "存在"
                    nat_route_ok="true"
                else
                    health_line "NAT IX 虚拟 IP 路由" "未找到"
                    health_mark warning "到 NAT IX 虚拟 IP 的路由未确认"
                fi
            else
                health_line "NAT IX 虚拟 IP 路由" "无法检查"
                health_mark warning "无法检查 NAT IX 虚拟 IP 路由"
            fi
            if command_exists ping && [[ -n "${NAT_ET_IP:-}" ]]; then
                if ping -c 1 -W 3 "$NAT_ET_IP" >/dev/null 2>&1; then
                    health_line "NAT IX 虚拟 IP ping" "成功"
                else
                    health_line "NAT IX 虚拟 IP ping" "pending peer（ICMP ping 不通不单独判失败）"
                fi
            else
                health_line "NAT IX 虚拟 IP ping" "跳过"
            fi
            [[ "${FORWARD_PROTO:-both}" == "tcp" || "${FORWARD_PROTO:-both}" == "both" ]] && tcp_needed="true"
            if [[ "$tcp_needed" == "true" && -n "${NAT_ET_IP:-}" && -n "${TRANSIT_PORT:-}" ]]; then
                if nc_cmd="$(detect_nc_cmd 2>/dev/null)"; then
                    if "$nc_cmd" -vz -w 3 "$NAT_ET_IP" "$TRANSIT_PORT" >/dev/null 2>&1; then
                        health_line "虚拟网中转 TCP" "可达（入口机到 NAT IX 中转链路可用）"
                        nat_tcp_ok="true"
                    else
                        health_line "虚拟网中转 TCP" "不可达"
                        if [[ "$nat_route_ok" == "true" ]]; then
                            health_mark warning "虚拟网中转 TCP 不可达；如 NAT IX 已导入，请检查 NAT IX nftables 或落地服务。"
                        else
                            health_mark warning "pending peer：NAT IX 机器可能尚未导入。"
                        fi
                    fi
                else
                    health_line "虚拟网中转 TCP" "nc 不可用"
                    suggest_install_nc | sed 's/^/  /'
                    health_mark warning "nc 不可用，跳过虚拟网中转 TCP 探测"
                fi
            fi
            IFS=$'\t' read -r nat_counter_state nat_counter_packets nat_counter_bytes <<<"$(profile_counter_health_status)"
            case "$nat_counter_state" in
                hit) health_line "nftables counter" "有命中（packets=${nat_counter_packets} bytes=${nat_counter_bytes}），说明转发规则正在接收流量" ;;
                readable) health_line "nftables counter" "可读（等待入口侧或客户端流量命中）" ;;
                unavailable) health_line "nftables counter" "不可读" ;;
                *) health_line "nftables counter" "未找到" ;;
            esac
            if [[ "$nat_route_ok" != "true" && "$nat_tcp_ok" != "true" && "$nat_counter_state" != "hit" ]]; then
                health_mark warning "pending peer：NAT IX 机器尚未接入或未连通"
            fi
            if [[ "${FORWARD_ENABLED:-true}" == "true" && -n "${LOCAL_PORT:-}" ]] && command_exists ss; then
                if ss -lntup 2>/dev/null | grep -Eq "[:.]${LOCAL_PORT}[[:space:]]"; then
                    health_line "入口端口本机监听冲突" "检测到"
                    health_mark warning "入口端口被本机进程监听"
                else
                    health_line "入口端口本机监听冲突" "未检测到"
                fi
            fi
            fi
            ;;
        nat-transit)
            local transit_peers_ok="false" transit_route_ok="false" transit_counter_state transit_counter_packets transit_counter_bytes
            if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
                if [[ -n "${ET_LISTENERS:-}" ]]; then
                    health_line "EasyTier listener" "存在（${NAT_PUBLIC_HOST:-}:${NAT_LISTENER_PORT:-}）"
                else
                    health_line "EasyTier listener" "不存在"
                    health_mark down "EasyTier listener 不存在"
                fi
                set +e
                check_listener_proto_port "${NAT_LISTENER_PROTO:-${ET_LISTENER_PROTO:-tcp}}" "${NAT_LISTENER_PORT:-${ET_LISTENER_PORT:-0}}"
                rc=$?
                set -e
                case "$rc" in
                    0) health_line "商家入口监听" "已检测到" ;;
                    2) health_line "商家入口监听" "无法检查（ss 命令不可用）"; health_mark warning "无法检查 listener" ;;
                    *) health_line "商家入口监听" "未检测到"; health_mark down "NAT IX 监听未检测到" ;;
                esac
                if command_exists ip && [[ -n "${INGRESS_ET_IP:-}" ]]; then
                    if ip route get "$INGRESS_ET_IP" >/dev/null 2>&1; then
                        health_line "公网入口机虚拟 IP route/peer" "存在"
                        transit_route_ok="true"
                    else
                        health_line "公网入口机虚拟 IP route/peer" "pending peer（公网入口机可能尚未导入接入码）"
                    fi
                else
                    health_line "公网入口机虚拟 IP route/peer" "无法检查"
                fi
                if command_exists ping && [[ -n "${INGRESS_ET_IP:-}" ]]; then
                    if ping -c 1 -W 3 "$INGRESS_ET_IP" >/dev/null 2>&1; then
                        health_line "公网入口机虚拟 IP ping" "成功"
                    else
                        health_line "公网入口机虚拟 IP ping" "pending peer 或 ICMP 不响应，不单独判失败"
                    fi
                else
                    health_line "公网入口机虚拟 IP ping" "跳过"
                fi
                if [[ -n "${LANDING_HOST:-}" ]]; then
                    if validate_ipv4 "$LANDING_HOST"; then
                        health_line "落地地址" "$LANDING_HOST"
                    elif landing_ip="$(landing_ip_for_nft "$LANDING_HOST" 2>/dev/null)"; then
                        health_line "落地地址解析" "${LANDING_HOST} -> ${landing_ip}"
                    else
                        health_line "落地地址解析" "失败"
                        health_mark down "落地地址域名解析失败"
                    fi
                fi
                [[ "${FORWARD_PROTO:-both}" == "tcp" || "${FORWARD_PROTO:-both}" == "both" ]] && tcp_needed="true"
                if [[ "$tcp_needed" == "true" && -n "${LANDING_HOST:-}" && -n "${LANDING_PORT:-}" ]]; then
                    if nc_cmd="$(detect_nc_cmd 2>/dev/null)"; then
                        if "$nc_cmd" -vz -w 3 "$LANDING_HOST" "$LANDING_PORT" >/dev/null 2>&1; then
                            health_line "落地服务 TCP" "可达"
                        else
                            health_line "落地服务 TCP" "不可达"
                            health_mark warning "落地服务 TCP 探测失败"
                        fi
                    else
                        health_line "落地服务 TCP" "nc 不可用"
                        suggest_install_nc | sed 's/^/  /'
                        health_mark warning "nc 不可用，跳过落地端口探测"
                    fi
                fi
                if [[ "${FORWARD_PROTO:-both}" == "udp" || "${FORWARD_PROTO:-both}" == "both" ]]; then
                    health_line "UDP 探测" "跳过（UDP 不可靠）"
                fi
                health_line "虚拟网中转端口监听" "不要求（nftables DNAT 接收端口）"
                IFS=$'\t' read -r transit_counter_state transit_counter_packets transit_counter_bytes <<<"$(profile_counter_health_status)"
                case "$transit_counter_state" in
                    hit) health_line "nftables counter" "有命中（packets=${transit_counter_packets} bytes=${transit_counter_bytes}），说明转发规则正在接收流量" ;;
                    readable) health_line "nftables counter" "可读（等待入口侧或客户端流量命中）" ;;
                    unavailable) health_line "nftables counter" "不可读" ;;
                    *) health_line "nftables counter" "未找到" ;;
                esac
                [[ "$transit_route_ok" == "true" ]] || health_mark warning "pending peer：公网入口机可能尚未导入推荐模式接入码。"
            else
            if [[ -n "${ET_PEERS:-}" ]]; then
                health_line "EasyTier peers" "存在"
                transit_peers_ok="true"
            else
                health_line "EasyTier peers" "不存在"
                health_mark warning "EasyTier peer 不存在"
            fi
            if command_exists ip && [[ -n "${INGRESS_ET_IP:-}" ]]; then
                if ip route get "$INGRESS_ET_IP" >/dev/null 2>&1; then
                    health_line "公网入口机虚拟 IP 路由" "存在"
                    transit_route_ok="true"
                else
                    health_line "公网入口机虚拟 IP 路由" "未找到"
                fi
            else
                health_line "公网入口机虚拟 IP 路由" "无法检查"
            fi
            if command_exists ping && [[ -n "${INGRESS_ET_IP:-}" ]]; then
                if ping -c 1 -W 3 "$INGRESS_ET_IP" >/dev/null 2>&1; then
                    health_line "公网入口机虚拟 IP ping" "成功"
                else
                    if [[ "$transit_peers_ok" == "true" && "$transit_route_ok" == "true" ]]; then
                        health_line "公网入口机虚拟 IP ping" "ICMP ping 不通，但 EasyTier route/peer 存在；可能是 ICMP 不响应。请以业务 TCP、traffic counter 或 EasyTier peer 状态为准。"
                    else
                        health_line "公网入口机虚拟 IP ping" "失败"
                    fi
                fi
            else
                health_line "公网入口机虚拟 IP ping" "跳过"
            fi
            if [[ "$transit_peers_ok" != "true" && "$transit_route_ok" != "true" ]]; then
                health_mark warning "EasyTier peer 未建立，请检查入口机 listener、安全组、NAT IX 出口是否可访问入口机 listener。"
            elif [[ "$transit_peers_ok" != "true" || "$transit_route_ok" != "true" ]]; then
                health_mark warning "EasyTier peer/route 未完全确认，请检查入口机 listener 和安全组。"
            fi
            if [[ -n "${LANDING_HOST:-}" ]]; then
                if validate_ipv4 "$LANDING_HOST"; then
                    health_line "落地地址" "$LANDING_HOST"
                elif landing_ip="$(landing_ip_for_nft "$LANDING_HOST" 2>/dev/null)"; then
                    health_line "落地地址解析" "${LANDING_HOST} -> ${landing_ip}"
                else
                    health_line "落地地址解析" "失败"
                    health_mark down "落地地址域名解析失败"
                fi
            fi
            [[ "${FORWARD_PROTO:-both}" == "tcp" || "${FORWARD_PROTO:-both}" == "both" ]] && tcp_needed="true"
            if [[ "$tcp_needed" == "true" && -n "${LANDING_HOST:-}" && -n "${LANDING_PORT:-}" ]]; then
                if nc_cmd="$(detect_nc_cmd 2>/dev/null)"; then
                    if "$nc_cmd" -vz -w 3 "$LANDING_HOST" "$LANDING_PORT" >/dev/null 2>&1; then
                        health_line "落地服务 TCP" "可达"
                    else
                        health_line "落地服务 TCP" "不可达"
                        health_mark warning "落地服务 TCP 探测失败"
                    fi
                else
                    health_line "落地服务 TCP" "nc 不可用"
                    suggest_install_nc | sed 's/^/  /'
                    health_mark warning "nc 不可用，跳过落地端口探测"
                fi
            fi
            if [[ "${FORWARD_PROTO:-both}" == "udp" || "${FORWARD_PROTO:-both}" == "both" ]]; then
                health_line "UDP 探测" "跳过（UDP 不可靠）"
            fi
            health_line "虚拟网中转端口监听" "不要求（nftables DNAT 接收端口）"
            health_line "虚拟网中转本机直连" "仅供参考：本机直连虚拟网中转端口可能不命中 PREROUTING DNAT"
            IFS=$'\t' read -r transit_counter_state transit_counter_packets transit_counter_bytes <<<"$(profile_counter_health_status)"
            case "$transit_counter_state" in
                hit) health_line "nftables counter" "有命中（packets=${transit_counter_packets} bytes=${transit_counter_bytes}），说明转发规则正在接收流量" ;;
                readable) health_line "nftables counter" "可读（等待入口侧或客户端流量命中）" ;;
                unavailable) health_line "nftables counter" "不可读" ;;
                *) health_line "nftables counter" "未找到" ;;
            esac
            fi
            ;;
    esac

    [[ -n "$_IXTF_HEALTH_REASON" ]] || _IXTF_HEALTH_REASON="检查通过"
    printf '\nHEALTH_STATUS=%s\n' "$_IXTF_HEALTH_STATUS"
    printf 'LAST_HEALTH_REASON=%s\n' "$_IXTF_HEALTH_REASON"
    if [[ ( "${ROLE:-}" == "nat-ingress" || "${ROLE:-}" == "nat-transit" ) && "$_IXTF_HEALTH_STATUS" != "healthy" ]]; then
        printf '需要延迟详情请运行：bash install.sh latency-report %s\n' "$profile_id"
    fi

    if [[ "$write_back" == "true" ]]; then
        saved_status="$_IXTF_HEALTH_STATUS"
        saved_reason="$_IXTF_HEALTH_REASON"
        now="$(utc_now)"
        HEALTH_STATUS="$saved_status"
        LAST_HEALTH_REASON="$saved_reason"
        LAST_HEALTH_CHECK_AT="$now"
        if ( validate_profile_config "$profile_id" ) >/dev/null 2>&1; then
            if save_profile_runtime_state "$profile_id"; then
                :
            else
                save_profile_env "$profile_id"
            fi
            printf '已写回健康状态：%s / %s\n' "$HEALTH_STATUS" "$LAST_HEALTH_CHECK_AT"
        else
            printf '[WARN] 线路配置不完整，未写回健康状态。\n'
        fi
    fi
}

print_nat_ix_troubleshooting_hint() {
    local profile_id="${1:-${PROFILE_ID:-}}" service status et_ip
    [[ "${ROLE:-}" == "nat-ingress" || "${ROLE:-}" == "nat-transit" ]] || return 0
    status="${_IXTF_HEALTH_STATUS:-${HEALTH_STATUS:-unknown}}"
    [[ "$status" != "healthy" ]] || return 0
    service="$(profile_service_name "$profile_id")"
    et_ip="${ET_IPV4:-ET_IP}"
    et_ip="${et_ip%%/*}"
    cat <<EOF

NAT-IX 排障命令：
  systemctl status ${service} --no-pager -l
  journalctl -u ${service} -n 100 --no-pager
  ip addr | grep ${et_ip} || true
  bash install.sh show-easytier-command ${profile_id}
  bash install.sh latency-report ${profile_id}
  bash install.sh health ${profile_id}
  bash install.sh verify-nft-profiles
  bash install.sh show-port-map --compact ${profile_id}
EOF
}

check_line() {
    require_root "$@"
    if [[ "${1:-}" == "--all" ]]; then
        local id
        for id in $(profile_ids); do
            printf '\n===== 线路 %s =====\n' "$id"
            ( run_line_health_check "$id" false ) || true
        done
        return 0
    fi
    run_line_health_check "${1:-}" false
}

health_profile() {
    require_root "$@"
    run_line_health_check "${1:-}" true
}

health_all() {
    require_root "$@"
    local id output rc status total=0 healthy=0 warning=0 down=0 unknown=0
    for id in $(profile_ids); do
        load_profile "$id" || { printf '[WARN] 无法读取线路：%s\n' "$id"; continue; }
        [[ "${ENABLED:-true}" == "true" && "${HEALTH_CHECK_ENABLED:-true}" == "true" ]] || continue
        printf '\n===== 线路 %s =====\n' "$id"
        set +e
        output="$(run_line_health_check "$id" true 2>&1)"
        rc=$?
        set -e
        printf '%s\n' "$output"
        total=$((total + 1))
        status="$(grep -E '^HEALTH_STATUS=' <<<"$output" | tail -n 1 | cut -d= -f2- || true)"
        status="${status:-unknown}"
        if [[ "$rc" -ne 0 ]]; then
            unknown=$((unknown + 1))
            printf '[WARN] health %s 失败（退出码 %s），已继续检查后续 Profile。\n' "$id" "$rc"
        else
            case "$status" in
                healthy) healthy=$((healthy + 1)) ;;
                warning) warning=$((warning + 1)) ;;
                down) down=$((down + 1)) ;;
                *) unknown=$((unknown + 1)) ;;
            esac
        fi
    done
    printf '\n汇总：total=%s healthy=%s warning=%s down=%s unknown=%s\n' "$total" "$healthy" "$warning" "$down" "$unknown"
}

set_health() {
    require_root "$@"
    local profile_id="${1:-}" status="${2:-}" reason
    [[ -n "$profile_id" && -n "$status" ]] || die_user "用法：set-health PROFILE_ID STATUS REASON"
    shift 2 || true
    reason="$*"
    validate_health_status_value "$status" || die_user "HEALTH_STATUS 只能是 unknown、healthy、warning 或 down。"
    load_profile_or_die "$profile_id"
    HEALTH_STATUS="$status"
    LAST_HEALTH_CHECK_AT="$(utc_now)"
    LAST_HEALTH_REASON="${reason:-手动设置}"
    save_profile_env "$profile_id"
    log_ok "已设置健康状态：${profile_id} -> ${HEALTH_STATUS}"
}

health_report() {
    require_root "$@"
    local group_filter="" output_file="" id service active et_ip nft_label enabled_label forward_label group_display health
    local total=0 healthy=0 warning=0 down=0 unknown=0 groups_total=0 groups_with_issues=0 group issue backup_id
    if [[ "${1:-}" == "--group" ]]; then
        group_filter="${2:-}"
        [[ -n "$group_filter" ]] || die_user "用法：health-report --group GROUP"
    elif [[ -n "${1:-}" ]]; then
        group_filter="$1"
    fi

    printf '%-20s %-14s %-14s %-10s %-5s %-7s %-8s %-10s %-15s %-8s %-8s %-20s %s\n' \
        "PROFILE" "GROUP" "ROLE" "LINE" "PRI" "ENABLED" "FORWARD" "SERVICE" "ET-IP" "NFT" "HEALTH" "LAST CHECK" "REASON"
    printf '%-20s %-14s %-14s %-10s %-5s %-7s %-8s %-10s %-15s %-8s %-8s %-20s %s\n' \
        "--------------------" "--------------" "--------------" "----------" "-----" "-------" "--------" "----------" "---------------" "--------" "--------" "--------------------" "------"
    for id in $(sorted_profile_ids); do
        if ! load_profile "$id"; then
            [[ -z "$group_filter" ]] || continue
            printf '%-20s %-14s %-14s %-10s %-5s %-7s %-8s %-10s %-15s %-8s %-8s %-20s %s\n' \
                "$id" "-" "-" "-" "-" "off" "off" "unknown" "-" "unknown" "down" "-" "cannot read Profile"
            total=$((total + 1))
            down=$((down + 1))
            continue
        fi
        [[ -z "$group_filter" || "${LINE_GROUP:-}" == "$group_filter" ]] || continue
        service="$(profile_service_name "$id")"
        active="$(profile_service_status "$service")"
        et_ip="${ET_IPV4:-}"
        et_ip="${et_ip%%/*}"
        nft_label="$(nft_profile_rule_label "$id")"
        enabled_label="$(enabled_display "${ENABLED:-true}")"
        forward_label="$(forward_display "${ROLE:-}" "${ENABLED:-true}" "${FORWARD_ENABLED:-true}")"
        group_display="${LINE_GROUP:-standalone}"
        health="${HEALTH_STATUS:-unknown}"
        case "$health" in
            healthy) healthy=$((healthy + 1)) ;;
            warning) warning=$((warning + 1)) ;;
            down) down=$((down + 1)) ;;
            *) unknown=$((unknown + 1)) ;;
        esac
        total=$((total + 1))
        printf '%-20s %-14s %-14s %-10s %-5s %-7s %-8s %-10s %-15s %-8s %-8s %-20s %s\n' \
            "$id" "$group_display" "${ROLE:-}" "${LINE_ROLE:-standalone}" "${LINE_PRIORITY:-100}" \
            "$enabled_label" "$forward_label" "${active:-unknown}" "${et_ip:-}" "$nft_label" \
            "$health" "${LAST_HEALTH_CHECK_AT:--}" "${LAST_HEALTH_REASON:-未检查}"
    done

    if [[ -n "$group_filter" ]]; then
        group_exists "$group_filter" && groups_total=1 || groups_total=0
    else
        groups_total="$(profile_groups | awk 'NF{c++} END{print c+0}')"
    fi

    printf '\nSummary:\n'
    printf 'Profiles total: %s\n' "$total"
    printf 'Groups total: %s\n' "$groups_total"
    printf 'Healthy: %s\n' "$healthy"
    printf 'Warning: %s\n' "$warning"
    printf 'Down: %s\n' "$down"
    printf 'Unknown: %s\n' "$unknown"

    printf '\nGroup issues:\n'
    while IFS= read -r group; do
        [[ -n "$group" ]] || continue
        [[ -z "$group_filter" || "$group" == "$group_filter" ]] || continue
        if [[ "$(group_issue_count "$group")" -gt 0 ]]; then
            groups_with_issues=$((groups_with_issues + 1))
            while IFS= read -r issue; do
                [[ -n "$issue" ]] || continue
                printf '  - %s: %s\n' "$group" "${issue%%:*}"
                if [[ "$issue" == primary\ down\ but\ backup\ healthy:* ]]; then
                    backup_id="${issue#*:}"
                    printf '    建议：bash install.sh switch-dry-run %s %s\n' "$group" "$backup_id"
                    printf '    执行：bash install.sh switch-line %s %s\n' "$group" "$backup_id"
                fi
            done < <(group_issue_lines "$group")
        fi
    done < <(profile_groups)
    [[ "$groups_with_issues" -gt 0 ]] || printf '  - none\n'
    printf 'Groups with issues: %s\n' "$groups_with_issues"
}

export_health_report() {
    require_root "$@"
    local output_file="" tmp
    if [[ "${1:-}" == "--file" ]]; then
        output_file="${2:-}"
        [[ -n "$output_file" ]] || die_user "用法：export-health-report --file PATH"
    elif [[ -n "${1:-}" ]]; then
        output_file="$1"
    fi

    if [[ -n "$output_file" ]]; then
        tmp="$(make_tmp_file "ix-transit-fabric.health-report")"
        health_report >"$tmp"
        install -m 0600 "$tmp" "$output_file"
        rm -f -- "$tmp"
        log_ok "已导出健康报告：${output_file}"
    else
        health_report
    fi
}

profile_groups() {
    local id
    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        [[ -n "${LINE_GROUP:-}" ]] && printf '%s\n' "$LINE_GROUP"
    done | sort -u || true
    return 0
}

profile_group_count() {
    profile_groups | awk 'NF{c++} END{print c+0}'
    return 0
}

print_no_group_message() {
    printf '当前没有已配置的线路组；standalone 模式下主备组检查已跳过。若需要主备切换，请先设置 LINE_GROUP。\n'
}

join_profile_list() {
    local value output=""
    while IFS= read -r value; do
        [[ -n "$value" ]] || continue
        output="${output:+$output }$value"
    done
    printf '%s\n' "${output:--}"
}

list_group_ingress_profiles() {
    local group="$1" id
    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        [[ "${LINE_GROUP:-}" == "$group" && "${ROLE:-}" == "nat-ingress" ]] || continue
        printf '%s\n' "$id"
    done
    return 0
}

list_group_forwarding_profiles() {
    local group="$1" id
    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        [[ "${LINE_GROUP:-}" == "$group" && "${ROLE:-}" == "nat-ingress" && "${ENABLED:-true}" == "true" && "${FORWARD_ENABLED:-true}" == "true" ]] || continue
        printf '%s\n' "$id"
    done
    return 0
}

list_group_primary_profiles() {
    local group="$1" id
    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        [[ "${LINE_GROUP:-}" == "$group" && "${LINE_ROLE:-standalone}" == "primary" ]] || continue
        printf '%s\n' "$id"
    done
    return 0
}

list_group_backup_profiles() {
    local group="$1" id
    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        [[ "${LINE_GROUP:-}" == "$group" && "${LINE_ROLE:-standalone}" == "backup" ]] || continue
        printf '%s\n' "$id"
    done
    return 0
}

group_profile_count() {
    local group="$1" id count=0
    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        [[ "${LINE_GROUP:-}" == "$group" ]] || continue
        count=$((count + 1))
    done
    printf '%s\n' "$count"
    return 0
}

group_exists() {
    [[ "$(group_profile_count "$1")" -gt 0 ]]
}

list_existing_groups_for_message() {
    local groups
    groups="$(profile_groups | join_profile_list)"
    printf '%s\n' "${groups:--}"
    return 0
}

profile_four_ports_missing() {
    local missing=()
    case "${ROLE:-}" in
        nat-ingress)
            [[ -n "${LOCAL_PORT:-}" ]] || missing+=("LOCAL_PORT")
            [[ -n "${CNIX_ENTRY_HOST:-}" ]] || missing+=("CNIX_ENTRY_HOST")
            [[ -n "${CNIX_ENTRY_PORT:-}" ]] || missing+=("CNIX_ENTRY_PORT")
            [[ -n "${CODE_LISTENER_PORT:-}" ]] || missing+=("CODE_LISTENER_PORT")
            [[ -n "${REMOTE_PORT:-}" ]] || missing+=("REMOTE_PORT")
            [[ -n "${LANDING_ET_IP:-}" ]] || missing+=("LANDING_ET_IP")
            [[ -n "${FORWARD_PROTO:-}" ]] || missing+=("FORWARD_PROTO")
            ;;
        nat-transit)
            [[ -n "${ET_LISTENER_PORT:-${LISTENER_PORT:-}}" ]] || missing+=("LISTENER_PORT")
            [[ -n "${SERVICE_PORT:-${REMOTE_PORT:-}}" ]] || missing+=("REMOTE_PORT")
            ;;
        nat-ingress)
            [[ -n "${INGRESS_PUBLIC_HOST:-}" ]] || missing+=("INGRESS_PUBLIC_HOST")
            [[ -n "${INGRESS_ET_IP:-}" ]] || missing+=("INGRESS_ET_IP")
            [[ -n "${NAT_ET_IP:-}" ]] || missing+=("NAT_ET_IP")
            [[ -n "${INGRESS_LISTENER_PORT:-}" ]] || missing+=("INGRESS_LISTENER_PORT")
            [[ -n "${LOCAL_PORT:-}" ]] || missing+=("LOCAL_PORT")
            [[ -n "${TRANSIT_PORT:-}" ]] || missing+=("TRANSIT_PORT")
            [[ -n "${FORWARD_PROTO:-}" ]] || missing+=("FORWARD_PROTO")
            ;;
        nat-transit)
            [[ -n "${INGRESS_PUBLIC_HOST:-}" ]] || missing+=("INGRESS_PUBLIC_HOST")
            [[ -n "${INGRESS_ET_IP:-}" ]] || missing+=("INGRESS_ET_IP")
            [[ -n "${NAT_ET_IP:-}" ]] || missing+=("NAT_ET_IP")
            [[ -n "${INGRESS_LISTENER_PORT:-}" ]] || missing+=("INGRESS_LISTENER_PORT")
            [[ -n "${TRANSIT_PORT:-}" ]] || missing+=("TRANSIT_PORT")
            [[ -n "${LANDING_HOST:-}" ]] || missing+=("LANDING_HOST")
            [[ -n "${LANDING_PORT:-}" ]] || missing+=("LANDING_PORT")
            [[ -n "${FORWARD_PROTO:-}" ]] || missing+=("FORWARD_PROTO")
            ;;
        *)
            missing+=("ROLE")
            ;;
    esac
    if ((${#missing[@]} == 0)); then
        printf 'complete\n'
    else
        (IFS=','; printf '%s\n' "${missing[*]}")
    fi
}

profile_four_port_summary() {
    local cnix listener remote landing
    case "${ROLE:-}" in
        nat-ingress)
            printf 'LOCAL=%s INGRESS_ET=%s NAT_ET=%s TRANSIT=%s TARGET=%s:%s PROTO=%s\n' \
                "${LOCAL_PORT:-?}" "${INGRESS_ET_IP:-?}" "${NAT_ET_IP:-?}" "${TRANSIT_PORT:-?}" "${NAT_ET_IP:-?}" "${TRANSIT_PORT:-?}" "${FORWARD_PROTO:-?}"
            return 0
            ;;
        nat-transit)
            printf 'TRANSIT=%s:%s LANDING=%s:%s CLIENT=%s:%s PROTO=%s\n' \
                "${NAT_ET_IP:-?}" "${TRANSIT_PORT:-?}" "${LANDING_HOST:-?}" "${LANDING_PORT:-?}" "${INGRESS_PUBLIC_HOST:-?}" "${LOCAL_PORT:-?}" "${FORWARD_PROTO:-?}"
            return 0
            ;;
    esac
    cnix="${CNIX_ENTRY_HOST:-?}:${CNIX_ENTRY_PORT:-?}"
    listener="${CODE_LISTENER_PORT:-${ET_LISTENER_PORT:-${LISTENER_PORT:-?}}}"
    remote="${REMOTE_PORT:-${SERVICE_PORT:-?}}"
    landing="${LANDING_ET_IP:-?}"
    printf 'LOCAL=%s CNIX=%s LISTENER=%s LANDING=%s REMOTE=%s PROTO=%s\n' \
        "${LOCAL_PORT:-?}" "$cnix" "$listener" "$landing" "$remote" "${FORWARD_PROTO:-?}"
}

group_health_for_profiles() {
    local profiles="$1" id out="" h
    while IFS= read -r id; do
        [[ -n "$id" ]] || continue
        if load_profile "$id" >/dev/null 2>&1; then
            h="${HEALTH_STATUS:-unknown}"
        else
            h="unknown"
        fi
        out="${out:+${out},}${id}:${h}"
    done <<<"$profiles"
    printf '%s\n' "${out:-none}"
}

switch_history_sanitize() {
    local value="${1:-}"
    value="${value//$'\t'/ }"
    value="${value//$'\r'/ }"
    value="${value//$'\n'/ }"
    printf '%s\n' "$value"
}

switch_history_path() {
    printf '%s/switch-history.tsv\n' "$STATE_DIR"
}

ensure_switch_history_file() {
    local history_file
    ensure_profile_dirs
    install -d -m 700 "$STATE_DIR"
    history_file="$(switch_history_path)"
    if [[ ! -e "$history_file" ]]; then
        printf 'timestamp\tgroup\tfrom_profile\tto_profile\toperator\treason\tfrom_health\tto_health\tresult\tnote\n' >"$history_file"
    fi
    chmod 600 "$history_file"
}

append_switch_history() {
    local stamp="$1" group="$2" from_profile="$3" to_profile="$4" operator="$5" reason="$6" from_health="$7" to_health="$8" result="$9" note="${10:-}"
    local history_file
    ensure_switch_history_file
    history_file="$(switch_history_path)"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$(switch_history_sanitize "$stamp")" \
        "$(switch_history_sanitize "$group")" \
        "$(switch_history_sanitize "$from_profile")" \
        "$(switch_history_sanitize "$to_profile")" \
        "$(switch_history_sanitize "$operator")" \
        "$(switch_history_sanitize "$reason")" \
        "$(switch_history_sanitize "$from_health")" \
        "$(switch_history_sanitize "$to_health")" \
        "$(switch_history_sanitize "$result")" \
        "$(switch_history_sanitize "$note")" >>"$history_file"
    chmod 600 "$history_file"
}

switch_history() {
    require_root "$@"
    local group_filter="${1:-}" tmp history_file
    ensure_switch_history_file
    history_file="$(switch_history_path)"
    tmp="$(make_tmp_file "ix-transit-fabric.switch-history")"
    if [[ -n "$group_filter" ]]; then
        awk -F '\t' -v g="$group_filter" 'NR==1 || $2==g {print}' "$history_file" >"$tmp"
    else
        cat "$history_file" >"$tmp"
    fi
    printf 'Recent switch history%s (last 20):\n' "$([[ -n "$group_filter" ]] && printf ' for %s' "$group_filter" || true)"
    awk -F '\t' '
        NR==1 {header=$0; next}
        {rows[++n]=$0}
        END {
            print header
            start=n-19
            if (start < 1) start=1
            for (i=start; i<=n; i++) if (i in rows) print rows[i]
            if (n == 0) print "(empty)"
        }
    ' "$tmp"
    rm -f -- "$tmp"
}

clear_switch_history() {
    require_root "$@"
    local history_file
    if read_exact_confirmation "确认清空切换历史请输入 CLEAR：" "CLEAR"; then
        ensure_switch_history_file
        history_file="$(switch_history_path)"
        printf 'timestamp\tgroup\tfrom_profile\tto_profile\toperator\treason\tfrom_health\tto_health\tresult\tnote\n' >"$history_file"
        chmod 600 "$history_file"
        log_ok "已清空切换历史：${history_file}"
    else
        die_user "已取消清空切换历史。"
    fi
}

last_switch_history_for_group() {
    local group="$1" history_file
    history_file="$(switch_history_path)"
    [[ -r "$history_file" ]] || return 1
    awk -F '\t' -v g="$group" 'NR>1 && $2==g {line=$0} END {if (line) print line}' "$history_file"
}

first_healthy_backup_in_group() {
    local group="$1" id
    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        [[ "${LINE_GROUP:-}" == "$group" && "${LINE_ROLE:-standalone}" == "backup" && "${HEALTH_STATUS:-unknown}" == "healthy" ]] || continue
        printf '%s\n' "$id"
        return 0
    done
    return 1
}

first_available_backup_in_group() {
    local group="$1" id fallback=""
    for id in $(list_group_backup_profiles "$group"); do
        load_profile "$id" >/dev/null 2>&1 || continue
        [[ -z "$fallback" ]] && fallback="$id"
        if [[ "${ENABLED:-true}" == "true" && "${HEALTH_STATUS:-unknown}" != "down" ]]; then
            printf '%s\n' "$id"
            return 0
        fi
    done
    [[ -n "$fallback" ]] && { printf '%s\n' "$fallback"; return 0; }
    return 1
}

primary_profile_in_group() {
    list_group_primary_profiles "$1" | awk 'NF{print; exit}' || true
    return 0
}

group_hot_standby_count() {
    local group="$1" id count=0
    for id in $(list_group_backup_profiles "$group"); do
        load_profile "$id" >/dev/null 2>&1 || continue
        [[ "${ENABLED:-true}" == "true" && "${FORWARD_ENABLED:-true}" == "false" ]] && count=$((count + 1))
    done
    printf '%s\n' "$count"
    return 0
}

group_cold_standby_count() {
    local group="$1" id count=0
    for id in $(list_group_backup_profiles "$group"); do
        load_profile "$id" >/dev/null 2>&1 || continue
        [[ "${ENABLED:-true}" == "false" ]] && count=$((count + 1))
    done
    printf '%s\n' "$count"
    return 0
}

group_ready_state_label_zh() {
    case "${1:-}" in
        ready) printf '就绪' ;;
        warning) printf '有警告' ;;
        not-ready) printf '未就绪' ;;
        *) printf '%s' "${1:-未知}" ;;
    esac
}

group_issue_label_zh() {
    local issue="${1:-}"
    issue="${issue%%:*}"
    case "$issue" in
        "primary down") printf '主线路故障' ;;
        "no primary") printf '未配置主线路' ;;
        "multiple primary") printf '存在多条主线路' ;;
        "no forwarding") printf '没有处于转发的入口线路' ;;
        "multiple forwarding") printf '多条线路同时转发' ;;
        "no backup") printf '未配置备线路' ;;
        "primary down but backup healthy") printf '主线路故障但备线路健康' ;;
        "backup down") printf '备线路故障' ;;
        "all lines down") printf '线路组内全部线路故障' ;;
        *) printf '%s' "$issue" ;;
    esac
}

group_ready_state() {
    local group="$1" primary_count backup_count forwarding_count ingress_count down_count=0 warning_count=0 id status
    group_exists "$group" || { printf 'not-ready\n'; return 0; }
    ingress_count="$(list_group_ingress_profiles "$group" | awk 'NF{c++} END{print c+0}')"
    primary_count="$(list_group_primary_profiles "$group" | awk 'NF{c++} END{print c+0}')"
    backup_count="$(list_group_backup_profiles "$group" | awk 'NF{c++} END{print c+0}')"
    forwarding_count="$(list_group_forwarding_profiles "$group" | awk 'NF{c++} END{print c+0}')"
    if [[ "$ingress_count" -lt 2 || "$primary_count" -ne 1 || "$backup_count" -lt 1 || "$forwarding_count" -ne 1 ]]; then
        printf 'not-ready\n'
        return 0
    fi
    for id in $(list_group_ingress_profiles "$group"); do
        load_profile "$id" >/dev/null 2>&1 || continue
        status="${HEALTH_STATUS:-unknown}"
        [[ "$status" == "down" ]] && down_count=$((down_count + 1))
        [[ "$status" == "warning" || "$status" == "unknown" ]] && warning_count=$((warning_count + 1))
    done
    if [[ "$down_count" -gt 0 ]]; then
        printf 'warning\n'
    elif [[ "$warning_count" -gt 0 ]]; then
        printf 'warning\n'
    else
        printf 'ready\n'
    fi
}

group_issue_lines() {
    local group="$1" id primary_count=0 backup_count=0 forwarding_count=0 profile_count=0 down_count=0
    local primary_down=0 backup_healthy=0 backup_id status
    [[ -n "$group" ]] || return 0
    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        [[ "${LINE_GROUP:-}" == "$group" ]] || continue
        profile_count=$((profile_count + 1))
        status="${HEALTH_STATUS:-unknown}"
        [[ "$status" == "down" ]] && down_count=$((down_count + 1))
        [[ "${LINE_ROLE:-standalone}" == "primary" ]] && primary_count=$((primary_count + 1))
        [[ "${LINE_ROLE:-standalone}" == "backup" ]] && backup_count=$((backup_count + 1))
        [[ "${ROLE:-}" == "nat-ingress" && "${ENABLED:-true}" == "true" && "${FORWARD_ENABLED:-true}" == "true" ]] && forwarding_count=$((forwarding_count + 1))
        [[ "${LINE_ROLE:-standalone}" == "primary" && "$status" == "down" ]] && { primary_down=1; printf 'primary down\n'; }
        [[ "${LINE_ROLE:-standalone}" == "backup" && "$status" == "down" ]] && printf 'backup down:%s\n' "$id"
        if [[ "${LINE_ROLE:-standalone}" == "backup" && "$status" == "healthy" ]]; then
            backup_healthy=1
            backup_id="${backup_id:-$id}"
        fi
    done
    [[ "$primary_count" -gt 0 ]] || printf 'no primary\n'
    [[ "$primary_count" -le 1 ]] || printf 'multiple primary\n'
    [[ "$forwarding_count" -gt 0 ]] || printf 'no forwarding\n'
    [[ "$forwarding_count" -le 1 ]] || printf 'multiple forwarding\n'
    [[ "$backup_count" -gt 0 ]] || printf 'no backup\n'
    [[ "$primary_down" -eq 1 && "$backup_healthy" -eq 1 ]] && printf 'primary down but backup healthy:%s\n' "$backup_id"
    [[ "$profile_count" -gt 0 && "$down_count" -eq "$profile_count" ]] && printf 'all lines down\n'
    return 0
}

group_issue_count() {
    local group="$1"
    group_issue_lines "$group" | awk 'NF{c++} END{print c+0}' || true
    return 0
}

validate_primary_backup() {
    require_root "$@"
    local group="${1:-}" id path primary_count=0 backup_count=0 ingress_count=0 forwarding_count=0
    local fail_count=0 warn_count=0 pass_count=0 primary_ids backup_ids forwarding_ids nft_text nft_available=0
    local missing dup_ports="" active_ports all_ports port seen_ports="" current current_found=0 primary_down=0 healthy_backup=""
    if [[ -z "$group" ]]; then
        if [[ "$(profile_group_count)" -eq 0 ]]; then
            print_no_group_message
            return 0
        fi
        die_user "用法：validate-primary-backup GROUP"
    fi

    pb_item() {
        local status="$1" message="$2"
        case "$status" in
            OK) pass_count=$((pass_count + 1)) ;;
            WARN) warn_count=$((warn_count + 1)) ;;
            FAIL) fail_count=$((fail_count + 1)) ;;
        esac
        printf '[%s] %s\n' "$status" "$message"
    }

    printf '主备模型校验：%s\n' "$group"
    if group_exists "$group"; then
        pb_item OK "线路组 ${group} 存在。"
    else
        pb_item FAIL "线路组 ${group} 不存在。已有线路组：$(list_existing_groups_for_message)"
        printf '\n建议：先用 set-line-group 创建或分配线路后再校验。\n'
        return 1
    fi

    primary_ids="$(list_group_primary_profiles "$group")"
    backup_ids="$(list_group_backup_profiles "$group")"
    forwarding_ids="$(list_group_forwarding_profiles "$group")"
    primary_count="$(printf '%s\n' "$primary_ids" | awk 'NF{c++} END{print c+0}')"
    backup_count="$(printf '%s\n' "$backup_ids" | awk 'NF{c++} END{print c+0}')"
    forwarding_count="$(printf '%s\n' "$forwarding_ids" | awk 'NF{c++} END{print c+0}')"
    ingress_count="$(list_group_ingress_profiles "$group" | awk 'NF{c++} END{print c+0}')"

    [[ "$ingress_count" -gt 0 ]] && pb_item OK "线路组含 ${ingress_count} 条入口线路。" || pb_item FAIL "线路组没有入口线路。"
    [[ "$primary_count" -gt 0 ]] && pb_item OK "主线路：$(printf '%s\n' "$primary_ids" | join_profile_list)。" || pb_item FAIL "未配置主线路（primary）。"
    [[ "$backup_count" -gt 0 ]] && pb_item OK "备线路：$(printf '%s\n' "$backup_ids" | join_profile_list)。" || pb_item FAIL "未配置备线路（backup）。"
    [[ "$primary_count" -le 1 ]] && pb_item OK "主线路唯一。" || pb_item FAIL "存在多条主线路：$(printf '%s\n' "$primary_ids" | join_profile_list)。"
    [[ "$forwarding_count" -le 1 ]] && pb_item OK "线路组内仅一条线路处于转发中。" || pb_item FAIL "多条线路同时转发：$(printf '%s\n' "$forwarding_ids" | join_profile_list)。"
    [[ "$forwarding_count" -gt 0 ]] && pb_item OK "当前转发线路：$(printf '%s\n' "$forwarding_ids" | join_profile_list)。" || pb_item FAIL "没有 FORWARD_ENABLED=true 的入口线路。"

    if [[ "$forwarding_count" -gt 0 ]]; then
        while IFS= read -r id; do
            [[ -n "$id" ]] || continue
            load_profile "$id" >/dev/null 2>&1 || continue
            if [[ "${LINE_GROUP:-}" == "$group" ]]; then
                current_found=1
            fi
        done <<<"$forwarding_ids"
        [[ "$current_found" -eq 1 ]] && pb_item OK "当前转发线路属于线路组 ${group}。" || pb_item FAIL "当前转发线路不属于线路组 ${group}。"
    else
        pb_item FAIL "无法确认转发线路归属：线路组内没有处于转发的入口线路。"
    fi

    while IFS= read -r id; do
        [[ -n "$id" ]] || continue
        load_profile "$id" >/dev/null 2>&1 || continue
        if [[ "${ENABLED:-true}" == "true" ]]; then
            pb_item OK "主线路 ${id} 已启用。"
        else
            pb_item FAIL "主线路 ${id} 已停用。"
        fi
        [[ "${HEALTH_STATUS:-unknown}" == "down" ]] && primary_down=1
    done <<<"$primary_ids"

    while IFS= read -r id; do
        [[ -n "$id" ]] || continue
        load_profile "$id" >/dev/null 2>&1 || continue
        if [[ "${ENABLED:-true}" == "true" ]]; then
            pb_item OK "备线路 ${id} 已启用。"
        else
            pb_item WARN "备线路 ${id} 为冷备（已停用），切换前请先 enable-profile。"
        fi
        [[ "${HEALTH_STATUS:-unknown}" == "healthy" && -z "$healthy_backup" ]] && healthy_backup="$id"
    done <<<"$backup_ids"

    while IFS= read -r id; do
        [[ -n "$id" ]] || continue
        load_profile "$id" >/dev/null 2>&1 || continue
        missing="$(profile_four_ports_missing)"
        if [[ "$missing" == "complete" ]]; then
            pb_item OK "线路 ${id} 四端口配置完整：$(profile_four_port_summary)"
        else
            pb_item FAIL "线路 ${id} 四端口配置不完整，缺少：${missing}。"
        fi
    done <<<"$(printf '%s\n%s\n' "$primary_ids" "$backup_ids" | awk 'NF' | sort -u)"

    for id in $(list_group_ingress_profiles "$group"); do
        load_profile "$id" >/dev/null 2>&1 || continue
        [[ "${ENABLED:-true}" == "true" && "${FORWARD_ENABLED:-true}" == "true" ]] || continue
        [[ -n "${LOCAL_PORT:-}" ]] || continue
        if grep -qxF "$LOCAL_PORT" <<<"$seen_ports"; then
            dup_ports="${dup_ports:+${dup_ports} }${LOCAL_PORT}"
        else
            seen_ports="${seen_ports}${LOCAL_PORT}"$'\n'
        fi
    done
    [[ -z "$dup_ports" ]] && pb_item OK "线路组内无 CLIENT_PORT 冲突。" || pb_item FAIL "转发中 CLIENT_PORT 冲突：${dup_ports}。"

    if nft_text="$(nft_table_text 2>/dev/null)"; then
        nft_available=1
    fi
    if [[ "$nft_available" -eq 1 ]]; then
        local nft_issues=0 actual_ports expected_ports
        for id in $(list_group_ingress_profiles "$group"); do
            load_profile "$id" >/dev/null 2>&1 || continue
            [[ -n "${LOCAL_PORT:-}" && -n "${LANDING_ET_IP:-}" && -n "${REMOTE_PORT:-}" ]] || continue
            if [[ "${ENABLED:-true}" == "true" && "${FORWARD_ENABLED:-true}" == "true" ]]; then
                if ! nft_text_has_profile_rule "$nft_text"; then
                    nft_issues=$((nft_issues + 1))
                fi
            else
                if nft_text_has_profile_rule "$nft_text"; then
                    nft_issues=$((nft_issues + 1))
                fi
            fi
        done
        actual_ports="$(nft_dnat_local_ports_from_text "$nft_text")"
        expected_ports="$(active_forwarding_local_ports)"
        while IFS= read -r port; do
            [[ -n "$port" ]] || continue
            grep -qxF "$port" <<<"$expected_ports" || nft_issues=$((nft_issues + 1))
        done <<<"$actual_ports"
        [[ "$nft_issues" -eq 0 ]] && pb_item OK "nftables 规则与启用中的入口转发线路一致。" || pb_item FAIL "nftables 规则与 Profile 转发状态不一致，请运行 verify-nft-profiles。"
    else
        pb_item WARN "无法读取 nftables 项目表或 ${NFT_FILE}；请在入口机上运行 verify-nft-profiles。"
    fi

    while IFS= read -r id; do
        [[ -n "$id" ]] || continue
        load_profile "$id" >/dev/null 2>&1 || continue
        if [[ "${ENABLED:-true}" == "true" && "${FORWARD_ENABLED:-true}" == "false" ]]; then
            pb_item OK "备线路 ${id} 为热备：ENABLED=true 且 FORWARD_ENABLED=false。"
        elif [[ "${ENABLED:-true}" == "true" && "${FORWARD_ENABLED:-true}" == "true" ]]; then
            pb_item WARN "备线路 ${id} 当前正在转发，不是待机状态。"
        fi
        if [[ "${ENABLED:-true}" == "false" ]]; then
            pb_item WARN "备线路 ${id} 为冷备（ENABLED=false），切换前请先 enable-profile。"
        fi
    done <<<"$backup_ids"

    printf '\n结果：通过=%s 警告=%s 失败=%s\n' "$pass_count" "$warn_count" "$fail_count"
    printf '建议：\n'
    if [[ "$fail_count" -gt 0 ]]; then
        printf '  - 先修复 FAIL 项；nft 漂移可运行：bash install.sh verify-nft-profiles\n'
        printf '  - 配置变更后运行：bash install.sh apply-nft-all\n'
    elif [[ "$primary_down" -eq 1 && -n "$healthy_backup" ]]; then
        printf '  - 主线路故障，备线路 %s 健康。\n' "$healthy_backup"
        printf '  - 建议：bash install.sh switch-dry-run %s %s\n' "$group" "$healthy_backup"
        printf '  - 执行：bash install.sh switch-line %s %s\n' "$group" "$healthy_backup"
    elif [[ "$warn_count" -gt 0 ]]; then
        printf '  - 请检查 WARN 项；冷备需先 enable-profile 再切换。\n'
    else
        printf '  - 主备模型就绪。切换前请先 switch-dry-run。\n'
    fi
    [[ "$fail_count" -eq 0 ]]
}

primary_backup_check() {
    require_root "$@"
    local group="${1:-}" id primary_ids backup_ids forwarding_ids primary_count=0 backup_count=0 ingress_count=0 forwarding_count=0
    local fail_count=0 warn_count=0 ok_count=0 active_profile="" primary_id="" recommended_backup="" nft_text nft_issues=0
    local service active rc status et_rc available_backup_count=0
    if [[ -z "$group" ]]; then
        if [[ "$(profile_group_count)" -eq 0 ]]; then
            print_no_group_message
            return 0
        fi
        die_user "用法：primary-backup-check GROUP"
    fi

    pb_check_item() {
        local state="$1" message="$2"
        case "$state" in
            OK) ok_count=$((ok_count + 1)) ;;
            WARN) warn_count=$((warn_count + 1)) ;;
            FAIL) fail_count=$((fail_count + 1)) ;;
        esac
        printf '[%s] %s\n' "$state" "$message"
    }

    printf '主备实机检查：%s\n' "$group"
    if ! group_exists "$group"; then
        pb_check_item FAIL "线路组 ${group} 不存在。已有线路组：$(list_existing_groups_for_message)"
        printf '主备组状态：未就绪\n'
        return 1
    fi
    pb_check_item OK "线路组 ${group} 存在。"

    primary_ids="$(list_group_primary_profiles "$group")"
    backup_ids="$(list_group_backup_profiles "$group")"
    forwarding_ids="$(list_group_forwarding_profiles "$group")"
    primary_count="$(printf '%s\n' "$primary_ids" | awk 'NF{c++} END{print c+0}')"
    backup_count="$(printf '%s\n' "$backup_ids" | awk 'NF{c++} END{print c+0}')"
    ingress_count="$(list_group_ingress_profiles "$group" | awk 'NF{c++} END{print c+0}')"
    forwarding_count="$(printf '%s\n' "$forwarding_ids" | awk 'NF{c++} END{print c+0}')"
    active_profile="$(printf '%s\n' "$forwarding_ids" | awk 'NF{print; exit}')"
    primary_id="$(printf '%s\n' "$primary_ids" | awk 'NF{print; exit}')"

    [[ "$ingress_count" -ge 2 ]] && pb_check_item OK "线路组至少 2 条入口线路（当前 ${ingress_count}）。" || pb_check_item FAIL "线路组入口线路不足 2 条（当前 ${ingress_count}）。"
    [[ "$primary_count" -eq 1 ]] && pb_check_item OK "主线路唯一：${primary_id}。" || pb_check_item FAIL "主线路数量必须为 1，当前=${primary_count}。"
    [[ "$backup_count" -ge 1 ]] && pb_check_item OK "备线路数量=${backup_count}。" || pb_check_item FAIL "未配置备线路。"
    [[ "$forwarding_count" -eq 1 ]] && pb_check_item OK "仅一条入口线路处于转发中：${active_profile}。" || pb_check_item FAIL "FORWARD_ENABLED=true 入口线路数必须为 1，当前=${forwarding_count}。"

    if [[ -n "$active_profile" ]]; then
        load_profile "$active_profile" >/dev/null 2>&1 || true
        [[ "${ENABLED:-true}" == "true" ]] && pb_check_item OK "当前转发线路 ${active_profile} 已启用。" || pb_check_item FAIL "当前转发线路 ${active_profile} 已停用。"
    fi

    for id in $(list_group_backup_profiles "$group"); do
        load_profile "$id" >/dev/null 2>&1 || continue
        if [[ "${ENABLED:-true}" == "true" ]]; then
            pb_check_item OK "备线路 ${id} 已启用。"
        else
            pb_check_item WARN "备线路 ${id} 为冷备（ENABLED=false），切换前请先 enable-profile。"
        fi
        if [[ "${HEALTH_STATUS:-unknown}" == "down" ]]; then
            pb_check_item FAIL "备线路 ${id} 故障，请勿切换到该备线路。"
        else
            available_backup_count=$((available_backup_count + 1))
        fi
        if [[ "${ENABLED:-true}" == "true" && "${FORWARD_ENABLED:-true}" == "false" ]]; then
            pb_check_item OK "备线路 ${id} 可作为热备（FORWARD_ENABLED=false）。"
        fi
    done

    for id in $(printf '%s\n%s\n' "$primary_ids" "$backup_ids" | awk 'NF' | sort -u); do
        load_profile "$id" >/dev/null 2>&1 || continue
        service="$(profile_service_name "$id")"
        active="$(profile_service_status "$service")"
        if [[ "$active" == "active" ]]; then
            pb_check_item OK "服务 ${service} 运行中。"
        elif [[ "$active" == "unknown" ]]; then
            pb_check_item WARN "无法检查服务 ${service}。"
        else
            pb_check_item WARN "服务 ${service} 未运行（${active}）。"
        fi
        set +e
        check_et_ip_present >/dev/null 2>&1
        et_rc=$?
        set -e
        case "$et_rc" in
            0) pb_check_item OK "线路 ${id} ET IP 存在：${ET_IPV4:-未知}。" ;;
            2) pb_check_item WARN "无法检查线路 ${id} 的 ET IP。" ;;
            *) pb_check_item WARN "线路 ${id} ET IP 缺失：${ET_IPV4:-未知}。" ;;
        esac
        [[ "${HEALTH_STATUS:-unknown}" == "down" ]] && pb_check_item WARN "线路 ${id} 健康=down，原因=${LAST_HEALTH_REASON:-未检查}。"
    done

    if nft_text="$(nft_table_text 2>/dev/null)"; then
        while IFS= read -r id; do
            [[ -n "$id" ]] || continue
            load_profile "$id" >/dev/null 2>&1 || continue
            if [[ "${ENABLED:-true}" == "true" && "${FORWARD_ENABLED:-true}" == "true" ]]; then
                nft_text_has_profile_rule "$nft_text" || nft_issues=$((nft_issues + 1))
            else
                nft_text_has_profile_rule "$nft_text" && nft_issues=$((nft_issues + 1))
            fi
        done <<<"$(list_group_ingress_profiles "$group")"
        [[ "$nft_issues" -eq 0 ]] && pb_check_item OK "nftables 规则与线路组当前转发状态一致。" || pb_check_item FAIL "nftables 规则与线路组 Profile 状态不一致，请运行 verify-nft-profiles。"
    else
        pb_check_item WARN "无法读取 nftables 项目表或 ${NFT_FILE}。"
    fi

    if [[ -n "$primary_id" ]]; then
        load_profile "$primary_id" >/dev/null 2>&1 || true
        if [[ "${HEALTH_STATUS:-unknown}" == "down" ]]; then
            recommended_backup="$(first_healthy_backup_in_group "$group" || true)"
            if [[ -n "$recommended_backup" ]]; then
                pb_check_item WARN "主线路故障，备线路 ${recommended_backup} 健康。"
                printf '建议：bash install.sh switch-dry-run %s %s\n' "$group" "$recommended_backup"
                printf '执行：bash install.sh switch-line %s %s\n' "$group" "$recommended_backup"
            fi
        fi
    fi
    [[ "$available_backup_count" -gt 0 ]] || pb_check_item FAIL "无可用备线路，当前线路组主备配置不完整。"

    printf '\n通过=%s 警告=%s 失败=%s\n' "$ok_count" "$warn_count" "$fail_count"
    if [[ "$fail_count" -gt 0 ]]; then
        printf '主备组状态：未就绪\n'
        return 1
    elif [[ "$warn_count" -gt 0 ]]; then
        printf '主备组状态：有警告\n'
        return 0
    fi
    printf '主备组状态：就绪\n'
}

primary_backup_runbook() {
    require_root "$@"
    local group="${1:-}" members forwarding primary backups recommended_backup
    [[ -n "$group" ]] || die_user "用法：primary-backup-runbook GROUP"
    group_exists "$group" || die_user "线路组 ${group} 不存在。已有 group：$(list_existing_groups_for_message)"
    members="$(list_group_ingress_profiles "$group" | join_profile_list)"
    forwarding="$(list_group_forwarding_profiles "$group" | join_profile_list)"
    primary="$(list_group_primary_profiles "$group" | join_profile_list)"
    backups="$(list_group_backup_profiles "$group" | join_profile_list)"
    recommended_backup="$(first_available_backup_in_group "$group" || true)"
    [[ -n "$recommended_backup" ]] || recommended_backup="BACKUP_PROFILE"

    cat <<EOF
主备切换手册：${group}

线路组成员：
  ${members}
当前转发线路：
  ${forwarding}
主线路：
  ${primary}
备线路：
  ${backups}

建议先运行：
  bash install.sh primary-backup-check ${group}
  bash install.sh health-report --group ${group}
  bash install.sh verify-nft-profiles

切换前检查：
  bash install.sh health-all
  bash install.sh health-report
  bash install.sh validate-primary-backup ${group}
  bash install.sh switch-dry-run ${group} ${recommended_backup}

正式切换：
  bash install.sh switch-line ${group} ${recommended_backup}

切换后验证：
  bash install.sh verify-nft-profiles
  bash install.sh show-group ${group}
  bash install.sh show-port-map --all

切回主线路：
  bash install.sh switch-line ${group} $(primary_profile_in_group "$group" || printf '主线路ID')

回滚：
  bash install.sh switch-rollback-last
EOF
}

primary_backup_summary() {
    require_root "$@"
    local group primary forwarding backup_count hot_count cold_count ready_state action recommended_backup
    printf '%-16s %-18s %-18s %-7s %-5s %-5s %-10s %s\n' "线路组" "主线路" "当前转发" "备线路" "热备" "冷备" "状态" "建议操作"
    while IFS= read -r group; do
        [[ -n "$group" ]] || continue
        primary="$(list_group_primary_profiles "$group" | join_profile_list)"
        forwarding="$(list_group_forwarding_profiles "$group" | join_profile_list)"
        backup_count="$(list_group_backup_profiles "$group" | awk 'NF{c++} END{print c+0}')"
        hot_count="$(group_hot_standby_count "$group")"
        cold_count="$(group_cold_standby_count "$group")"
        ready_state="$(group_ready_state "$group")"
        recommended_backup="$(first_healthy_backup_in_group "$group" || true)"
        case "$ready_state" in
            ready) action="监控 / 切换前先 dry-run" ;;
            warning)
                if [[ -n "$recommended_backup" ]]; then
                    action="switch-dry-run ${group} ${recommended_backup}"
                else
                    action="检查警告项"
                fi
                ;;
            *) action="primary-backup-check ${group}" ;;
        esac
        printf '%-16s %-18s %-18s %-7s %-5s %-5s %-10s %s\n' "$group" "$primary" "$forwarding" "$backup_count" "$hot_count" "$cold_count" "$(group_ready_state_label_zh "$ready_state")" "$action"
    done < <(profile_groups)
}

group_abnormal() {
    local group="$1" id primary_count=0 backup_count=0 forwarding_count=0 profile_count=0 down_count=0 status abnormal=1
    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        [[ "${LINE_GROUP:-}" == "$group" ]] || continue
        profile_count=$((profile_count + 1))
        [[ "${LINE_ROLE:-standalone}" == "primary" ]] && primary_count=$((primary_count + 1))
        [[ "${LINE_ROLE:-standalone}" == "backup" ]] && backup_count=$((backup_count + 1))
        [[ "${ROLE:-}" == "nat-ingress" && "${ENABLED:-true}" == "true" && "${FORWARD_ENABLED:-true}" == "true" ]] && forwarding_count=$((forwarding_count + 1))
        status="${HEALTH_STATUS:-unknown}"
        [[ "$status" == "down" ]] && down_count=$((down_count + 1))
        if [[ "${LINE_ROLE:-standalone}" == "primary" && ( "$status" == "down" || "$status" == "warning" ) ]]; then
            abnormal=0
        fi
        if [[ "${LINE_ROLE:-standalone}" == "backup" && "$status" == "down" ]]; then
            abnormal=0
        fi
    done
    [[ "$primary_count" -eq 1 && "$backup_count" -gt 0 && "$forwarding_count" -eq 1 ]] || abnormal=0
    [[ "$profile_count" -gt 0 && "$down_count" -eq "$profile_count" ]] && abnormal=0
    return "$abnormal"
}

print_group_advice() {
    local group="$1" id primary_count=0 backup_count=0 forwarding_count=0 profile_count=0 down_count=0 status backup_id
    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        [[ "${LINE_GROUP:-}" == "$group" ]] || continue
        profile_count=$((profile_count + 1))
        [[ "${LINE_ROLE:-standalone}" == "primary" ]] && primary_count=$((primary_count + 1))
        [[ "${LINE_ROLE:-standalone}" == "backup" ]] && backup_count=$((backup_count + 1))
        [[ "${ROLE:-}" == "nat-ingress" && "${ENABLED:-true}" == "true" && "${FORWARD_ENABLED:-true}" == "true" ]] && forwarding_count=$((forwarding_count + 1))
        [[ "${HEALTH_STATUS:-unknown}" == "down" ]] && down_count=$((down_count + 1))
    done

    [[ "$primary_count" -gt 0 ]] || printf '[WARN] 线路组 %s 没有 primary。\n' "$group"
    [[ "$backup_count" -gt 0 ]] || printf '[WARN] 线路组 %s 没有 backup。\n' "$group"
    [[ "$primary_count" -le 1 ]] || printf '[WARN] 线路组 %s 存在多个 primary。\n' "$group"
    if [[ "$forwarding_count" -eq 0 ]]; then
        printf '[WARN] 线路组 %s 没有任何 FORWARD_ENABLED=true 的入口 Profile。\n' "$group"
    elif [[ "$forwarding_count" -gt 1 ]]; then
        printf '[WARN] 线路组 %s 有多个 FORWARD_ENABLED=true 的入口 Profile。\n' "$group"
    fi

    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        [[ "${LINE_GROUP:-}" == "$group" ]] || continue
        status="${HEALTH_STATUS:-unknown}"
        if [[ "${LINE_ROLE:-standalone}" == "primary" && "$status" == "warning" ]]; then
            printf '[WARN] primary %s 健康状态为 warning：%s\n' "$id" "${LAST_HEALTH_REASON:-未检查}"
        elif [[ "${LINE_ROLE:-standalone}" == "primary" && "$status" == "down" ]]; then
            printf '[WARN] primary %s 健康状态为 down：%s\n' "$id" "${LAST_HEALTH_REASON:-未检查}"
            backup_id="$(first_healthy_backup_in_group "$group" || true)"
            [[ -n "$backup_id" ]] && printf '[WARN] primary %s down，backup %s healthy。可运行：bash install.sh switch-line %s %s\n' "$id" "$backup_id" "$group" "$backup_id"
        elif [[ "${LINE_ROLE:-standalone}" == "backup" && "$status" == "down" ]]; then
            printf '[WARN] backup %s down，备用线路当前不可用：%s\n' "$id" "${LAST_HEALTH_REASON:-未检查}"
        fi
    done

    if [[ "$profile_count" -gt 0 && "$down_count" -eq "$profile_count" ]]; then
        printf '[WARN] 线路组 %s 所有线路都是 down。先不要切换，请检查 CNIX 面板、EasyTier listener、业务端口和 nftables。\n' "$group"
    fi
}

list_groups() {
    require_root "$@"
    local group id count primary_count forwarding_count
    printf 'GROUP\t线路数\t主线路\t转发中\n'
    while IFS= read -r group; do
        [[ -n "$group" ]] || continue
        count=0
        primary_count=0
        forwarding_count=0
        for id in $(profile_ids); do
            load_profile "$id" || continue
            [[ "${LINE_GROUP:-}" == "$group" ]] || continue
            count=$((count + 1))
            [[ "${LINE_ROLE:-standalone}" == "primary" ]] && primary_count=$((primary_count + 1))
            [[ "${ROLE:-}" == "nat-ingress" && "${ENABLED:-true}" == "true" && "${FORWARD_ENABLED:-true}" == "true" ]] && forwarding_count=$((forwarding_count + 1))
        done
        printf '%s\t%s\t%s\t%s\n' "$group" "$count" "$primary_count" "$forwarding_count"
    done < <(profile_groups)
}

set_line_group() {
    require_root "$@"
    local profile_id="${1:-}" group="${2:-}"
    [[ -n "$profile_id" && -n "$group" ]] || die_user "用法：set-line-group PROFILE_ID GROUP"
    load_profile_or_die "$profile_id"
    LINE_GROUP="$group"
    save_profile_env "$profile_id"
    log_ok "已设置线路组：${profile_id} -> ${LINE_GROUP}"
}

set_line_priority() {
    require_root "$@"
    local profile_id="${1:-}" priority="${2:-}"
    [[ -n "$profile_id" && -n "$priority" ]] || die_user "用法：set-line-priority PROFILE_ID PRIORITY"
    validate_line_priority "$priority" || die_user "LINE_PRIORITY 必须是数字。"
    load_profile_or_die "$profile_id"
    LINE_PRIORITY="$priority"
    save_profile_env "$profile_id"
    log_ok "已设置线路优先级：${profile_id} -> ${LINE_PRIORITY}"
}

set_line_role() {
    require_root "$@"
    local profile_id="${1:-}" role="${2:-}" id answer target_group existing_primary=""
    [[ -n "$profile_id" && -n "$role" ]] || die_user "用法：set-primary|set-backup|set-standalone PROFILE_ID"
    validate_line_role "$role" || die_user "LINE_ROLE 只能是 primary、backup 或 standalone。"
    load_profile_or_die "$profile_id"
    if [[ "$role" == "standalone" ]]; then
        LINE_ROLE="standalone"
        LINE_GROUP=""
        save_profile_env "$profile_id"
        log_ok "已设置为独立线路：${profile_id}"
        return 0
    fi
    [[ -n "${LINE_GROUP:-}" ]] || die_user "请先运行 set-line-group ${profile_id} GROUP。"
    target_group="$LINE_GROUP"
    if [[ "$role" == "primary" ]]; then
        for id in $(profile_ids); do
            [[ "$id" == "$profile_id" ]] && continue
            load_profile "$id" || continue
            [[ "${LINE_GROUP:-}" == "$target_group" && "${LINE_ROLE:-standalone}" == "primary" ]] || continue
            existing_primary="${existing_primary}${id} "
        done
        load_profile_or_die "$profile_id"
        if [[ -n "$existing_primary" ]]; then
            if is_interactive_input; then
                answer="$(prompt_yes_no "同组已有 primary：${existing_primary}，是否降级为 backup" "true")" || answer="false"
                [[ "$answer" == "true" ]] || die_user "已取消设置 primary。"
                for id in $existing_primary; do
                    load_profile "$id" || continue
                    LINE_ROLE="backup"
                    save_profile_env "$id"
                done
                load_profile_or_die "$profile_id"
            else
                die_user "同组已有 primary：${existing_primary}。请在交互模式确认降级，或先 set-backup 旧 primary。"
            fi
        fi
    fi
    LINE_ROLE="$role"
    save_profile_env "$profile_id"
    log_ok "已设置线路角色：${profile_id} -> ${LINE_ROLE}"
}

set_primary() {
    set_line_role "${1:-}" primary
}

set_backup() {
    set_line_role "${1:-}" backup
}

set_standalone() {
    set_line_role "${1:-}" standalone
}

read_exact_confirmation() {
    local prompt="$1" expected="$2" answer
    is_interactive_input || return 2
    printf '%s' "$prompt" >&2
    IFS= read -r answer || return 1
    [[ "$answer" == "$expected" ]]
}

validate_switch_target() {
    local group="$1" target="$2" saved_forward
    [[ -n "$group" && -n "$target" ]] || die_user "用法：switch-line GROUP TARGET_PROFILE_ID"
    load_profile_or_die "$target"
    [[ "${LINE_GROUP:-}" == "$group" ]] || die_user "目标 Profile 不属于线路组 ${group}。"
    [[ "${ROLE:-}" == "nat-ingress" ]] || die_user "switch-line 目标必须是 nat-ingress Profile。"
    [[ "${ENABLED:-true}" == "true" ]] || die_user "目标 Profile 已禁用，请先 enable-profile ${target}。"
    saved_forward="${FORWARD_ENABLED:-true}"
    FORWARD_ENABLED="true"
    validate_profile_config "$target"
    FORWARD_ENABLED="$saved_forward"
}

validate_switch_dry_run_target() {
    local group="$1" target="$2"
    [[ -n "$group" && -n "$target" ]] || die_user "用法：switch-dry-run GROUP TARGET_PROFILE_ID"
    group_exists "$group" || die_user "线路组 ${group} 不存在。已有 group：$(list_existing_groups_for_message)"
    load_profile_or_die "$target"
    [[ "${LINE_GROUP:-}" == "$group" ]] || die_user "目标 Profile 不属于线路组 ${group}。"
    [[ "${ROLE:-}" == "nat-ingress" ]] || die_user "switch-dry-run 目标必须是 nat-ingress Profile。"
}

record_switch_event() {
    local profile_id="$1" stamp="$2" note="$3"
    load_profile "$profile_id" || return 1
    LAST_SWITCH_AT="$stamp"
    SWITCH_NOTE="$note"
    save_profile_env "$profile_id"
}

ensure_single_forward_enabled_in_group() {
    local group="$1" target="$2" stamp="$3" note="$4" id desired
    for id in $(list_group_ingress_profiles "$group"); do
        load_profile "$id" || continue
        if [[ "$id" == "$target" ]]; then
            desired="true"
        else
            desired="false"
        fi
        if [[ "${FORWARD_ENABLED:-true}" != "$desired" ]]; then
            FORWARD_ENABLED="$desired"
            save_profile_env "$id"
        fi
        record_switch_event "$id" "$stamp" "$note" || true
    done
}

switch_dry_run() {
    require_root "$@"
    local group="${1:-}" target="${2:-}" forwarding_profiles to_disable target_status target_summary
    local id before_summary after_summary enabled_state health_note
    validate_switch_dry_run_target "$group" "$target"

    forwarding_profiles="$(list_group_forwarding_profiles "$group")"
    to_disable="$(printf '%s\n' "$forwarding_profiles" | grep -vx "$target" || true)"

    printf 'Switch dry-run (no changes)\n'
    printf 'GROUP: %s\n' "$group"
    printf 'TARGET_PROFILE: %s\n' "$target"
    printf '\nCurrent FORWARD_ENABLED=true profiles in group:\n'
    printf '  %s\n' "$(printf '%s\n' "$forwarding_profiles" | join_profile_list)"

    printf '\nTarget profile:\n'
    load_profile_or_die "$target"
    enabled_state="${ENABLED:-true}"
    target_status="${HEALTH_STATUS:-unknown}"
    target_summary="$(profile_four_port_summary)"
    printf '  PROFILE=%s ENABLED=%s FORWARD=%s HEALTH=%s\n' "$target" "$enabled_state" "${FORWARD_ENABLED:-true}" "$target_status"
    printf '  PORTS=%s\n' "$target_summary"
    if [[ "$enabled_state" != "true" ]]; then
        printf '[WARN] 目标线路为冷备（ENABLED=false），正式 switch-line 前请先 enable-profile。\n'
    fi

    printf '\nChanges that would happen:\n'
    if [[ -n "$to_disable" ]]; then
        while IFS= read -r id; do
            [[ -n "$id" ]] || continue
            printf '  - %s: FORWARD_ENABLED true -> false\n' "$id"
        done <<<"$to_disable"
    else
        printf '  - No other forwarding profile needs to be disabled.\n'
    fi
    printf '  - %s: FORWARD_ENABLED -> true\n' "$target"
    printf '  - Other LINE_GROUP impact: 不会影响其他组\n'
    printf '  - Would run: bash install.sh apply-nft-all\n'

    printf '\nTarget health:\n'
    printf '  HEALTH_STATUS=%s\n' "$target_status"
    health_note="${LAST_HEALTH_REASON:-未检查}"
    printf '  REASON=%s\n' "$health_note"
    if [[ "$target_status" == "down" ]]; then
        printf '[WARN] Target is down. Real switch-line will require typing SWITCH.\n'
    fi

    printf '\nBefore / after port summary:\n'
    printf 'BEFORE:\n'
    for id in $(list_group_ingress_profiles "$group"); do
        load_profile "$id" || continue
        before_summary="$(profile_four_port_summary)"
        printf '  %s forward=%s ports=%s\n' "$id" "${FORWARD_ENABLED:-true}" "$before_summary"
    done
    printf 'AFTER:\n'
    for id in $(list_group_ingress_profiles "$group"); do
        load_profile "$id" || continue
        after_summary="$(profile_four_port_summary)"
        if [[ "$id" == "$target" ]]; then
            printf '  %s forward=true ports=%s\n' "$id" "$after_summary"
        else
            printf '  %s forward=false ports=%s\n' "$id" "$after_summary"
        fi
    done

    printf '\nDry-run guarantee: no Profile files were written, apply-nft-all was not executed, LAST_SWITCH_AT and SWITCH_NOTE were not changed.\n'
}

set_forward() {
    require_root "$@"
    local profile_id="${1:-}" value="${2:-}" normalized group other_forwarding other_count old_forward answer
    [[ -n "$profile_id" && -n "$value" ]] || die_user "用法：set-forward PROFILE_ID on|off"
    case "${value,,}" in
        on|true|1|yes) normalized="true" ;;
        off|false|0|no) normalized="false" ;;
        *) die_user "set-forward 只能使用 on 或 off。" ;;
    esac
    load_profile_or_die "$profile_id"
    if [[ "${ROLE:-}" != "nat-ingress" ]]; then
        die_user "set-forward on 只适用于 nat-ingress Profile。"
    fi
    group="${LINE_GROUP:-}"
    old_forward="${FORWARD_ENABLED:-true}"

    if [[ "$normalized" == "true" ]]; then
        if [[ -n "$group" ]]; then
            other_forwarding="$(list_group_forwarding_profiles "$group" | grep -vx "$profile_id" || true)"
            other_count="$(grep -c '^[^[:space:]]' <<<"$other_forwarding" || true)"
            if [[ "${other_count:-0}" -gt 0 ]]; then
                printf '[WARN] 线路组 %s 已有其他入口 Profile 正在转发：%s\n' "$group" "$(printf '%s\n' "$other_forwarding" | join_profile_list)"
                printf '[WARN] set-forward on 不会自动关闭其他线路；主备切换建议使用：bash install.sh switch-line %s %s\n' "$group" "$profile_id"
            fi
        fi
        load_profile_or_die "$profile_id"
        FORWARD_ENABLED="true"
        validate_profile_config "$profile_id"
    else
        if [[ "$old_forward" == "true" && -n "$group" ]]; then
            other_forwarding="$(list_group_forwarding_profiles "$group" | grep -vx "$profile_id" || true)"
            other_count="$(grep -c '^[^[:space:]]' <<<"$other_forwarding" || true)"
            if [[ "${other_count:-0}" -eq 0 ]]; then
                if read_exact_confirmation "关闭后该线路组将无业务转发。确认请输入 OFF：" "OFF"; then
                    :
                else
                    die_user "已取消关闭业务转发。"
                fi
            fi
        fi
        load_profile_or_die "$profile_id"
    fi

    FORWARD_ENABLED="$normalized"
    save_profile_env "$profile_id"
    apply_nft_all || true
    log_ok "已设置业务转发：${profile_id} -> ${normalized}"
    show_port_map "$profile_id" || true
    [[ -n "$group" ]] && show_group "$group" || true
}

switch_line() {
    require_root "$@"
    local group="${1:-}" target="${2:-}" target_status answer now note health_output rc
    local forwarding_profiles forwarding_count ingress_count only_forwarding
    local from_profiles from_health to_health
    [[ -n "$group" && -n "$target" ]] || die_user "用法：switch-line GROUP TARGET_PROFILE_ID"
    validate_switch_target "$group" "$target"

    ingress_count="$(list_group_ingress_profiles "$group" | awk 'NF{c++} END{print c+0}')"
    forwarding_profiles="$(list_group_forwarding_profiles "$group")"
    from_profiles="$(printf '%s\n' "$forwarding_profiles" | join_profile_list)"
    from_health="$(group_health_for_profiles "$forwarding_profiles")"
    forwarding_count="$(grep -c '^[^[:space:]]' <<<"$forwarding_profiles" || true)"
    only_forwarding="$(printf '%s\n' "$forwarding_profiles" | awk 'NF{print; exit}')"

    if [[ "${ingress_count:-0}" -le 1 ]]; then
        printf '[WARN] 线路组 %s 只有一条 ingress Profile，切换意义有限，但允许继续。\n' "$group"
    fi
    if [[ "${forwarding_count:-0}" -gt 1 ]]; then
        printf '[WARN] 线路组 %s 当前有多个 FORWARD_ENABLED=true 的入口 Profile：%s\n' "$group" "$(printf '%s\n' "$forwarding_profiles" | join_profile_list)"
        printf '[WARN] 本次切换会收敛为只保留目标 Profile 转发：%s\n' "$target"
    fi
    if [[ "${forwarding_count:-0}" -eq 1 && "$only_forwarding" == "$target" ]]; then
        printf 'Profile %s 已经是线路组 %s 当前业务线路，未重复操作。\n' "$target" "$group"
        show_port_map "$target" || true
        return 0
    fi

    printf '切换前端口映射：\n'
    show_port_map --all || true

    printf '\n切换前健康检查：\n'
    set +e
    health_output="$(run_line_health_check "$target" false 2>&1)"
    rc=$?
    set -e
    printf '%s\n' "$health_output"
    target_status="$(grep -E '^HEALTH_STATUS=' <<<"$health_output" | tail -n 1 | cut -d= -f2- || true)"
    target_status="${target_status:-unknown}"
    [[ "$rc" -eq 0 ]] || printf '[WARN] 目标线路健康检查命令返回非 0（%s），按 %s 继续判断。\n' "$rc" "$target_status"
    if [[ "$target_status" == "down" ]]; then
        if read_exact_confirmation "目标线路健康状态异常，继续切换可能导致业务中断。确认切换请输入 SWITCH：" "SWITCH"; then
            :
        else
            append_switch_history "$(utc_now)" "$group" "$from_profiles" "$target" "local" "manual" "$from_health" "$target_status" "cancelled" "target down; SWITCH not confirmed" || true
            die_user "已取消切换。"
        fi
    fi

    now="$(utc_now)"
    note="manual switch group ${group} to ${target}; target_health=${target_status}"
    ensure_single_forward_enabled_in_group "$group" "$target" "$now" "$note"

    if ! apply_nft_all; then
        append_switch_history "$now" "$group" "$from_profiles" "$target" "local" "manual" "$from_health" "$target_status" "failed" "${note}; apply_nft_all=failed" || true
        return 1
    fi
    to_health="$target:${target_status}"
    append_switch_history "$now" "$group" "$from_profiles" "$target" "local" "manual" "$from_health" "$to_health" "success" "${note}; apply_nft_all=success" || true
    if declare -F send_switch_notification >/dev/null 2>&1; then
        send_switch_notification "$group" "$from_profiles" "$target" "$target_status" || true
    fi

    load_profile_or_die "$target"
    printf '\n切换完成：%s\n' "$target"
    printf '客户端入口：公网入口 VPS:%s\n' "${LOCAL_PORT:-未配置}"
    printf '转发目标：%s:%s\n' "${LANDING_ET_IP:-未配置}" "${REMOTE_PORT:-未配置}"
    printf '\n切换后端口映射：\n'
    show_port_map --all || true
    printf '\n线路组状态：\n'
    show_group "$group" || true
}

switch_to() {
    require_root "$@"
    local profile_id="${1:-}" group
    [[ -n "$profile_id" ]] || die_user "用法：switch-to PROFILE_ID"
    load_profile_or_die "$profile_id"
    group="${LINE_GROUP:-}"
    [[ -n "$group" ]] || die_user "目标 Profile 未设置 LINE_GROUP，无法按组切换。"
    switch_line "$group" "$profile_id"
}

health_report() {
    require_root "$@"
    local group_filter="" id service active nft_label enabled_label forward_label group_display health role_label line_label
    local total=0 forwarding_lines=0 healthy=0 warning=0 down=0 unknown=0 groups_total=0 groups_ready=0 groups_warning=0 groups_not_ready=0
    local group issue backup_id groups_with_issues=0 ready_state
    if [[ "${1:-}" == "--group" ]]; then
        group_filter="${2:-}"
        [[ -n "$group_filter" ]] || die_user "用法：health-report --group GROUP"
    elif [[ -n "${1:-}" ]]; then
        group_filter="$1"
    fi

    printf '%-18s %-14s %-8s %-10s %-5s %-3s %-7s %-8s %-15s %-8s %-8s %s\n' \
        "线路ID" "线路组" "角色" "主备" "优先级" "启用" "转发" "服务" "IP" "NFT" "健康" "原因"
    printf '%-18s %-14s %-8s %-10s %-5s %-3s %-7s %-8s %-15s %-8s %-8s %s\n' \
        "------------------" "--------------" "--------" "----------" "-----" "---" "-------" "--------" "---------------" "--------" "--------" "------"

    for id in $(sorted_profile_ids); do
        if ! load_profile "$id"; then
            [[ -z "$group_filter" ]] || continue
            printf '%-18s %-14s %-8s %-10s %-5s %-3s %-7s %-8s %-15s %-8s %-8s %s\n' \
                "$id" "-" "-" "-" "-" "off" "off" "unknown" "-" "unknown" "down" "无法读取线路"
            total=$((total + 1))
            down=$((down + 1))
            continue
        fi
        [[ -z "$group_filter" || "${LINE_GROUP:-}" == "$group_filter" ]] || continue
        service="$(profile_service_name "$id")"
        active="$(profile_service_status "$service")"
        et_ip="${ET_IPV4:-}"
        et_ip="${et_ip%%/*}"
        nft_label="$(nft_profile_rule_label "$id")"
        enabled_label="$(enabled_display "${ENABLED:-true}")"
        forward_label="$(forward_display "${ROLE:-}" "${ENABLED:-true}" "${FORWARD_ENABLED:-true}")"
        group_display="${LINE_GROUP:-standalone}"
        health="${HEALTH_STATUS:-unknown}"
        case "${ROLE:-}" in
            nat-ingress) role_label="ingress" ;;
            nat-transit) role_label="landing" ;;
            *) role_label="${ROLE:-unknown}" ;;
        esac
        [[ "$forward_label" == "active" ]] && forwarding_lines=$((forwarding_lines + 1))
        case "$health" in
            healthy) healthy=$((healthy + 1)) ;;
            warning) warning=$((warning + 1)) ;;
            down) down=$((down + 1)) ;;
            *) unknown=$((unknown + 1)) ;;
        esac
        total=$((total + 1))
        printf '%-18s %-14s %-8s %-10s %-5s %-3s %-7s %-8s %-15s %-8s %-8s %s\n' \
            "$id" "$group_display" "$role_label" "${LINE_ROLE:-standalone}" "${LINE_PRIORITY:-100}" \
            "$enabled_label" "$forward_label" "${active:-unknown}" "${et_ip:-}" "$nft_label" \
            "$health" "${LAST_HEALTH_REASON:-未检查}"
    done

    while IFS= read -r group; do
        [[ -n "$group" ]] || continue
        [[ -z "$group_filter" || "$group" == "$group_filter" ]] || continue
        groups_total=$((groups_total + 1))
        ready_state="$(group_ready_state "$group")"
        case "$ready_state" in
            ready) groups_ready=$((groups_ready + 1)) ;;
            warning) groups_warning=$((groups_warning + 1)) ;;
            *) groups_not_ready=$((groups_not_ready + 1)) ;;
        esac
    done < <(profile_groups)

    printf '\n汇总：\n'
    printf '线路总数：%s\n' "$total"
    printf '线路组总数：%s\n' "$groups_total"
    printf '转发中线路：%s\n' "$forwarding_lines"
    printf '健康 / 警告 / 故障 / 未检查：%s / %s / %s / %s\n' "$healthy" "$warning" "$down" "$unknown"
    printf '线路组 就绪 / 有警告 / 未就绪：%s / %s / %s\n' "$groups_ready" "$groups_warning" "$groups_not_ready"

    printf '\n线路组问题：\n'
    while IFS= read -r group; do
        [[ -n "$group" ]] || continue
        [[ -z "$group_filter" || "$group" == "$group_filter" ]] || continue
        if [[ "$(group_issue_count "$group")" -gt 0 ]]; then
            groups_with_issues=$((groups_with_issues + 1))
            while IFS= read -r issue; do
                [[ -n "$issue" ]] || continue
                printf '  - %s：%s\n' "$group" "$(group_issue_label_zh "$issue")"
                if [[ "$issue" == primary\ down\ but\ backup\ healthy:* ]]; then
                    backup_id="${issue#*:}"
                    printf '    bash install.sh switch-dry-run %s %s\n' "$group" "$backup_id"
                    printf '    bash install.sh switch-line %s %s\n' "$group" "$backup_id"
                elif [[ "$issue" == backup\ down:* ]]; then
                    backup_id="${issue#*:}"
                    printf '    备线路 %s 当前不宜作为切换目标\n' "$backup_id"
                fi
            done < <(group_issue_lines "$group")
        fi
    done < <(profile_groups)
    [[ "$groups_with_issues" -gt 0 ]] || printf '  - 无\n'
}

switch_history() {
    require_root "$@"
    local group_filter="" limit=20 history_file row_count
    while (($#)); do
        case "$1" in
            --limit)
                shift
                [[ -n "${1:-}" ]] || die_user "用法：switch-history [GROUP] [--limit N]"
                limit="$1"
                ;;
            --limit=*)
                limit="${1#--limit=}"
                ;;
            --*)
                die_user "未知 switch-history 参数：$1"
                ;;
            *)
                [[ -z "$group_filter" ]] || die_user "用法：switch-history [GROUP] [--limit N]"
                group_filter="$1"
                ;;
        esac
        shift || true
    done
    [[ "$limit" =~ ^[0-9]+$ && "$limit" -gt 0 ]] || die_user "--limit 必须是正整数。"

    ensure_switch_history_file
    history_file="$(switch_history_path)"
    row_count="$(awk -F '\t' -v g="$group_filter" 'NR>1 && (g=="" || $2==g) {c++} END{print c+0}' "$history_file")"
    if [[ "$row_count" -eq 0 ]]; then
        printf 'No switch history found%s.\n' "$([[ -n "$group_filter" ]] && printf ' for %s' "$group_filter" || true)"
        printf 'TIME\tGROUP\tFROM\tTO\tRESULT\tFROM_HEALTH\tTO_HEALTH\tNOTE\n'
        return 0
    fi

    printf 'Recent switch history%s (last %s):\n' "$([[ -n "$group_filter" ]] && printf ' for %s' "$group_filter" || true)" "$limit"
    awk -F '\t' -v g="$group_filter" -v limit="$limit" '
        NR>1 && (g=="" || $2==g) {
            rows[++n]=sprintf("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s", $1, $2, $3, $4, $9, $7, $8, $10)
        }
        END {
            print "TIME\tGROUP\tFROM\tTO\tRESULT\tFROM_HEALTH\tTO_HEALTH\tNOTE"
            start=n-limit+1
            if (start < 1) start=1
            for (i=start; i<=n; i++) print rows[i]
        }
    ' "$history_file"
}

latest_success_switch_history() {
    local history_file
    history_file="$(switch_history_path)"
    [[ -r "$history_file" ]] || return 1
    awk -F '\t' 'NR>1 && $9=="success" {line=$0} END{if (line) print line}' "$history_file"
}

switch_rollback_last() {
    require_root "$@"
    local line stamp group from_profile to_profile operator reason from_health to_health result note
    local target target_count target_health
    ensure_switch_history_file
    line="$(latest_success_switch_history || true)"
    [[ -n "$line" ]] || die_user "没有可用于回切的成功切换历史。"
    IFS=$'\t' read -r stamp group from_profile to_profile operator reason from_health to_health result note <<<"$line"
    target_count="$(printf '%s\n' "$from_profile" | awk 'NF{print NF; found=1} END{if (!found) print 0}')"
    [[ "$target_count" -eq 1 && "$from_profile" != "-" ]] || die_user "最近一次成功切换记录无法唯一确定回切目标：${from_profile:-empty}"
    target="$from_profile"
    load_profile_or_die "$target"
    [[ "${LINE_GROUP:-}" == "$group" ]] || die_user "回切目标 ${target} 不属于历史记录中的线路组 ${group}。"

    printf '最近一次成功切换：%s group=%s from=%s to=%s\n' "$stamp" "$group" "$from_profile" "$to_profile"
    printf '将要回切到 Profile：%s\n' "$target"
    printf '本命令只基于最近审计记录辅助回切，确认前不会修改配置。\n'
    if ! read_exact_confirmation "确认回切请输入 ROLLBACK：" "ROLLBACK"; then
        die_user "已取消回切。"
    fi

    load_profile_or_die "$target"
    target_health="${HEALTH_STATUS:-unknown}"
    if [[ "$target_health" == "down" ]]; then
        printf '[WARN] 回切目标 %s 当前 health=down：%s\n' "$target" "${LAST_HEALTH_REASON:-未检查}"
        if ! read_exact_confirmation "目标 health=down，继续回切请输入 SWITCH：" "SWITCH"; then
            die_user "已取消回切。"
        fi
    fi

    switch_line "$group" "$target"
}

group_expected_nft_rules_after_switch() {
    local group="$1" target="$2" saved_forward id
    for id in $(list_group_ingress_profiles "$group"); do
        [[ "$id" == "$target" ]] || continue
        load_profile "$id" >/dev/null 2>&1 || continue
        saved_forward="${FORWARD_ENABLED:-true}"
        FORWARD_ENABLED="true"
        profile_expected_nft_rules
        FORWARD_ENABLED="$saved_forward"
    done | sort -u || true
    return 0
}

switch_dry_run() {
    require_root "$@"
    local group="${1:-}" target="${2:-}" forwarding_profiles to_disable target_status target_summary enabled_state health_note
    local id before_summary after_summary nft_text current_rules expected_rules primary_count backup_count forwarding_count
    local risk_count=0 target_port="" expected_target_rules conflict_profiles="" conflict_id
    if [[ -z "$group" || -z "$target" ]]; then
        if [[ "$(profile_group_count)" -eq 0 ]]; then
            print_no_group_message
            return 0
        fi
    fi
    validate_switch_dry_run_target "$group" "$target"

    forwarding_profiles="$(list_group_forwarding_profiles "$group")"
    to_disable="$(printf '%s\n' "$forwarding_profiles" | grep -vx "$target" || true)"
    primary_count="$(list_group_primary_profiles "$group" | awk 'NF{c++} END{print c+0}')"
    backup_count="$(list_group_backup_profiles "$group" | awk 'NF{c++} END{print c+0}')"
    forwarding_count="$(printf '%s\n' "$forwarding_profiles" | awk 'NF{c++} END{print c+0}')"
    nft_text="$(nft_table_text 2>/dev/null || true)"
    current_rules="$(group_actual_nft_rules "$group" "$nft_text")"
    expected_rules="$(group_expected_nft_rules_after_switch "$group" "$target")"

    printf 'Switch dry-run (no changes)\n'
    printf 'GROUP: %s\n' "$group"
    printf 'Current active profile: %s\n' "$(printf '%s\n' "$forwarding_profiles" | join_profile_list)"
    printf 'Target profile: %s\n' "$target"

    printf '\nCurrent nftables rules for this group:\n'
    if [[ -n "$nft_text" ]]; then
        print_rule_list "$current_rules"
    else
        printf '  - unavailable (no runtime table and no readable %s)\n' "$NFT_FILE"
    fi

    printf '\nExpected nftables rules after switch:\n'
    print_rule_list "$expected_rules"

    printf '\nProfiles that would be set FORWARD_ENABLED=false:\n'
    if [[ -n "$to_disable" ]]; then
        while IFS= read -r id; do
            [[ -n "$id" ]] && printf '  - %s\n' "$id"
        done <<<"$to_disable"
    else
        printf '  - none\n'
    fi

    printf '\nProfile that would be set FORWARD_ENABLED=true:\n'
    printf '  - %s\n' "$target"

    load_profile_or_die "$target"
    enabled_state="${ENABLED:-true}"
    target_status="${HEALTH_STATUS:-unknown}"
    health_note="${LAST_HEALTH_REASON:-未检查}"
    target_summary="$(profile_four_port_summary)"
    target_port="${LOCAL_PORT:-}"
    expected_target_rules="$(profile_expected_nft_rules)"
    printf '\nTarget health:\n'
    printf '  HEALTH_STATUS=%s\n' "$target_status"
    printf '  REASON=%s\n' "$health_note"
    printf '\nTarget four-port mapping:\n'
    printf '  %s\n' "$target_summary"

    if [[ -n "$target_port" ]]; then
        for conflict_id in $(profile_ids); do
            [[ "$conflict_id" != "$target" ]] || continue
            load_profile "$conflict_id" >/dev/null 2>&1 || continue
            [[ "${LINE_GROUP:-}" != "$group" ]] || continue
            [[ "${ROLE:-}" == "nat-ingress" && "${ENABLED:-true}" == "true" && "${FORWARD_ENABLED:-true}" == "true" ]] || continue
            [[ "${LOCAL_PORT:-}" == "$target_port" ]] || continue
            conflict_profiles="${conflict_profiles:+$conflict_profiles }$conflict_id"
        done
    fi

    printf '\nBefore / after port summary:\n'
    printf 'BEFORE:\n'
    for id in $(list_group_ingress_profiles "$group"); do
        load_profile "$id" || continue
        before_summary="$(profile_four_port_summary)"
        printf '  %s forward=%s ports=%s\n' "$id" "${FORWARD_ENABLED:-true}" "$before_summary"
    done
    printf 'AFTER:\n'
    for id in $(list_group_ingress_profiles "$group"); do
        load_profile "$id" || continue
        after_summary="$(profile_four_port_summary)"
        if [[ "$id" == "$target" ]]; then
            printf '  %s forward=true ports=%s\n' "$id" "$after_summary"
        else
            printf '  %s forward=false ports=%s\n' "$id" "$after_summary"
        fi
    done

    printf '\nRisk hints:\n'
    if [[ "$target_status" == "down" ]]; then
        printf '  - target down\n'
        risk_count=$((risk_count + 1))
    fi
    if [[ "$backup_count" -eq 0 ]]; then
        printf '  - no backup\n'
        risk_count=$((risk_count + 1))
    fi
    if [[ "$forwarding_count" -gt 1 ]]; then
        printf '  - multiple forwarding\n'
        risk_count=$((risk_count + 1))
    fi
    if [[ "$primary_count" -eq 0 ]]; then
        printf '  - no primary\n'
        risk_count=$((risk_count + 1))
    fi
    if [[ -n "$conflict_profiles" ]]; then
        printf '  - local port conflict: %s also uses LOCAL_PORT=%s\n' "$conflict_profiles" "$target_port"
        risk_count=$((risk_count + 1))
    fi
    if [[ -z "$expected_target_rules" ]]; then
        printf '  - target missing nft mapping\n'
        risk_count=$((risk_count + 1))
    fi
    [[ "$risk_count" -gt 0 ]] || printf '  - none\n'

    if [[ "$enabled_state" != "true" ]]; then
        printf '[WARN] 目标线路为冷备（ENABLED=false），正式 switch-line 前请先 enable-profile。\n'
    fi
    printf '\n预演说明：本命令不修改配置、不重启服务、不应用 nftables。\n'
    printf '预演说明：不会写入 Profile 文件、不会执行 apply-nft-all、不会更新 LAST_SWITCH_AT / SWITCH_NOTE。\n'
}

show_group() {
    require_root "$@"
    local group="${1:-}" id forwarding primary backups enabled_label forward_label cnix listener remote_port found=0
    local hot_count=0 cold_count=0 history_line recommended_target="" ready_state nft_text current_rules expected_rules
    if [[ -z "$group" ]]; then
        print_no_group_message
        return 0
    fi
    if ! group_exists "$group"; then
        printf '[ERROR] 线路组 %s 不存在。\n' "$group"
        printf '已有 group：%s\n' "$(list_existing_groups_for_message)"
        if [[ "$(profile_group_count)" -eq 0 ]]; then
            print_no_group_message
        fi
        return 1
    fi
    forwarding="$(list_group_forwarding_profiles "$group" | join_profile_list)"
    primary="$(list_group_primary_profiles "$group" | join_profile_list)"
    backups="$(list_group_backup_profiles "$group" | join_profile_list)"
    ready_state="$(group_ready_state "$group")"
    recommended_target="$(first_healthy_backup_in_group "$group" || true)"
    [[ -n "$recommended_target" ]] || recommended_target="$(first_available_backup_in_group "$group" || true)"

    printf '线路组：%s\n' "$group"
    printf '线路组状态：%s\n' "$(group_ready_state_label_zh "$ready_state")"
    printf '当前转发线路：%s\n' "$forwarding"
    printf '主线路：%s\n' "$primary"
    printf '备线路：%s\n' "$backups"
    printf '推荐备线路：%s\n' "${recommended_target:--}"
    for id in $(list_group_backup_profiles "$group"); do
        load_profile "$id" >/dev/null 2>&1 || continue
        if [[ "${ENABLED:-true}" == "true" && "${FORWARD_ENABLED:-true}" == "false" ]]; then
            hot_count=$((hot_count + 1))
        elif [[ "${ENABLED:-true}" == "false" ]]; then
            cold_count=$((cold_count + 1))
        fi
    done
    printf '热备数量：%s\n' "$hot_count"
    printf '冷备数量：%s\n' "$cold_count"
    printf '\n线路ID | 主备角色 | 优先级 | 启用 | 转发 | 健康 | 客户端端口 | CNIX入口 | Listener | 业务端口\n'
    printf '%s\n' '--- | --- | --- | --- | --- | --- | --- | --- | --- | ---'
    for id in $(sorted_profile_ids); do
        load_profile "$id" || { printf '%s | - | - | off | off | down | - | - | - | -\n' "$id"; continue; }
        [[ "${LINE_GROUP:-}" == "$group" ]] || continue
        found=1
        enabled_label="$(enabled_display "${ENABLED:-true}")"
        forward_label="$(forward_display "${ROLE:-}" "${ENABLED:-true}" "${FORWARD_ENABLED:-true}")"
        if [[ -n "${CNIX_ENTRY_HOST:-}" && -n "${CNIX_ENTRY_PORT:-}" ]]; then
            cnix="${CNIX_ENTRY_HOST}:${CNIX_ENTRY_PORT}"
        else
            cnix="-"
        fi
        listener="${ET_LISTENER_PORT:-${LISTENER_PORT:-}}"
        remote_port="${REMOTE_PORT:-${SERVICE_PORT:-}}"
        printf '%s | %s | %s | %s | %s | %s | %s | %s | %s | %s\n' \
            "$id" "${LINE_ROLE:-standalone}" "${LINE_PRIORITY:-100}" "$enabled_label" "$forward_label" \
            "${HEALTH_STATUS:-unknown}" "${LOCAL_PORT:-}" "$cnix" "${listener:-}" "${remote_port:-}"
    done
    [[ "$found" -eq 1 ]] || die_user "线路组 ${group} 不存在或没有 Profile。"

    printf '\n当前线路组 nftables 规则：\n'
    nft_text="$(nft_table_text 2>/dev/null || true)"
    if [[ -n "$nft_text" ]]; then
        current_rules="$(group_actual_nft_rules "$group" "$nft_text")"
        print_rule_list "$current_rules"
    else
        printf '  - 不可用（无运行时表且无法读取 %s）\n' "$NFT_FILE"
    fi

    printf '\n期望的 nftables 规则（按当前 Profile）：\n'
    expected_rules="$(group_expected_nft_rules "$group")"
    print_rule_list "$expected_rules"

    printf '\n最近切换记录：\n'
    history_line="$(last_switch_history_for_group "$group" || true)"
    if [[ -n "$history_line" ]]; then
        printf '  %s\n' "$history_line"
    else
        printf '  无\n'
    fi

    printf '\n线路组建议：\n'
    print_group_advice "$group"
    printf '\n推荐操作：\n'
    printf '  健康：bash install.sh health-report --group %s\n' "$group"
    printf '  检查：bash install.sh primary-backup-check %s\n' "$group"
    if [[ -n "$recommended_target" ]]; then
        printf '  预演：bash install.sh switch-dry-run %s %s\n' "$group" "$recommended_target"
        printf '  切换：bash install.sh switch-line %s %s\n' "$group" "$recommended_target"
    else
        printf '  切换：请先添加备线路后再 switch-dry-run / switch-line\n'
    fi
    printf '  回滚：bash install.sh switch-rollback-last\n'
}

history_sanitize_field() {
    local value="${1:-}"
    value="${value//$'\t'/ }"
    value="${value//$'\r'/ }"
    value="${value//$'\n'/ }"
    printf '%s\n' "$value"
}

ensure_state_file() {
    local path="$1" header="$2"
    ensure_profile_dirs
    install -d -m 700 "$STATE_DIR"
    if [[ ! -e "$path" ]]; then
        printf '%s\n' "$header" >"$path"
    fi
    chmod 600 "$path"
}

ensure_health_history_file() {
    ensure_state_file "$HEALTH_HISTORY_FILE" "timestamp	profile_id	line_group	health_status	service_status	et_ip_status	nft_status	reason"
}

append_health_history() {
    local profile_id="$1" health_status="$2" reason="$3" stamp group service service_status nft_status et_ip_status et_rc
    ensure_health_history_file || return 1
    stamp="$(utc_now)"
    if load_profile "$profile_id" >/dev/null 2>&1; then
        group="${LINE_GROUP:-}"
        service="$(profile_service_name "$profile_id")"
        service_status="$(profile_service_status "$service")"
        nft_status="$(nft_profile_rule_label "$profile_id")"
        set +e
        check_et_ip_present >/dev/null 2>&1
        et_rc=$?
        set -e
        case "$et_rc" in
            0) et_ip_status="present" ;;
            2) et_ip_status="unknown" ;;
            *) et_ip_status="missing" ;;
        esac
    else
        group=""
        service_status="unknown"
        et_ip_status="unknown"
        nft_status="unknown"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$(history_sanitize_field "$stamp")" \
        "$(history_sanitize_field "$profile_id")" \
        "$(history_sanitize_field "$group")" \
        "$(history_sanitize_field "$health_status")" \
        "$(history_sanitize_field "$service_status")" \
        "$(history_sanitize_field "$et_ip_status")" \
        "$(history_sanitize_field "$nft_status")" \
        "$(history_sanitize_field "$reason")" >>"$HEALTH_HISTORY_FILE"
    chmod 600 "$HEALTH_HISTORY_FILE"
}

health_history() {
    require_root "$@"
    local profile_filter="" group_filter="" limit=50 history_file row_count
    while (($#)); do
        case "$1" in
            --group)
                shift
                [[ -n "${1:-}" ]] || die_user "用法：health-history [PROFILE_ID|--group GROUP] [--limit N]"
                group_filter="$1"
                ;;
            --limit)
                shift
                [[ -n "${1:-}" ]] || die_user "用法：health-history [PROFILE_ID|--group GROUP] [--limit N]"
                limit="$1"
                ;;
            --limit=*)
                limit="${1#--limit=}"
                ;;
            --*)
                die_user "未知 health-history 参数：$1"
                ;;
            *)
                [[ -z "$profile_filter" ]] || die_user "用法：health-history [PROFILE_ID|--group GROUP] [--limit N]"
                profile_filter="$1"
                ;;
        esac
        shift || true
    done
    [[ "$limit" =~ ^[0-9]+$ && "$limit" -gt 0 ]] || die_user "--limit 必须是正整数。"
    ensure_health_history_file
    history_file="$HEALTH_HISTORY_FILE"
    row_count="$(awk -F '\t' -v p="$profile_filter" -v g="$group_filter" 'NR>1 && (p=="" || $2==p) && (g=="" || $3==g) {c++} END{print c+0}' "$history_file")"
    if [[ "$row_count" -eq 0 ]]; then
        printf 'No health history found.\n'
        printf 'TIME\tPROFILE\tGROUP\tHEALTH\tSERVICE\tET_IP\tNFT\tREASON\n'
        return 0
    fi
    printf 'Recent health history (last %s):\n' "$limit"
    awk -F '\t' -v p="$profile_filter" -v g="$group_filter" -v limit="$limit" '
        NR>1 && (p=="" || $2==p) && (g=="" || $3==g) {
            rows[++n]=sprintf("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s", $1, $2, $3, $4, $5, $6, $7, $8)
        }
        END {
            print "TIME\tPROFILE\tGROUP\tHEALTH\tSERVICE\tET_IP\tNFT\tREASON"
            start=n-limit+1
            if (start < 1) start=1
            for (i=start; i<=n; i++) print rows[i]
        }
    ' "$history_file"
}

clear_health_history() {
    require_root "$@"
    if read_exact_confirmation "确认清空健康历史请输入 CLEAR：" "CLEAR"; then
        ensure_health_history_file
        printf 'timestamp\tprofile_id\tline_group\thealth_status\tservice_status\tet_ip_status\tnft_status\treason\n' >"$HEALTH_HISTORY_FILE"
        chmod 600 "$HEALTH_HISTORY_FILE"
        log_ok "已清空健康历史：${HEALTH_HISTORY_FILE}"
    else
        die_user "已取消清空健康历史。"
    fi
}

health_all() {
    require_root "$@"
    local id output rc status reason total=0 healthy=0 warning=0 down=0 unknown=0
    for id in $(profile_ids); do
        load_profile "$id" || { printf '[WARN] 无法读取线路：%s\n' "$id"; continue; }
        [[ "${ENABLED:-true}" == "true" && "${HEALTH_CHECK_ENABLED:-true}" == "true" ]] || continue
        printf '\n===== 线路 %s =====\n' "$id"
        set +e
        output="$(run_line_health_check "$id" true 2>&1)"
        rc=$?
        set -e
        printf '%s\n' "$output"
        total=$((total + 1))
        status="$(grep -E '^HEALTH_STATUS=' <<<"$output" | tail -n 1 | cut -d= -f2- || true)"
        status="${status:-unknown}"
        reason="$(grep -E '^LAST_HEALTH_REASON=' <<<"$output" | tail -n 1 | cut -d= -f2- || true)"
        reason="${reason:-未检查}"
        if ! append_health_history "$id" "$status" "$reason"; then
            printf '[WARN] 写入 health-history 失败，已继续。\n'
        fi
        if [[ "$rc" -ne 0 ]]; then
            unknown=$((unknown + 1))
            printf '[WARN] health %s 失败（退出码 %s），已继续检查后续 Profile。\n' "$id" "$rc"
        else
            case "$status" in
                healthy) healthy=$((healthy + 1)) ;;
                warning) warning=$((warning + 1)) ;;
                down) down=$((down + 1)) ;;
                *) unknown=$((unknown + 1)) ;;
            esac
        fi
    done
    printf '\n汇总：total=%s healthy=%s warning=%s down=%s unknown=%s\n' "$total" "$healthy" "$warning" "$down" "$unknown"
}

mask_notify_token() {
    local token="${1:-}" len prefix suffix
    [[ -n "$token" ]] || { printf '(empty)\n'; return 0; }
    len="${#token}"
    if [[ "$len" -le 10 ]]; then
        printf '***\n'
    else
        prefix="${token:0:6}"
        suffix="${token: -4}"
        printf '%s***%s\n' "$prefix" "$suffix"
    fi
}

set_notify_defaults() {
    NOTIFY_ENABLED="${NOTIFY_ENABLED:-false}"
    NOTIFY_PROVIDER="${NOTIFY_PROVIDER:-telegram}"
    TG_BOT_TOKEN="${TG_BOT_TOKEN:-}"
    TG_CHAT_ID="${TG_CHAT_ID:-}"
    NOTIFY_ON_HEALTH_CHANGE="${NOTIFY_ON_HEALTH_CHANGE:-true}"
    NOTIFY_ON_DOWN="${NOTIFY_ON_DOWN:-true}"
    NOTIFY_ON_RECOVERY="${NOTIFY_ON_RECOVERY:-true}"
    NOTIFY_ON_SWITCH="${NOTIFY_ON_SWITCH:-true}"
    NOTIFY_ON_NFT_MISMATCH="${NOTIFY_ON_NFT_MISMATCH:-true}"
    NOTIFY_MIN_INTERVAL_SECONDS="${NOTIFY_MIN_INTERVAL_SECONDS:-300}"
}

load_notify_config() {
    set_notify_defaults
    if [[ -r "$NOTIFY_ENV_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$NOTIFY_ENV_FILE"
        set_notify_defaults
    fi
}

save_notify_config() {
    local tmp
    ensure_profile_dirs
    install -d -m 700 "$CONFIG_DIR"
    tmp="$(make_tmp_file "ix-transit-fabric.notify")"
    {
        printf 'NOTIFY_ENABLED=%s\n' "${NOTIFY_ENABLED:-false}"
        printf 'NOTIFY_PROVIDER=%s\n' "${NOTIFY_PROVIDER:-telegram}"
        printf 'TG_BOT_TOKEN=%s\n' "$(quote_env_value "${TG_BOT_TOKEN:-}")"
        printf 'TG_CHAT_ID=%s\n' "$(quote_env_value "${TG_CHAT_ID:-}")"
        printf 'NOTIFY_ON_HEALTH_CHANGE=%s\n' "${NOTIFY_ON_HEALTH_CHANGE:-true}"
        printf 'NOTIFY_ON_DOWN=%s\n' "${NOTIFY_ON_DOWN:-true}"
        printf 'NOTIFY_ON_RECOVERY=%s\n' "${NOTIFY_ON_RECOVERY:-true}"
        printf 'NOTIFY_ON_SWITCH=%s\n' "${NOTIFY_ON_SWITCH:-true}"
        printf 'NOTIFY_ON_NFT_MISMATCH=%s\n' "${NOTIFY_ON_NFT_MISMATCH:-true}"
        printf 'NOTIFY_MIN_INTERVAL_SECONDS=%s\n' "${NOTIFY_MIN_INTERVAL_SECONDS:-300}"
    } >"$tmp"
    install -m 0600 "$tmp" "$NOTIFY_ENV_FILE"
    rm -f -- "$tmp"
}

ensure_notify_config_file() {
    load_notify_config
    [[ -e "$NOTIFY_ENV_FILE" ]] || save_notify_config
    chmod 600 "$NOTIFY_ENV_FILE"
}

notify_config() {
    require_root "$@"
    local answer
    ensure_notify_config_file
    load_notify_config
    if is_interactive_input; then
        printf 'Telegram bot token（留空保持不变）：' >&2
        IFS= read -r answer || answer=""
        [[ -n "$answer" ]] && TG_BOT_TOKEN="$answer"
        printf 'Telegram chat id（留空保持不变）：' >&2
        IFS= read -r answer || answer=""
        [[ -n "$answer" ]] && TG_CHAT_ID="$answer"
        printf '最小通知间隔秒数（当前 %s，留空保持不变）：' "${NOTIFY_MIN_INTERVAL_SECONDS:-300}" >&2
        IFS= read -r answer || answer=""
        [[ -n "$answer" ]] && NOTIFY_MIN_INTERVAL_SECONDS="$answer"
        save_notify_config
        log_ok "已保存通知配置：${NOTIFY_ENV_FILE}"
    else
        printf 'Notification config: %s\n' "$NOTIFY_ENV_FILE"
        printf 'Use an interactive shell to edit it safely, or edit the file directly with mode 600.\n'
    fi
    notify_status
}

notify_enable() {
    require_root "$@"
    ensure_notify_config_file
    load_notify_config
    NOTIFY_ENABLED="true"
    save_notify_config
    log_ok "已启用通知。"
}

notify_disable() {
    require_root "$@"
    ensure_notify_config_file
    load_notify_config
    NOTIFY_ENABLED="false"
    save_notify_config
    log_ok "已禁用通知。"
}

notify_status() {
    require_root "$@"
    ensure_notify_config_file
    load_notify_config
    printf 'NOTIFY_ENABLED=%s\n' "${NOTIFY_ENABLED:-false}"
    printf 'NOTIFY_PROVIDER=%s\n' "${NOTIFY_PROVIDER:-telegram}"
    printf 'TG_BOT_TOKEN=%s\n' "$(mask_notify_token "${TG_BOT_TOKEN:-}")"
    printf 'TG_CHAT_ID=%s\n' "$([[ -n "${TG_CHAT_ID:-}" ]] && printf 'configured' || printf '(empty)')"
    printf 'NOTIFY_ON_HEALTH_CHANGE=%s\n' "${NOTIFY_ON_HEALTH_CHANGE:-true}"
    printf 'NOTIFY_ON_DOWN=%s\n' "${NOTIFY_ON_DOWN:-true}"
    printf 'NOTIFY_ON_RECOVERY=%s\n' "${NOTIFY_ON_RECOVERY:-true}"
    printf 'NOTIFY_ON_SWITCH=%s\n' "${NOTIFY_ON_SWITCH:-true}"
    printf 'NOTIFY_ON_NFT_MISMATCH=%s\n' "${NOTIFY_ON_NFT_MISMATCH:-true}"
    printf 'NOTIFY_MIN_INTERVAL_SECONDS=%s\n' "${NOTIFY_MIN_INTERVAL_SECONDS:-300}"
}

send_notification() {
    local message="$1" force_send="${2:-false}" output token rc
    load_notify_config
    [[ "$force_send" == "true" || "${NOTIFY_ENABLED:-false}" == "true" ]] || return 0
    [[ "${NOTIFY_PROVIDER:-telegram}" == "telegram" ]] || { log_warn "通知 provider 暂不支持：${NOTIFY_PROVIDER:-}"; return 0; }
    [[ -n "${TG_BOT_TOKEN:-}" && -n "${TG_CHAT_ID:-}" ]] || { log_warn "Telegram 通知未配置完整，跳过发送。"; return 0; }
    command_exists curl || { log_warn "curl 不存在，无法发送 Telegram 通知。"; return 0; }
    token="${TG_BOT_TOKEN:-}"
    set +e
    output="$(curl -fsS -X POST "https://api.telegram.org/bot${token}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT_ID}" \
        --data-urlencode "text=${message}" 2>&1 >/dev/null)"
    rc=$?
    set -e
    if [[ "$rc" -ne 0 ]]; then
        output="${output//$token/$(mask_notify_token "$token")}"
        log_warn "通知发送失败（curl exit=${rc}）：${output:-no detail}"
    fi
}

notify_test() {
    require_root "$@"
    ensure_notify_config_file
    send_notification "ix-transit-fabric health alert
hostname: $(hostname 2>/dev/null || printf unknown)
time: $(utc_now)
summary: test notification
suggested command: bash install.sh health-report" true
    log_ok "notify-test 已执行。"
}

ensure_notify_state_files() {
    ensure_state_file "$LAST_NOTIFY_FILE" "profile_id	last_notify_at"
    ensure_state_file "$LAST_HEALTH_STATUS_FILE" "profile_id	health_status	updated_at"
}

last_state_value() {
    local file="$1" key="$2" field="${3:-2}"
    [[ -r "$file" ]] || return 1
    awk -F '\t' -v k="$key" -v f="$field" 'NR>1 && $1==k {v=$f} END{if (v!="") print v}' "$file"
}

upsert_state_line() {
    local file="$1" key="$2" value1="$3" value2="${4:-}" tmp
    ensure_state_file "$file" "profile_id	value	updated_at"
    tmp="$(make_tmp_file "ix-transit-fabric.state")"
    awk -F '\t' -v k="$key" 'BEGIN{OFS="\t"} NR==1{print; next} $1!=k{print}' "$file" >"$tmp"
    if [[ -n "$value2" ]]; then
        printf '%s\t%s\t%s\n' "$(history_sanitize_field "$key")" "$(history_sanitize_field "$value1")" "$(history_sanitize_field "$value2")" >>"$tmp"
    else
        printf '%s\t%s\n' "$(history_sanitize_field "$key")" "$(history_sanitize_field "$value1")" >>"$tmp"
    fi
    install -m 0600 "$tmp" "$file"
    rm -f -- "$tmp"
}

should_notify_health_change() {
    local profile_id="$1" new_status="$2" force_notify="${3:-false}" old_status last_notify now min_interval elapsed
    load_notify_config
    [[ "${NOTIFY_ENABLED:-false}" == "true" ]] || return 1
    ensure_notify_state_files
    old_status="$(last_state_value "$LAST_HEALTH_STATUS_FILE" "$profile_id" 2 || true)"
    last_notify="$(last_state_value "$LAST_NOTIFY_FILE" "$profile_id" 2 || true)"
    now="$(date +%s)"
    min_interval="${NOTIFY_MIN_INTERVAL_SECONDS:-300}"
    if [[ -n "$last_notify" && "$last_notify" =~ ^[0-9]+$ && "$force_notify" != "true" ]]; then
        elapsed=$((now - last_notify))
        [[ "$elapsed" -ge "$min_interval" ]] || return 1
    fi
    [[ "$force_notify" == "true" ]] && return 0
    if [[ -z "$old_status" ]]; then
        [[ "$new_status" == "down" && "${NOTIFY_ON_DOWN:-true}" == "true" ]] && return 0
        [[ "$new_status" == "warning" && "${NOTIFY_ON_HEALTH_CHANGE:-true}" == "true" ]] && return 0
        return 1
    fi
    [[ "$old_status" == "$new_status" ]] && return 1
    if [[ "$new_status" == "healthy" && "${NOTIFY_ON_RECOVERY:-true}" == "true" ]]; then
        return 0
    fi
    if [[ "$new_status" == "down" && "${NOTIFY_ON_DOWN:-true}" == "true" ]]; then
        return 0
    fi
    [[ "${NOTIFY_ON_HEALTH_CHANGE:-true}" == "true" ]]
}

record_last_health_status() {
    local profile_id="$1" status="$2"
    ensure_notify_state_files
    upsert_state_line "$LAST_HEALTH_STATUS_FILE" "$profile_id" "$status" "$(utc_now)"
}

record_last_notify() {
    local profile_id="$1"
    ensure_notify_state_files
    upsert_state_line "$LAST_NOTIFY_FILE" "$profile_id" "$(date +%s)"
}

notification_suggestion_for_profile() {
    local profile_id="$1" group backup_id
    load_profile "$profile_id" >/dev/null 2>&1 || return 0
    group="${LINE_GROUP:-}"
    [[ -n "$group" ]] || return 0
    if [[ "${LINE_ROLE:-standalone}" == "primary" && "${HEALTH_STATUS:-unknown}" == "down" ]]; then
        backup_id="$(first_healthy_backup_in_group "$group" || true)"
        if [[ -n "$backup_id" ]]; then
            printf 'suggested command:\n'
            printf 'bash install.sh switch-dry-run %s %s\n' "$group" "$backup_id"
            printf 'bash install.sh switch-line %s %s\n' "$group" "$backup_id"
        fi
    fi
}

send_monitor_notifications() {
    local force_notify="${1:-false}" id status reason group message suggestion
    load_notify_config
    [[ "${NOTIFY_ENABLED:-false}" == "true" ]] || return 0
    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        status="${HEALTH_STATUS:-unknown}"
        reason="${LAST_HEALTH_REASON:-未检查}"
        group="${LINE_GROUP:-}"
        if should_notify_health_change "$id" "$status" "$force_notify"; then
            suggestion="$(notification_suggestion_for_profile "$id")"
            message="ix-transit-fabric health alert
hostname: $(hostname 2>/dev/null || printf unknown)
time: $(utc_now)
summary: profile health ${status}
affected group: ${group:-standalone}
affected profile: ${id}
health status: ${status}
reason: ${reason}
${suggestion:-suggested command: bash install.sh health-report}"
            send_notification "$message"
            record_last_notify "$id"
        fi
        record_last_health_status "$id" "$status"
    done
}

send_switch_notification() {
    local group="$1" from_profile="$2" to_profile="$3" target_status="$4"
    load_notify_config
    [[ "${NOTIFY_ENABLED:-false}" == "true" && "${NOTIFY_ON_SWITCH:-true}" == "true" ]] || return 0
    send_notification "ix-transit-fabric health alert
hostname: $(hostname 2>/dev/null || printf unknown)
time: $(utc_now)
summary: manual switch completed
affected group: ${group}
affected profile: ${to_profile}
health status: ${target_status}
from: ${from_profile}
suggested command: bash install.sh verify-nft-profiles"
}

monitor_interval_minutes() {
    if [[ -r "$MONITOR_INTERVAL_FILE" ]]; then
        awk 'NR==1 && $1 ~ /^[0-9]+$/ {print $1; found=1} END{if (!found) print 5}' "$MONITOR_INTERVAL_FILE"
    else
        printf '5\n'
    fi
}

render_monitor_systemd_files() {
    local interval script_path tmp_service tmp_timer
    ensure_profile_dirs
    install -d -m 700 "$STATE_DIR"
    interval="$(monitor_interval_minutes)"
    script_path="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
    tmp_service="$(make_tmp_file "ix-transit-monitor.service")"
    tmp_timer="$(make_tmp_file "ix-transit-monitor.timer")"
    {
        printf '[Unit]\n'
        printf 'Description=ix-transit-fabric monitor run once\n\n'
        printf '[Service]\n'
        printf 'Type=oneshot\n'
        printf 'ExecStart=/bin/bash %s monitor-run-once\n' "$script_path"
    } >"$tmp_service"
    {
        printf '[Unit]\n'
        printf 'Description=ix-transit-fabric monitor timer\n\n'
        printf '[Timer]\n'
        printf 'OnBootSec=2min\n'
        printf 'OnUnitActiveSec=%smin\n' "$interval"
        printf 'AccuracySec=30s\n'
        printf 'Persistent=true\n\n'
        printf '[Install]\n'
        printf 'WantedBy=timers.target\n'
    } >"$tmp_timer"
    install -m 0644 "$tmp_service" "$MONITOR_SERVICE_FILE"
    install -m 0644 "$tmp_timer" "$MONITOR_TIMER_FILE"
    rm -f -- "$tmp_service" "$tmp_timer"
}

monitor_set_interval() {
    require_root "$@"
    local minutes="${1:-}"
    [[ "$minutes" =~ ^[0-9]+$ && "$minutes" -gt 0 ]] || die_user "用法：monitor-set-interval MINUTES"
    ensure_profile_dirs
    install -d -m 700 "$STATE_DIR"
    printf '%s\n' "$minutes" >"$MONITOR_INTERVAL_FILE"
    chmod 600 "$MONITOR_INTERVAL_FILE"
    if command_exists systemctl; then
        render_monitor_systemd_files
        systemctl daemon-reload || true
        if systemctl is-enabled "$MONITOR_TIMER_NAME" >/dev/null 2>&1; then
            systemctl restart "$MONITOR_TIMER_NAME" || true
        fi
    fi
    log_ok "已设置监控间隔：${minutes} 分钟"
}

monitor_config() {
    require_root "$@"
    printf 'monitor interval minutes: %s\n' "$(monitor_interval_minutes)"
    printf 'service file: %s\n' "$MONITOR_SERVICE_FILE"
    printf 'timer file: %s\n' "$MONITOR_TIMER_FILE"
    printf 'default state: disabled until monitor-enable is run\n'
}

monitor_enable() {
    require_root "$@"
    ensure_systemctl
    render_monitor_systemd_files
    systemctl daemon-reload
    systemctl enable --now "$MONITOR_TIMER_NAME" >/dev/null
    log_ok "已启用定时健康检查：${MONITOR_TIMER_NAME}"
}

monitor_disable() {
    require_root "$@"
    ensure_systemctl
    systemctl disable --now "$MONITOR_TIMER_NAME" >/dev/null 2>&1 || true
    log_ok "已禁用定时健康检查：${MONITOR_TIMER_NAME}"
}

monitor_status() {
    require_root "$@"
    local enabled active next_run last_run last_result summary timer_text active_text notify_text health_count switch_count
    if command_exists systemctl; then
        enabled="$(systemctl is-enabled "$MONITOR_TIMER_NAME" 2>/dev/null || printf disabled)"
        active="$(systemctl is-active "$MONITOR_TIMER_NAME" 2>/dev/null || printf inactive)"
        next_run="$(systemctl list-timers "$MONITOR_TIMER_NAME" --no-pager --no-legend 2>/dev/null | awk '{print $1" "$2" "$3" "$4; exit}')"
    else
        enabled="systemctl-unavailable"
        active="systemctl-unavailable"
        next_run="-"
    fi
    case "$enabled" in
        enabled) timer_text="已启用" ;;
        disabled) timer_text="未启用" ;;
        systemctl-unavailable) timer_text="未安装（systemctl 不可用）" ;;
        *) timer_text="未安装或未启用（${enabled}）" ;;
    esac
    case "$active" in
        active) active_text="运行中" ;;
        inactive) active_text="未运行" ;;
        systemctl-unavailable) active_text="未安装（systemctl 不可用）" ;;
        *) active_text="$active" ;;
    esac
    if [[ -r "$MONITOR_LAST_RUN_FILE" ]]; then
        last_run="$(awk -F '\t' 'NR==1{print $1}' "$MONITOR_LAST_RUN_FILE")"
        last_result="$(awk -F '\t' 'NR==1{print $2}' "$MONITOR_LAST_RUN_FILE")"
        summary="$(awk -F '\t' 'NR==1{print $3}' "$MONITOR_LAST_RUN_FILE")"
    else
        last_run="-"
        last_result="-"
        summary="-"
    fi
    load_notify_config
    notify_text="$([[ "${NOTIFY_ENABLED:-false}" == "true" ]] && printf enabled || printf disabled)"
    health_count=0
    switch_count=0
    [[ -r "$HEALTH_HISTORY_FILE" ]] && health_count="$(awk 'NR>1{c++} END{print c+0}' "$HEALTH_HISTORY_FILE")"
    [[ -r "$(switch_history_path)" ]] && switch_count="$(awk 'NR>1{c++} END{print c+0}' "$(switch_history_path)")"
    printf 'monitor timer：%s\n' "$timer_text"
    printf 'timer active：%s\n' "$active_text"
    printf 'next run：%s\n' "${next_run:-unknown}"
    printf 'last run：%s\n' "$last_run"
    printf 'last result：%s\n' "$last_result"
    printf 'latest health summary：%s\n' "$summary"
    printf 'notify：%s\n' "$notify_text"
    printf 'health history：%s 条\n' "$health_count"
    printf 'switch history：%s 条\n' "$switch_count"
}

monitor_logs() {
    require_root "$@"
    command_exists journalctl || die_user "journalctl 不可用。"
    journalctl -u "$MONITOR_SERVICE_NAME" -n 100 --no-pager 2>/dev/null | sed -E 's#bot[0-9]+:[A-Za-z0-9_-]+#bot***#g'
}

monitor_run_once() {
    require_root "$@"
    local force_notify="false" arg rc=0 verify_rc=0 total=0 healthy=0 warning=0 down=0 unknown=0 summary
    for arg in "$@"; do
        case "$arg" in
            --force-notify) force_notify="true" ;;
            --repair) die_user "本版本不实现 --repair；monitor-run-once 只读，不自动修复。" ;;
            *) die_user "未知 monitor-run-once 参数：$arg" ;;
        esac
    done
    printf 'ix-transit-fabric monitor-run-once\n'
    printf 'This monitor is read-only: no switch-line, no service restart, no apply-nft-all.\n'
    set +e
    health_all
    rc=$?
    set -e
    printf '\n===== health-report =====\n'
    health_report || true
    printf '\n===== validate-primary-backup =====\n'
    local group
    while IFS= read -r group; do
        [[ -n "$group" ]] || continue
        validate_primary_backup "$group" || true
    done < <(profile_groups)
    printf '\n===== verify-nft-profiles =====\n'
    set +e
    verify_nft_profiles_core
    verify_rc=$?
    set -e
    for id in $(profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        total=$((total + 1))
        case "${HEALTH_STATUS:-unknown}" in
            healthy) healthy=$((healthy + 1)) ;;
            warning) warning=$((warning + 1)) ;;
            down) down=$((down + 1)) ;;
            *) unknown=$((unknown + 1)) ;;
        esac
    done
    summary="profiles=${total} healthy=${healthy} warning=${warning} down=${down} unknown=${unknown} nft_verify=${verify_rc}"
    ensure_profile_dirs
    install -d -m 700 "$STATE_DIR"
    printf '%s\t%s\t%s\n' "$(utc_now)" "$([[ "$rc" -eq 0 && "$verify_rc" -eq 0 ]] && printf success || printf warning)" "$summary" >"$MONITOR_LAST_RUN_FILE"
    chmod 600 "$MONITOR_LAST_RUN_FILE"
    load_notify_config
    if [[ "${NOTIFY_ENABLED:-false}" != "true" ]]; then
        printf '\nnotify disabled：本次只记录本地健康状态，不发送通知。\n'
    fi
    send_monitor_notifications "$force_notify" || true
    printf '\nMonitor summary: %s\n' "$summary"
    return 0
}

nft_text_has_dnat_rule() {
    local text="$1" proto="$2" local_port="$3" landing_ip="$4" remote_port="$5" daddr="${6:-}"
    [[ -n "$local_port" && -n "$landing_ip" && -n "$remote_port" ]] || return 1
    if [[ -n "$daddr" ]]; then
        grep -Eq "ip[[:space:]]+daddr[[:space:]]+${daddr}[[:space:]]+${proto}[[:space:]]+dport[[:space:]]+${local_port}([[:space:]]+counter([[:space:]]+packets[[:space:]]+[0-9]+[[:space:]]+bytes[[:space:]]+[0-9]+)?)?[[:space:]]+dnat[[:space:]]+to[[:space:]]+${landing_ip}:${remote_port}" <<<"$text"
    else
        grep -Eq "${proto}[[:space:]]+dport[[:space:]]+${local_port}([[:space:]]+counter([[:space:]]+packets[[:space:]]+[0-9]+[[:space:]]+bytes[[:space:]]+[0-9]+)?)?[[:space:]]+dnat[[:space:]]+to[[:space:]]+${landing_ip}:${remote_port}" <<<"$text"
    fi
}

nft_dnat_rules_from_text() {
    local text="$1"
    grep -E '^[[:space:]]*((ip[[:space:]]+daddr[[:space:]]+[0-9.]+[[:space:]]+)?(tcp|udp))[[:space:]]+dport[[:space:]]+[0-9]+([[:space:]]+counter([[:space:]]+packets[[:space:]]+[0-9]+[[:space:]]+bytes[[:space:]]+[0-9]+)?)?[[:space:]]+dnat[[:space:]]+to[[:space:]]+' <<<"$text" 2>/dev/null |
        sed -E 's/^[[:space:]]+//; s/[[:space:]]+counter( packets [0-9]+ bytes [0-9]+)?//g; s/[[:space:]]+/ /g' | sort -u
}

render_nft_all_file() {
    local output="$1" table_name="$2" id rule_id dport target daddr post ip port saved_local saved_transit saved_landing_host saved_landing_port saved_proto
    {
        printf 'table ip %s {\n' "$table_name"
        printf '    chain prerouting {\n'
        printf '        type nat hook prerouting priority dstnat; policy accept;\n\n'
        for id in $(profile_ids); do
            load_profile "$id" || continue
            profile_needs_nft_forward || continue
            if profile_supports_forward_rules; then
                saved_local="${LOCAL_PORT:-}"
                saved_transit="${TRANSIT_PORT:-}"
                saved_landing_host="${LANDING_HOST:-}"
                saved_landing_port="${LANDING_PORT:-}"
                saved_proto="${FORWARD_PROTO:-both}"
                for rule_id in $(profile_rule_ids "$id"); do
                    load_rule "$id" "$rule_id" || continue
                    [[ "${RULE_ENABLED:-true}" == "true" ]] || continue
                    dport="$(profile_rule_nft_dport)" || continue
                    if ! target="$(profile_rule_nft_target)"; then
                        printf '        # profile: %s rule: %s skipped: landing host resolve failed or target incomplete\n\n' "$id" "$rule_id"
                        continue
                    fi
                    daddr="$(profile_rule_nft_daddr_match || true)"
                    printf '        # profile: %s rule: %s note: %s\n' "$id" "$rule_id" "${RULE_NOTE:-}"
                    if [[ "${FORWARD_PROTO:-both}" == "tcp" || "${FORWARD_PROTO:-both}" == "both" ]]; then
                        printf '        %stcp dport %s counter dnat to %s\n' "$daddr" "$dport" "$target"
                    fi
                    if [[ "${FORWARD_PROTO:-both}" == "udp" || "${FORWARD_PROTO:-both}" == "both" ]]; then
                        printf '        %sudp dport %s counter dnat to %s\n' "$daddr" "$dport" "$target"
                    fi
                    printf '\n'
                done
                LOCAL_PORT="$saved_local"; TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
            else
                dport="$(profile_nft_dport)" || continue
                target="$(profile_nft_target)" || return 1
                daddr="$(profile_nft_daddr_match || true)"
                printf '        # profile: %s\n' "$id"
                if [[ "${FORWARD_PROTO:-both}" == "tcp" || "${FORWARD_PROTO:-both}" == "both" ]]; then
                    printf '        %stcp dport %s counter dnat to %s\n' "$daddr" "$dport" "$target"
                fi
                if [[ "${FORWARD_PROTO:-both}" == "udp" || "${FORWARD_PROTO:-both}" == "both" ]]; then
                    printf '        %sudp dport %s counter dnat to %s\n' "$daddr" "$dport" "$target"
                fi
                printf '\n'
            fi
        done
        printf '    }\n\n'
        printf '    chain postrouting {\n'
        printf '        type nat hook postrouting priority srcnat; policy accept;\n\n'
        for id in $(profile_ids); do
            load_profile "$id" || continue
            profile_needs_nft_forward || continue
            if profile_supports_forward_rules; then
                saved_local="${LOCAL_PORT:-}"
                saved_transit="${TRANSIT_PORT:-}"
                saved_landing_host="${LANDING_HOST:-}"
                saved_landing_port="${LANDING_PORT:-}"
                saved_proto="${FORWARD_PROTO:-both}"
                for rule_id in $(profile_rule_ids "$id"); do
                    load_rule "$id" "$rule_id" || continue
                    [[ "${RULE_ENABLED:-true}" == "true" ]] || continue
                    post="$(profile_rule_nft_postrouting_ip_port)" || continue
                    ip="${post%:*}"
                    port="${post##*:}"
                    printf '        # profile: %s rule: %s note: %s\n' "$id" "$rule_id" "${RULE_NOTE:-}"
                    if [[ "${FORWARD_PROTO:-both}" == "tcp" || "${FORWARD_PROTO:-both}" == "both" ]]; then
                        printf '        ip daddr %s tcp dport %s counter masquerade\n' "$ip" "$port"
                    fi
                    if [[ "${FORWARD_PROTO:-both}" == "udp" || "${FORWARD_PROTO:-both}" == "both" ]]; then
                        printf '        ip daddr %s udp dport %s counter masquerade\n' "$ip" "$port"
                    fi
                    printf '\n'
                done
                LOCAL_PORT="$saved_local"; TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
            else
                post="$(profile_nft_postrouting_ip_port)" || return 1
                ip="${post%:*}"
                port="${post##*:}"
                printf '        # profile: %s\n' "$id"
                if [[ "${FORWARD_PROTO:-both}" == "tcp" || "${FORWARD_PROTO:-both}" == "both" ]]; then
                    printf '        ip daddr %s tcp dport %s counter masquerade\n' "$ip" "$port"
                fi
                if [[ "${FORWARD_PROTO:-both}" == "udp" || "${FORWARD_PROTO:-both}" == "both" ]]; then
                    printf '        ip daddr %s udp dport %s counter masquerade\n' "$ip" "$port"
                fi
                printf '\n'
            fi
        done
        printf '    }\n'
        printf '}\n'
    } >"$output"
}

human_bytes() {
    local bytes="${1:-0}" unit="B" value
    if [[ "$bytes" -ge 1073741824 ]]; then
        unit="GiB"; value="$(awk -v b="$bytes" 'BEGIN{printf "%.2f", b/1073741824}')"
    elif [[ "$bytes" -ge 1048576 ]]; then
        unit="MiB"; value="$(awk -v b="$bytes" 'BEGIN{printf "%.2f", b/1048576}')"
    elif [[ "$bytes" -ge 1024 ]]; then
        unit="KiB"; value="$(awk -v b="$bytes" 'BEGIN{printf "%.2f", b/1024}')"
    else
        value="$bytes"
    fi
    printf '%s %s\n' "$value" "$unit"
}

profile_counter_from_text() {
    local text="$1" packets=0 bytes=0 found=0 line dport target daddr_prefix="" rule_id rp rb rs
    profile_needs_nft_forward || { printf -- "-\t-\tmissing\n"; return 0; }
    if profile_supports_forward_rules; then
        local saved_local="${LOCAL_PORT:-}" saved_transit="${TRANSIT_PORT:-}" saved_landing_host="${LANDING_HOST:-}" saved_landing_port="${LANDING_PORT:-}" saved_proto="${FORWARD_PROTO:-both}"
        packets=0
        bytes=0
        found=0
        for rule_id in $(profile_rule_ids "${PROFILE_ID:-default}"); do
            load_rule "${PROFILE_ID:-default}" "$rule_id" || continue
            [[ "${RULE_ENABLED:-true}" == "true" ]] || continue
            IFS=$'\t' read -r rp rb rs <<<"$(profile_rule_counter_from_text "$text")"
            if [[ "$rs" == "ok" && "$rp" =~ ^[0-9]+$ && "$rb" =~ ^[0-9]+$ ]]; then
                packets=$((packets + rp))
                bytes=$((bytes + rb))
                found=1
            fi
        done
        LOCAL_PORT="$saved_local"; TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
        if [[ "$found" -eq 1 ]]; then
            printf '%s\t%s\tok\n' "$packets" "$bytes"
        else
            printf -- "-\t-\tmissing\n"
        fi
        return 0
    fi
    dport="$(profile_nft_dport 2>/dev/null || true)"
    target="$(profile_nft_target 2>/dev/null || true)"
    [[ -n "$dport" && -n "$target" ]] || { printf -- "-\t-\tmissing\n"; return 0; }
    if [[ "${ROLE:-}" == "nat-transit" ]]; then
        daddr_prefix="ip[[:space:]]+daddr[[:space:]]+${NAT_ET_IP:-}[[:space:]]+"
    fi
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        if grep -Eq "${daddr_prefix}(tcp|udp)[[:space:]]+dport[[:space:]]+${dport}[[:space:]].*dnat[[:space:]]+to[[:space:]]+${target}" <<<"$line"; then
            if grep -Eq 'counter[[:space:]]+packets[[:space:]]+[0-9]+[[:space:]]+bytes[[:space:]]+[0-9]+' <<<"$line"; then
                packets=$((packets + $(sed -E 's/.*counter packets ([0-9]+) bytes ([0-9]+).*/\1/' <<<"$line")))
                bytes=$((bytes + $(sed -E 's/.*counter packets ([0-9]+) bytes ([0-9]+).*/\2/' <<<"$line")))
                found=1
            fi
        fi
    done <<<"$text"
    if [[ "$found" -eq 1 ]]; then
        printf '%s\t%s\tok\n' "$packets" "$bytes"
    else
        printf -- "-\t-\tmissing\n"
    fi
}

profile_rule_counter_from_text() {
    local text="$1" packets=0 bytes=0 found=0 line dport target daddr_prefix=""
    dport="$(profile_rule_nft_dport 2>/dev/null || true)"
    target="$(profile_rule_nft_target 2>/dev/null || true)"
    [[ -n "$dport" && -n "$target" ]] || { printf -- "-\t-\tmissing\n"; return 0; }
    if [[ "${ROLE:-}" == "nat-transit" ]]; then
        daddr_prefix="ip[[:space:]]+daddr[[:space:]]+${NAT_ET_IP:-}[[:space:]]+"
    fi
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        if grep -Eq "${daddr_prefix}(tcp|udp)[[:space:]]+dport[[:space:]]+${dport}[[:space:]].*dnat[[:space:]]+to[[:space:]]+${target}" <<<"$line"; then
            if grep -Eq 'counter[[:space:]]+packets[[:space:]]+[0-9]+[[:space:]]+bytes[[:space:]]+[0-9]+' <<<"$line"; then
                packets=$((packets + $(sed -E 's/.*counter packets ([0-9]+) bytes ([0-9]+).*/\1/' <<<"$line")))
                bytes=$((bytes + $(sed -E 's/.*counter packets ([0-9]+) bytes ([0-9]+).*/\2/' <<<"$line")))
                found=1
            fi
        fi
    done <<<"$text"
    if [[ "$found" -eq 1 ]]; then
        printf '%s\t%s\tok\n' "$packets" "$bytes"
    else
        printf -- "-\t-\tmissing\n"
    fi
}

traffic_report() {
    require_root "$@"
    local group_filter="" sample=0 id rule_id text after_text packets bytes state human port target status landing_target
    local before_packets before_bytes before_state after_packets after_bytes after_state delta_packets delta_bytes delta_total=0
    local saved_local saved_transit saved_landing_host saved_landing_port saved_proto
    while (($#)); do
        case "$1" in
            --group)
                shift
                group_filter="${1:-}"
                [[ -n "$group_filter" ]] || die_user "用法：traffic-report [--group GROUP] [--sample N]"
                ;;
            --sample)
                shift
                sample="$(parse_sample_seconds "${1:-}")" || die_user "--sample 必须是非负整数秒。"
                ;;
            *)
                die_user "用法：traffic-report [--group GROUP] [--sample N]"
                ;;
        esac
        shift || true
    done
    text="$(nft_table_text 2>/dev/null || true)"
    printf '线路ID\t规则ID\t备注\t状态\t公网入口端口\t虚拟网中转端口\t落地目标\t数据包\t字节\t可读流量\n'
    if [[ -z "$text" ]]; then
        printf '# 当前无法读取项目 nftables 表；请在应用转发规则后重试。\n'
    fi
    for id in $(sorted_profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || continue
        case "${ROLE:-}" in nat-ingress|nat-transit) ;; *) continue ;; esac
        [[ -z "$group_filter" || "${LINE_GROUP:-}" == "$group_filter" ]] || continue
        if profile_supports_forward_rules; then
            saved_local="${LOCAL_PORT:-}"; saved_transit="${TRANSIT_PORT:-}"; saved_landing_host="${LANDING_HOST:-}"; saved_landing_port="${LANDING_PORT:-}"; saved_proto="${FORWARD_PROTO:-both}"
            for rule_id in $(profile_rule_ids "$id"); do
                load_rule "$id" "$rule_id" || continue
                target="$(profile_rule_nft_target 2>/dev/null || true)"
                landing_target="${LANDING_HOST:-}:${LANDING_PORT:-}"
                [[ "$landing_target" == ":" ]] && landing_target="${target:-未知}"
                IFS=$'\t' read -r packets bytes state <<<"$(profile_rule_counter_from_text "$text")"
                if [[ "$state" == "ok" ]]; then
                    human="$(human_bytes "$bytes")"
                else
                    human="计数器缺失；请运行 bash install.sh apply-nft-all"
                fi
                printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                    "$id" "$rule_id" "$(rule_note_display)" "$(profile_rule_status_display)" "$(rule_client_port_display)" \
                    "${TRANSIT_PORT:-}" "$landing_target" "$packets" "$bytes" "$human"
            done
            LOCAL_PORT="$saved_local"; TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
        else
            port="$(profile_nft_dport 2>/dev/null || true)"
            target="$(profile_nft_target 2>/dev/null || true)"
            [[ -n "$target" ]] || target="未知"
            IFS=$'\t' read -r packets bytes state <<<"$(profile_counter_from_text "$text")"
            if [[ "$state" == "ok" ]]; then
                human="$(human_bytes "$bytes")"
            else
                human="计数器缺失；请运行 bash install.sh apply-nft-all"
            fi
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$id" "" "未备注" "$(enabled_label_zh "${FORWARD_ENABLED:-true}")" "${port:-}" "" "$target" "$packets" "$bytes" "$human"
        fi
    done
    printf '\n说明：nftables 计数器只统计本项目转发规则命中的流量，不等于云厂商账单流量。\n'
    printf 'NAT-IX 场景下，计数器增长表示 PREROUTING DNAT 正在接收流量。\n'
    if [[ "$sample" -gt 0 ]]; then
        printf '\n流量计数器采样：等待 %s 秒...\n' "$sample"
        sleep "$sample"
        after_text="$(nft_table_text 2>/dev/null || true)"
        printf '线路ID\t规则ID\t备注\t状态\t公网入口端口\t虚拟网中转端口\t落地目标\t增量数据包\t增量字节\t说明\n'
        for id in $(sorted_profile_ids); do
            load_profile "$id" >/dev/null 2>&1 || continue
            case "${ROLE:-}" in nat-ingress|nat-transit) ;; *) continue ;; esac
            [[ -z "$group_filter" || "${LINE_GROUP:-}" == "$group_filter" ]] || continue
            if profile_supports_forward_rules; then
                saved_local="${LOCAL_PORT:-}"; saved_transit="${TRANSIT_PORT:-}"; saved_landing_host="${LANDING_HOST:-}"; saved_landing_port="${LANDING_PORT:-}"; saved_proto="${FORWARD_PROTO:-both}"
                for rule_id in $(profile_rule_ids "$id"); do
                    load_rule "$id" "$rule_id" || continue
                    target="$(profile_rule_nft_target 2>/dev/null || true)"
                    landing_target="${LANDING_HOST:-}:${LANDING_PORT:-}"
                    [[ "$landing_target" == ":" ]] && landing_target="${target:-未知}"
                    IFS=$'\t' read -r before_packets before_bytes before_state <<<"$(profile_rule_counter_from_text "$text")"
                    IFS=$'\t' read -r after_packets after_bytes after_state <<<"$(profile_rule_counter_from_text "$after_text")"
                    if [[ "$before_packets" =~ ^[0-9]+$ && "$after_packets" =~ ^[0-9]+$ && "$before_bytes" =~ ^[0-9]+$ && "$after_bytes" =~ ^[0-9]+$ ]]; then
                        delta_packets=$((after_packets - before_packets))
                        delta_bytes=$((after_bytes - before_bytes))
                        delta_total=$((delta_total + delta_packets + delta_bytes))
                        if [[ "$delta_packets" -gt 0 || "$delta_bytes" -gt 0 ]]; then
                            human="采样期间有流量命中"
                        else
                            human="采样期间未观察到规则命中"
                        fi
                    else
                        delta_packets="-"
                        delta_bytes="-"
                        human="计数器不可用"
                    fi
                    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                        "$id" "$rule_id" "$(rule_note_display)" "$(profile_rule_status_display)" "$(rule_client_port_display)" \
                        "${TRANSIT_PORT:-}" "$landing_target" "$delta_packets" "$delta_bytes" "$human"
                done
                LOCAL_PORT="$saved_local"; TRANSIT_PORT="$saved_transit"; LANDING_HOST="$saved_landing_host"; LANDING_PORT="$saved_landing_port"; FORWARD_PROTO="$saved_proto"
            else
                port="$(profile_nft_dport 2>/dev/null || true)"
                target="$(profile_nft_target 2>/dev/null || true)"
                [[ -n "$target" ]] || target="未知"
                IFS=$'\t' read -r before_packets before_bytes before_state <<<"$(profile_counter_from_text "$text")"
                IFS=$'\t' read -r after_packets after_bytes after_state <<<"$(profile_counter_from_text "$after_text")"
                if [[ "$before_packets" =~ ^[0-9]+$ && "$after_packets" =~ ^[0-9]+$ && "$before_bytes" =~ ^[0-9]+$ && "$after_bytes" =~ ^[0-9]+$ ]]; then
                    delta_packets=$((after_packets - before_packets))
                    delta_bytes=$((after_bytes - before_bytes))
                    delta_total=$((delta_total + delta_packets + delta_bytes))
                    if [[ "$delta_packets" -gt 0 || "$delta_bytes" -gt 0 ]]; then
                        human="采样期间有流量命中"
                    else
                        human="采样期间未观察到规则命中"
                    fi
                else
                    delta_packets="-"
                    delta_bytes="-"
                    human="计数器不可用"
                fi
                printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                    "$id" "" "未备注" "$(enabled_label_zh "${FORWARD_ENABLED:-true}")" "${port:-}" "" "$target" "$delta_packets" "$delta_bytes" "$human"
            fi
        done
        if [[ "$delta_total" -gt 0 ]]; then
            printf '采样说明：测试期间有流量命中项目 nftables 规则。\n'
        else
            printf '采样说明：未观察到项目规则流量命中；请确认客户端正在连接正确的客户端入口端口。\n'
        fi
    fi
}

traffic_status() {
    require_root "$@"
    local profile_id="${1:-}"
    if [[ -n "$profile_id" ]]; then
        load_profile_or_die "$profile_id"
        printf 'Traffic status for %s\n' "$profile_id"
        if [[ -n "${LINE_GROUP:-}" ]]; then
            traffic_report --group "$LINE_GROUP" | awk -F '\t' -v p="$profile_id" 'NR==1 || $1==p || /^#|^Note:/ {print}'
        else
            traffic_report | awk -F '\t' -v p="$profile_id" 'NR==1 || $1==p || /^#|^Note:/ {print}'
        fi
    else
        traffic_report
    fi
}

traffic_reset() {
    require_root "$@"
    local profile_id="${1:-}"
    [[ -n "$profile_id" ]] || die_user "用法：traffic-reset PROFILE_ID"
    load_profile_or_die "$profile_id"
    printf '当前版本只支持 traffic-reset-all；单 Profile 精确重置将在未来版本设计。\n'
    printf '如需重置项目表所有 counter：bash install.sh traffic-reset-all\n'
    return 1
}

traffic_reset_all() {
    require_root "$@"
    apply_nft_all
    log_ok "已通过重新应用项目 nftables 表重置全部 Profile counter。"
}

nft_mismatch_status() {
    set +e
    verify_nft_profiles_core >/dev/null 2>&1
    local rc=$?
    set -e
    [[ "$rc" -eq 0 ]] && printf 'no' || printf 'yes'
}

traffic_counter_status() {
    local text
    text="$(nft_table_text 2>/dev/null || true)"
    grep -q 'counter' <<<"$text" && printf 'yes' || printf 'no'
}

notify_enabled_status() {
    load_notify_config
    printf '%s\n' "${NOTIFY_ENABLED:-false}"
}

monitor_timer_enabled_status() {
    if command_exists systemctl; then
        case "$(systemctl is-enabled "$MONITOR_TIMER_NAME" 2>/dev/null || printf not-found)" in
            enabled) printf '已启用\n' ;;
            disabled) printf '未启用\n' ;;
            *) printf '未安装\n' ;;
        esac
    else
        printf '未安装'
    fi
}

health_report() {
    require_root "$@"
    local group_filter="" id service active et_ip nft_label enabled_label forward_label group_display health role_label
    local total=0 forwarding_lines=0 healthy=0 warning=0 down=0 unknown=0 groups_total=0 groups_ready=0 groups_warning=0 groups_not_ready=0
    local group issue backup_id groups_with_issues=0 ready_state last_monitor="-" group_count
    if [[ "${1:-}" == "--group" ]]; then
        group_filter="${2:-}"
        [[ -n "$group_filter" ]] || die_user "用法：health-report --group GROUP"
    elif [[ -n "${1:-}" ]]; then
        group_filter="$1"
    fi

    printf '%-18s %-14s %-12s %-8s %-5s %-6s %-8s %-8s %-8s %-8s %s\n' \
        "线路ID" "分组" "类型" "主备" "优先" "启用" "业务转发" "服务" "转发规则" "健康" "说明"
    printf '%-18s %-14s %-12s %-8s %-5s %-6s %-8s %-8s %-8s %-8s %s\n' \
        "------------------" "--------------" "------------" "--------" "-----" "------" "--------" "--------" "--------" "--------" "------"
    for id in $(sorted_profile_ids); do
        if ! load_profile "$id"; then
            [[ -z "$group_filter" ]] || continue
            printf '%-18s %-14s %-12s %-8s %-5s %-6s %-8s %-8s %-8s %-8s %s\n' \
                "$id" "-" "-" "-" "-" "off" "off" "unknown" "unknown" "down" "无法读取线路配置"
            total=$((total + 1)); down=$((down + 1)); continue
        fi
        [[ -z "$group_filter" || "${LINE_GROUP:-}" == "$group_filter" ]] || continue
        service="$(profile_service_name "$id")"
        active="$(profile_service_status "$service")"
        nft_label="$(nft_profile_rule_label "$id")"
        enabled_label="$(enabled_display "${ENABLED:-true}")"
        forward_label="$(forward_display "${ROLE:-}" "${ENABLED:-true}" "${FORWARD_ENABLED:-true}")"
        group_display="${LINE_GROUP:-standalone}"
        health="${HEALTH_STATUS:-unknown}"
        case "${ROLE:-}" in
            nat-transit) role_label="落地" ;;
            nat-ingress) role_label="公网入口" ;;
            nat-transit) role_label="NAT IX 中转" ;;
            *) role_label="${ROLE:-unknown}" ;;
        esac
        case "${LINE_ROLE:-standalone}" in
            primary) line_label="主线" ;;
            backup) line_label="备用" ;;
            standalone) line_label="独立" ;;
            *) line_label="${LINE_ROLE:-standalone}" ;;
        esac
        [[ "$forward_label" == "active" ]] && forwarding_lines=$((forwarding_lines + 1))
        case "$health" in healthy) healthy=$((healthy + 1)) ;; warning) warning=$((warning + 1)) ;; down) down=$((down + 1)) ;; *) unknown=$((unknown + 1)) ;; esac
        total=$((total + 1))
        printf '%-18s %-14s %-12s %-8s %-5s %-6s %-8s %-8s %-8s %-8s %s\n' \
            "$id" "$group_display" "$role_label" "$line_label" "${LINE_PRIORITY:-100}" \
            "$enabled_label" "$forward_label" "${active:-unknown}" "$nft_label" "$health" "${LAST_HEALTH_REASON:-未检查}"
    done
    group_count="$(profile_group_count)"
    while IFS= read -r group; do
        [[ -n "$group" ]] || continue
        [[ -z "$group_filter" || "$group" == "$group_filter" ]] || continue
        groups_total=$((groups_total + 1))
        ready_state="$(group_ready_state "$group")"
        case "$ready_state" in ready) groups_ready=$((groups_ready + 1)) ;; warning) groups_warning=$((groups_warning + 1)) ;; *) groups_not_ready=$((groups_not_ready + 1)) ;; esac
    done < <(profile_groups || true)
    [[ -r "$MONITOR_LAST_RUN_FILE" ]] && last_monitor="$(awk -F '\t' 'NR==1{print $1}' "$MONITOR_LAST_RUN_FILE")"
    printf '\n汇总：\n'
    printf '线路总数：%s\n' "$total"
    printf '线路组总数：%s\n' "$groups_total"
    printf '当前转发线路：%s\n' "$forwarding_lines"
    printf '健康 / 警告 / 故障 / 未知：%s / %s / %s / %s\n' "$healthy" "$warning" "$down" "$unknown"
    printf '线路组就绪 / 警告 / 未就绪：%s / %s / %s\n' "$groups_ready" "$groups_warning" "$groups_not_ready"
    printf '最近监控时间：%s\n' "$last_monitor"
    printf 'monitor timer：%s\n' "$(monitor_timer_enabled_status)"
    printf 'notify：%s\n' "$([[ "$(notify_enabled_status)" == "true" ]] && printf enabled || printf disabled)"
    printf 'nftables 差异：%s\n' "$(nft_mismatch_status)"
    printf '流量计数器：%s\n' "$(traffic_counter_status)"
    printf '\n线路组问题：\n'
    if [[ "$group_count" -eq 0 ]]; then
        print_no_group_message
    else
        while IFS= read -r group; do
            [[ -n "$group" ]] || continue
            [[ -z "$group_filter" || "$group" == "$group_filter" ]] || continue
            if [[ "$(group_issue_count "$group")" -gt 0 ]]; then
                groups_with_issues=$((groups_with_issues + 1))
                while IFS= read -r issue; do
                    [[ -n "$issue" ]] || continue
                    printf '  - %s: %s\n' "$group" "${issue%%:*}"
                    if [[ "$issue" == primary\ down\ but\ backup\ healthy:* ]]; then
                        backup_id="${issue#*:}"
                        printf '    bash install.sh switch-dry-run %s %s\n' "$group" "$backup_id"
                        printf '    bash install.sh switch-line %s %s\n' "$group" "$backup_id"
                    elif [[ "$issue" == backup\ down:* ]]; then
                        backup_id="${issue#*:}"
                        printf '    backup %s is not a safe switch target now\n' "$backup_id"
                    fi
                done < <(group_issue_lines "$group" || true)
            fi
        done < <(profile_groups || true)
        [[ "$groups_with_issues" -gt 0 ]] || printf '  - none\n'
    fi
}

group_last_health_check() {
    local group="$1" id last=""
    for id in $(list_group_ingress_profiles "$group"); do
        load_profile "$id" >/dev/null 2>&1 || continue
        [[ -n "${LAST_HEALTH_CHECK_AT:-}" && "${LAST_HEALTH_CHECK_AT}" > "$last" ]] && last="$LAST_HEALTH_CHECK_AT"
    done
    printf '%s\n' "${last:--}"
}

primary_backup_summary() {
    require_root "$@"
    local group primary forwarding backup_count hot_count cold_count ready_state action recommended_backup last_check notify_hint
    if [[ "$(profile_group_count)" -eq 0 ]]; then
        print_no_group_message
        return 0
    fi
    printf '%-16s %-18s %-18s %-7s %-5s %-5s %-10s %-20s %-16s %s\n' "GROUP" "PRIMARY" "ACTIVE" "BACKUP" "HOT" "COLD" "HEALTH" "LAST_CHECK" "NOTIFY" "SUGGESTED ACTION"
    while IFS= read -r group; do
        [[ -n "$group" ]] || continue
        primary="$(list_group_primary_profiles "$group" | join_profile_list)"
        forwarding="$(list_group_forwarding_profiles "$group" | join_profile_list)"
        backup_count="$(list_group_backup_profiles "$group" | awk 'NF{c++} END{print c+0}')"
        hot_count="$(group_hot_standby_count "$group")"
        cold_count="$(group_cold_standby_count "$group")"
        ready_state="$(group_ready_state "$group")"
        recommended_backup="$(first_healthy_backup_in_group "$group" || true)"
        last_check="$(group_last_health_check "$group")"
        notify_hint="$([[ "$(notify_enabled_status)" == "true" ]] && printf monitor-notify || printf notify-disabled)"
        case "$ready_state" in
            ready) action="monitor / dry-run before switch" ;;
            warning) [[ -n "$recommended_backup" ]] && action="switch-dry-run ${group} ${recommended_backup}" || action="review warnings" ;;
            *) action="primary-backup-check ${group}" ;;
        esac
        printf '%-16s %-18s %-18s %-7s %-5s %-5s %-10s %-20s %-16s %s\n' "$group" "$primary" "$forwarding" "$backup_count" "$hot_count" "$cold_count" "$ready_state" "$last_check" "$notify_hint" "$action"
    done < <(profile_groups || true)
}

self_check_line() {
    local status="$1" item="$2" detail="${3:-}"
    if [[ -n "$detail" ]]; then
        printf '[%s] %s: %s\n' "$status" "$item" "$detail"
    else
        printf '[%s] %s\n' "$status" "$item"
    fi
}

self_check_command() {
    local cmd="$1" required="${2:-true}"
    if command_exists "$cmd"; then
        self_check_line OK "${cmd} 命令" "$(command -v "$cmd" 2>/dev/null || printf 已找到)"
    elif [[ "$required" == "true" ]]; then
        self_check_line WARN "${cmd} 命令" "缺失"
    else
        self_check_line INFO "${cmd} 命令" "可选，缺失"
    fi
}

self_check() {
    local id profile_count=0 switch_size=0 health_size=0 notify_mode config_mode profiles_mode et_path timer_enabled timer_active
    local running_instances legacy_enabled legacy_active landing_count ingress_count transit_count other_count role_hint
    local backup_count=0 backup_latest=""
    printf 'ix-transit-fabric 自检\n'
    printf '版本：%s\n' "$SCRIPT_VERSION"
    printf '只读检查：不会切换线路，不会重启服务，不会应用 nftables。\n'
    self_check_line "$([[ "${EUID:-$(id -u)}" -eq 0 ]] && printf OK || printf WARN)" "root 权限" "$([[ "${EUID:-$(id -u)}" -eq 0 ]] && printf 是 || printf 否)"

    printf '\n必需命令：\n'
    for cmd in bash systemctl nft ip ss sed awk grep; do
        self_check_command "$cmd" true
    done
    if command_exists curl || command_exists wget; then
        self_check_line OK "curl/wget" "可用"
    else
        self_check_line WARN "curl/wget" "缺失；下载或 Telegram 通知可能失败"
    fi
    if detect_nc_cmd >/dev/null 2>&1; then
        self_check_line OK "nc/ncat" "$(detect_nc_cmd)"
    else
        self_check_line INFO "nc/ncat" "缺失；TCP 探测将跳过；可运行：bash install.sh install-netcat"
    fi

    printf '\n快捷命令：\n'
    if [[ -x "$IX_CLI_BIN" && -x "$IX_CLI_BIN_UPPER" && -f "$IX_CLI_INSTALL_SH" ]]; then
        self_check_line OK "ix / IX" "已安装（${IX_CLI_BIN}）"
    else
        self_check_line INFO "ix / IX" "未安装；运行：bash install.sh install-ix-cli"
    fi

    printf '\n运行状态：\n'
    et_path="$(detect_easytier_binary 2>/dev/null || true)"
    [[ -n "$et_path" ]] && self_check_line OK "EasyTier" "$et_path" || self_check_line WARN "EasyTier" "未安装；请运行：bash install.sh install-easytier"
    [[ -d "$CONFIG_DIR" ]] && config_mode="$(path_mode "$CONFIG_DIR")" || config_mode="缺失"
    [[ -d "$PROFILES_DIR" ]] && profiles_mode="$(path_mode "$PROFILES_DIR")" || profiles_mode="缺失"
    self_check_line "$([[ -d "$CONFIG_DIR" ]] && printf OK || printf WARN)" "配置目录" "${CONFIG_DIR} 权限=${config_mode}"
    self_check_line "$([[ -d "$PROFILES_DIR" ]] && printf OK || printf WARN)" "线路目录" "${PROFILES_DIR} 权限=${profiles_mode}"
    if [[ -e "$NOTIFY_ENV_FILE" ]]; then
        notify_mode="$(path_mode "$NOTIFY_ENV_FILE")"
        [[ "$notify_mode" == "600" ]] && self_check_line OK "通知配置" "权限=600" || self_check_line WARN "通知配置" "权限=${notify_mode}；建议 600"
    else
        self_check_line INFO "通知配置" "未配置"
    fi
    [[ -e "$ENV_FILE" ]] && self_check_line INFO "旧单线路配置" "存在：${ENV_FILE}" || self_check_line OK "旧单线路配置" "不存在"
    if [[ -d "$PROFILES_DIR" ]]; then
        profile_count="$(profile_ids | awk 'NF{c++} END{print c+0}')"
    fi
    [[ "$profile_count" -gt 0 ]] && self_check_line OK "线路数量" "${profile_count}" || self_check_line WARN "线路数量" "0"
    read -r landing_count ingress_count transit_count other_count < <(profile_role_counts)
    self_check_line INFO "落地线路数" "${landing_count:-0}"
    self_check_line INFO "公网入口线路数" "${ingress_count:-0}"
    self_check_line INFO "NAT IX 中转线路数" "${transit_count:-0}"
    role_hint="$(host_role_hint_zh)"
    self_check_line INFO "当前机器角色" "$role_hint"
    [[ -e "$PROFILE_SERVICE_TEMPLATE" ]] && self_check_line OK "线路 systemd 模板" "$PROFILE_SERVICE_TEMPLATE" || self_check_line WARN "线路 systemd 模板" "缺失"
    if command_exists systemctl; then
        running_instances="$(systemctl list-units 'ix-transit-easytier@*.service' --state=running --no-legend --no-pager 2>/dev/null | awk '{print $1}' | paste -sd ',' -)"
        self_check_line INFO "运行中的线路服务" "${running_instances:-无}"
        if [[ -e "$SYSTEMD_SERVICE" ]]; then
            legacy_active="$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || printf unknown)"
            legacy_enabled="$(systemctl is-enabled "$SERVICE_NAME" 2>/dev/null || printf unknown)"
            self_check_line INFO "旧版服务" "${SERVICE_NAME} 状态=${legacy_active} 自启=${legacy_enabled}；兼容残留，线路模式已忽略"
        else
            self_check_line OK "旧版服务" "不存在"
        fi
    else
        self_check_line WARN "运行中的线路服务" "systemctl 不可用"
        [[ -e "$SYSTEMD_SERVICE" ]] && self_check_line INFO "旧版服务" "存在：${SYSTEMD_SERVICE}；兼容残留" || self_check_line OK "旧版服务" "不存在"
    fi
    if command_exists nft && nft list table ip "$NFT_TABLE" >/dev/null 2>&1; then
        self_check_line OK "nftables 项目表" "table ip ${NFT_TABLE}"
    else
        self_check_line INFO "nftables 项目表" "未找到或 nft 不可用"
    fi
    self_check_line INFO "危险命令扫描" "请在仓库中运行：bash tests/smoke.sh"
    self_check_line INFO "监控定时器" "$(self_check_monitor_timer_status)"
    self_check_line INFO "DDNS 定时器" "$(self_check_ddns_timer_status)"
    load_notify_config
    self_check_line INFO "通知" "启用=${NOTIFY_ENABLED:-false} 提供方=${NOTIFY_PROVIDER:-telegram}"
    [[ -e "$SWITCH_HISTORY_FILE" ]] && switch_size="$(wc -c <"$SWITCH_HISTORY_FILE" 2>/dev/null || printf 0)"
    [[ -e "$HEALTH_HISTORY_FILE" ]] && health_size="$(wc -c <"$HEALTH_HISTORY_FILE" 2>/dev/null || printf 0)"
    self_check_line INFO "切换历史大小" "${switch_size} 字节"
    self_check_line INFO "健康历史大小" "${health_size} 字节"
    if [[ -d "$BACKUP_DIR" ]]; then
        backup_count="$(find "$BACKUP_DIR" -type f 2>/dev/null | awk 'END{print NR+0}' || true)"
        backup_latest="$(find "$BACKUP_DIR" -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1{sub(/^[^ ]+ /,""); print; exit}' || true)"
        self_check_line INFO "备份文件" "${backup_count:-0} 个${backup_latest:+；最新=${backup_latest}}"
    else
        self_check_line INFO "备份文件" "0 个"
    fi

    printf '\n建议：\n'
    [[ "$profile_count" -gt 0 ]] || printf '  - 正式使用前，请先创建 NAT IX 中转线路或在公网入口机导入接入码。\n'
    detect_nc_cmd >/dev/null 2>&1 || printf '  - TCP 端口诊断可运行：bash install.sh install-netcat\n'
    [[ -n "$et_path" ]] || printf '  - 启动线路前需要安装 EasyTier：bash install.sh install-easytier\n'
    printf '  - 问题反馈可运行：bash install.sh export-diagnostic\n'
    printf '\n开发者检查：\n'
    printf '  - 可运行：bash tests/smoke.sh\n'
    return 0
}

redact_diagnostic_stream() {
    sed -E \
        -e 's/(ET_NETWORK_SECRET=)[^[:space:]]+/\1***REDACTED***/g' \
        -e 's/(TG_BOT_TOKEN=)[^[:space:]]+/\1***REDACTED***/g' \
        -e 's/IXTF1:[A-Za-z0-9._~+\/=-]+/IXTF1:***REDACTED***/g' \
        -e 's#bot[0-9]+:[A-Za-z0-9_-]+#bot***REDACTED***#g'
}

diagnostic_section() {
    local title="$1"
    printf '\n===== %s =====\n' "$title"
}

diagnostic_notify_status() {
    load_notify_config
    printf 'NOTIFY_ENABLED=%s\n' "${NOTIFY_ENABLED:-false}"
    printf 'NOTIFY_PROVIDER=%s\n' "${NOTIFY_PROVIDER:-telegram}"
    printf 'TG_BOT_TOKEN=%s\n' "$(mask_notify_token "${TG_BOT_TOKEN:-}")"
    printf 'TG_CHAT_ID=%s\n' "$([[ -n "${TG_CHAT_ID:-}" ]] && printf 'configured' || printf '(empty)')"
    printf 'NOTIFY_ON_HEALTH_CHANGE=%s\n' "${NOTIFY_ON_HEALTH_CHANGE:-true}"
    printf 'NOTIFY_ON_DOWN=%s\n' "${NOTIFY_ON_DOWN:-true}"
    printf 'NOTIFY_ON_RECOVERY=%s\n' "${NOTIFY_ON_RECOVERY:-true}"
    printf 'NOTIFY_ON_SWITCH=%s\n' "${NOTIFY_ON_SWITCH:-true}"
    printf 'NOTIFY_ON_NFT_MISMATCH=%s\n' "${NOTIFY_ON_NFT_MISMATCH:-true}"
    printf 'NOTIFY_MIN_INTERVAL_SECONDS=%s\n' "${NOTIFY_MIN_INTERVAL_SECONDS:-300}"
}

diagnostic_tsv_tail() {
    local file="$1" limit="$2" empty_message="$3"
    [[ -r "$file" ]] || { printf '%s\n' "$empty_message"; return 0; }
    awk -F '\t' -v limit="$limit" '
        NR==1 {header=$0; next}
        {rows[++n]=$0}
        END {
            if (header != "") print header
            if (n == 0) {
                print "(empty)"
                exit
            }
            start=n-limit+1
            if (start < 1) start=1
            for (i=start; i<=n; i++) print rows[i]
        }
    ' "$file"
}

export_diagnostic() {
    require_root "$@"
    local stamp output tmp unit
    stamp="$(date +%Y%m%d-%H%M%S)"
    output="${IXTF_DIAGNOSTIC_DIR:-/tmp}/ix-transit-diagnostic-${stamp}.txt"
    tmp="$(make_tmp_file "ix-transit-diagnostic")"
    {
        diagnostic_section "版本信息"
        printf 'ix-transit-fabric %s\n' "$SCRIPT_VERSION"
        printf '主机名：%s\n' "$(hostname 2>/dev/null || printf 未知)"
        printf '时间：%s\n' "$(date -Is 2>/dev/null || utc_now)"

        diagnostic_section "自检"
        self_check 2>&1 || true

        diagnostic_section "线路状态汇总"
        status_all 2>&1 || true

        diagnostic_section "健康报告"
        health_report 2>&1 || true

        diagnostic_section "主备摘要"
        primary_backup_summary 2>&1 || true

        diagnostic_section "nftables 转发校验"
        verify_nft_profiles_core 2>&1 || true

        diagnostic_section "监控状态"
        monitor_status 2>&1 || true

        diagnostic_section "通知配置"
        diagnostic_notify_status 2>&1 || true

        diagnostic_section "流量统计"
        traffic_report 2>&1 || true

        diagnostic_section "线路原始配置"
        if [[ -d "$PROFILES_DIR" ]]; then
            for unit in $(profile_ids); do
                printf '\n--- %s ---\n' "$unit"
                if load_profile "$unit"; then
                    print_config_summary_diagnostic loaded 2>&1 || true
                else
                    printf '无法读取线路配置\n'
                fi
            done
        else
            printf '无 profiles 目录\n'
        fi

        diagnostic_section "最近切换历史"
        diagnostic_tsv_tail "$(switch_history_path)" 20 "无切换历史记录。" 2>&1 || true

        diagnostic_section "最近健康历史"
        diagnostic_tsv_tail "$HEALTH_HISTORY_FILE" 50 "无健康检查历史。" 2>&1 || true

        diagnostic_section "端口映射"
        show_port_map --all 2>&1 || true

        diagnostic_section "nftables 项目表"
        show_nft 2>&1 || true

        diagnostic_section "systemd 服务摘要"
        if command_exists systemctl; then
            for unit in "$SERVICE_NAME" "$MONITOR_SERVICE_NAME" "$MONITOR_TIMER_NAME"; do
                printf '%s 运行=%s 自启=%s\n' "$unit" \
                    "$(systemctl is-active "$unit" 2>/dev/null || printf 未知)" \
                    "$(systemctl is-enabled "$unit" 2>/dev/null || printf 未知)"
            done
        else
            printf 'systemctl 不可用\n'
        fi
    } | redact_diagnostic_stream >"$tmp"
    install -m 0600 "$tmp" "$output"
    rm -f -- "$tmp"
    printf '%s\n' "$output"
}

trim_tsv_keep() {
    local file="$1" keep="$2" tmp total start
    [[ -e "$file" ]] || return 0
    [[ "$keep" =~ ^[0-9]+$ && "$keep" -gt 0 ]] || return 1
    tmp="$(make_tmp_file "ix-transit-fabric.trim")"
    total="$(awk 'NR>1{c++} END{print c+0}' "$file")"
    if [[ "$total" -le "$keep" ]]; then
        rm -f -- "$tmp"
        return 0
    fi
    start=$((total - keep + 2))
    awk -v start="$start" 'NR==1 || NR>=start {print}' "$file" >"$tmp"
    install -m 0600 "$tmp" "$file"
    rm -f -- "$tmp"
}

cleanup_history() {
    require_root "$@"
    local keep_health=1000 keep_switch=200
    while (($#)); do
        case "$1" in
            --keep-health)
                shift
                keep_health="${1:-}"
                ;;
            --keep-switch)
                shift
                keep_switch="${1:-}"
                ;;
            *)
                die_user "用法：cleanup-history [--keep-health N] [--keep-switch N]"
                ;;
        esac
        [[ -n "${1:-}" ]] || die_user "cleanup-history 参数缺少数值。"
        shift || true
    done
    [[ "$keep_health" =~ ^[0-9]+$ && "$keep_health" -gt 0 ]] || die_user "--keep-health 必须是正整数。"
    [[ "$keep_switch" =~ ^[0-9]+$ && "$keep_switch" -gt 0 ]] || die_user "--keep-switch 必须是正整数。"
    trim_tsv_keep "$HEALTH_HISTORY_FILE" "$keep_health"
    trim_tsv_keep "$(switch_history_path)" "$keep_switch"
    log_ok "已清理历史：health 保留 ${keep_health} 条，switch 保留 ${keep_switch} 条。"
}

cleanup_state() {
    require_root "$@"
    cleanup_history
    rm -f -- "$MONITOR_LAST_RUN_FILE"
    if [[ -n "${IXTF_TMPDIR:-}" && -d "${IXTF_TMPDIR:-}" ]]; then
        find "$IXTF_TMPDIR" -maxdepth 1 -type f -name 'ix-transit-fabric.*' -mtime +1 -delete 2>/dev/null || true
    fi
    log_ok "已清理 state 中可重建的监控结果和旧临时文件；未删除 profiles、codes、notify.env 或 backups。"
}

doctor_group_warnings() {
    local group
    while IFS= read -r group; do
        [[ -n "$group" ]] || continue
        printf '\n===== 线路组 %s =====\n' "$group"
        print_group_advice "$group"
    done < <(profile_groups)
}

doctor_profile() {
    require_root "$@"
    local profile_id service rc active enabled ip_forward
    profile_id="$(resolve_profile_id "${1:-}")"
    load_profile_or_die "$profile_id"
    service="$(profile_service_name "$profile_id")"

    printf 'ix-transit-fabric Profile 诊断\n'
    printf 'Profile：%s\n' "$profile_id"
    printf '配置文件：%s\n' "$(profile_env_path "$profile_id")"
    printf '配置文件权限：%s\n' "$(path_mode "$(profile_env_path "$profile_id")")"
    validate_profile_config "$profile_id"
    printf '配置校验：通过\n'

    printf '\n配置摘要：\n'
    print_config_summary loaded || true

    printf '\nProfile 服务：%s\n' "$service"
    if command_exists systemctl; then
        active="$(systemctl is-active "$service" 2>/dev/null || true)"
        enabled="$(systemctl is-enabled "$service" 2>/dev/null || true)"
        printf 'systemd 状态：%s（开机自启：%s）\n' "${active:-未知}" "${enabled:-未知}"
    else
        printf 'systemd 状态：systemctl 不可用\n'
    fi

    printf '\nEasyTier 详细状态：\n'
    status_easytier_detailed "$service"

    case "${ROLE:-}" in
        nat-transit)
            printf '\n落地机检查：\n'
            printf 'EasyTier listener：%s/%s\n' "$(proto_display "${ET_LISTENER_PROTO:-}")" "${ET_LISTENER_PORT:-}"
            set +e
            check_listener_proto_port "${ET_LISTENER_PROTO:-tcp}" "${ET_LISTENER_PORT:-0}"
            rc=$?
            set -e
            case "$rc" in
                0) printf 'listener 监听：已检测到\n' ;;
                2) printf 'listener 监听：ss 命令不可用\n' ;;
                *) printf '[WARN] listener 未检测到，请检查 Profile 服务和 logs-profile。\n' ;;
            esac
            check_business_core || true
            ;;
        nat-ingress)
            printf '\n入口机检查：\n'
            printf '业务转发：%s\n' "$([[ "${FORWARD_ENABLED:-true}" == "true" ]] && printf 已配置 || printf 未配置)"
            if command_exists sysctl; then
                ip_forward="$(sysctl -n net.ipv4.ip_forward 2>/dev/null || printf 未知)"
                printf 'ip_forward：%s\n' "$ip_forward"
                if [[ "${FORWARD_ENABLED:-true}" == "true" && "$ip_forward" != "1" ]]; then
                    printf '[WARN] ip_forward 未开启，请运行 add-nat-ingress-from-listener-code 或 sysctl --system。\n'
                fi
            fi
            if [[ "${FORWARD_ENABLED:-true}" == "true" ]]; then
                status_nft
                if command_exists ss; then
                    if ss -lntup 2>/dev/null | grep -Eq "[:.]${LOCAL_PORT:-0}[[:space:]]"; then
                        printf '[WARN] LOCAL_PORT %s 已被本机进程监听，可能和 nft DNAT 冲突。\n' "${LOCAL_PORT:-}"
                    else
                        printf 'LOCAL_PORT 本机监听冲突：未检测到\n'
                    fi
                fi
            fi
            check_business_core || true
            ;;
        nat-ingress|nat-transit)
            printf '\nNAT-IX 检查：\n'
            run_line_health_check "$profile_id" false || true
            ;;
    esac
}

status_all() {
    require_root "$@"
    local verbose="${1:-}" id service active enabled_label forward_label health rule_count total=0 enabled_count=0 forwarding_count=0
    local healthy=0 warning=0 down=0 unknown=0
    [[ "$verbose" == "--verbose" || -z "$verbose" ]] || die_user "用法：status-all [--verbose]"
    # 状态列表不显示主备角色；旧字段保留在诊断导出和主备维护命令中。
    printf '线路ID\t角色\t启用\t转发\t服务\t健康\t规则数\t最近检查\n'
    for id in $(sorted_profile_ids); do
        total=$((total + 1))
        if ! load_profile "$id"; then
            unknown=$((unknown + 1))
            printf '%s\t-\t停止\t停止\t未知\t未检查\t0\t-\n' "$id"
            continue
        fi
        service="$(profile_service_name "$id")"
        active="$(profile_service_status "$service")"
        enabled_label="$(enabled_label_zh "${ENABLED:-true}")"
        forward_label="$(forward_label_zh "${ROLE:-}" "${ENABLED:-true}" "${FORWARD_ENABLED:-true}")"
        rule_count="$(profile_rule_count "$id")"
        [[ "${ENABLED:-true}" == "true" ]] && enabled_count=$((enabled_count + 1))
        [[ "${FORWARD_ENABLED:-true}" == "true" && "${ENABLED:-true}" == "true" ]] && case "${ROLE:-}" in nat-ingress|nat-transit) forwarding_count=$((forwarding_count + 1)) ;; esac
        health="${HEALTH_STATUS:-unknown}"
        case "$health" in
            healthy) healthy=$((healthy + 1)) ;;
            warning) warning=$((warning + 1)) ;;
            down) down=$((down + 1)) ;;
            *) unknown=$((unknown + 1)) ;;
        esac
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$id" "$(profile_role_label_zh "${ROLE:-}")" "$enabled_label" "$forward_label" \
            "$(service_label_zh "${active:-unknown}")" "$(health_label_zh "$health")" "$rule_count" "${LAST_HEALTH_CHECK_AT:--}"
    done
    printf '\n汇总：线路总数=%s 启用=%s 转发中=%s 健康=%s 警告=%s 故障=%s 未检查=%s\n' \
        "$total" "$enabled_count" "$forwarding_count" "$healthy" "$warning" "$down" "$unknown"
    if [[ "$verbose" == "--verbose" ]]; then
        printf '\n线路组详情：\n'
        doctor_group_warnings
        printf '\nnftables 只读校验：\n'
        verify_nft_profiles_core || true
    fi
    return 0
}

doctor_all() {
    require_root "$@"
    local id profile_count=0 enabled_count=0 forwarding_count=0 healthy=0 warning=0 down=0 unknown=0 rc status output reason
    local group_issue_total=0 group issue backup_id service active enabled_label forward_label status_row group_count issue_count nat_profile_count=0
    local -a health_rows=()
    printf 'ix-transit-fabric 全量诊断（doctor-all）\n'
    printf '说明：本命令只读，不会自动切换线路。\n'

    printf '\n===== 线路级问题 =====\n'
    for id in $(sorted_profile_ids); do
        printf '\n--- 线路 %s ---\n' "$id"
        set +e
        output="$(run_line_health_check "$id" false 2>&1)"
        rc=$?
        set -e
        printf '%s\n' "$output"
        profile_count=$((profile_count + 1))
        if load_profile "$id" >/dev/null 2>&1; then
            [[ "${ENABLED:-true}" == "true" ]] && enabled_count=$((enabled_count + 1))
            forward_label="$(forward_display "${ROLE:-}" "${ENABLED:-true}" "${FORWARD_ENABLED:-true}")"
            [[ "$forward_label" == "active" ]] && forwarding_count=$((forwarding_count + 1))
            case "${ROLE:-}" in nat-ingress|nat-transit) nat_profile_count=$((nat_profile_count + 1)) ;; esac
        fi
        status="$(grep -E '^HEALTH_STATUS=' <<<"$output" | tail -n 1 | cut -d= -f2- || true)"
        status="${status:-unknown}"
        reason="$(grep -E '^LAST_HEALTH_REASON=' <<<"$output" | tail -n 1 | cut -d= -f2- || true)"
        reason="${reason:-未检查}"
        health_rows+=("${id}"$'\t'"${status}"$'\t'"${reason}")
        if [[ "$rc" -ne 0 ]]; then
            unknown=$((unknown + 1))
            printf '[WARN] 线路 %s 诊断失败（退出码 %s），已继续检查其他线路。\n' "$id" "$rc"
        else
            case "$status" in
                healthy) healthy=$((healthy + 1)) ;;
                warning) warning=$((warning + 1)) ;;
                down) down=$((down + 1)) ;;
                *) unknown=$((unknown + 1)) ;;
            esac
        fi
    done

    printf '\n===== 线路组级问题 =====\n'
    group_count="$(profile_group_count)"
    if [[ "$group_count" -eq 0 ]]; then
        print_no_group_message
    else
        while IFS= read -r group; do
            [[ -n "$group" ]] || continue
            printf '\n--- 线路组 %s ---\n' "$group"
            issue_count="$(group_issue_count "$group")"
            if [[ "$issue_count" -eq 0 ]]; then
                printf '[OK] 未发现线路组问题\n'
                continue
            fi
            while IFS= read -r issue; do
                [[ -n "$issue" ]] || continue
                group_issue_total=$((group_issue_total + 1))
                printf '[WARN] %s\n' "$(group_issue_label_zh "$issue")"
                if [[ "$issue" == primary\ down\ but\ backup\ healthy:* ]]; then
                    backup_id="${issue#*:}"
                    printf '建议：bash install.sh switch-dry-run %s %s\n' "$group" "$backup_id"
                    printf '执行：bash install.sh switch-line %s %s\n' "$group" "$backup_id"
                fi
            done < <(group_issue_lines "$group" || true)
        done < <(profile_groups || true)
    fi

    printf '\n===== 线路组角色提示 =====\n'
    while IFS= read -r id; do
        [[ -n "$id" ]] || continue
        load_profile "$id" >/dev/null 2>&1 || continue
        if [[ -n "${LINE_GROUP:-}" && "${LINE_ROLE:-standalone}" == "standalone" ]]; then
            printf '[WARN] %s 设置了 LINE_GROUP=%s，但 LINE_ROLE=standalone；该 Profile 不参与主备切换。\n' "$id" "$LINE_GROUP"
        elif [[ -z "${LINE_GROUP:-}" && "${LINE_ROLE:-standalone}" != "standalone" ]]; then
            printf '[WARN] %s 设置了 LINE_ROLE=%s，但 LINE_GROUP 为空；主备角色缺少 LINE_GROUP。\n' "$id" "${LINE_ROLE:-standalone}"
        fi
    done < <(profile_ids || true)
    if [[ "$group_count" -eq 0 ]]; then
        printf '[OK] 独立线路（standalone）无需设置 LINE_GROUP。\n'
    fi

    printf '\n===== nftables 规则问题 =====\n'
    verify_nft_profiles_core || true

    printf '\n===== 服务状态 =====\n'
    for id in $(sorted_profile_ids); do
        load_profile "$id" >/dev/null 2>&1 || { printf '[WARN] %s：无法读取线路配置，跳过服务检查\n' "$id"; continue; }
        service="$(profile_service_name "$id")"
        if command_exists systemctl; then
            active="$(systemctl is-active "$service" 2>/dev/null || true)"
            enabled_label="$(systemctl is-enabled "$service" 2>/dev/null || true)"
            printf '%s\t%s\t%s\n' "$id" "${active:-未知}" "${enabled_label:-未知}"
        else
            printf '%s\tsystemctl不可用\t未知\n' "$id"
        fi
    done

    printf '\n===== 健康状态异常 =====\n'
    for status_row in "${health_rows[@]}"; do
        IFS=$'\t' read -r id status reason <<<"$status_row"
        case "${status:-unknown}" in
            healthy) ;;
            *) printf '[WARN] %s 健康=%s 原因=%s\n' "$id" "${status:-unknown}" "${reason:-未检查}" ;;
        esac
    done

    printf '\n汇总：\n'
    printf '线路数=%s\n' "$profile_count"
    printf '启用数=%s\n' "$enabled_count"
    printf '转发中=%s\n' "$forwarding_count"
    printf '健康=%s 警告=%s 故障=%s 未检查=%s\n' "$healthy" "$warning" "$down" "$unknown"
    printf '线路组问题数=%s\n' "$group_issue_total"
    if [[ "$nat_profile_count" -gt 0 ]]; then
        printf 'NAT-IX 延迟诊断：bash install.sh latency-report 线路ID\n'
    fi
    printf '自动切换：已禁用。请先 switch-dry-run，确认后再手动 switch-line。\n'
}

restart_all() {
    require_root "$@"
    local id
    for id in $(profile_ids); do
        load_profile "$id" || continue
        [[ "${ENABLED:-true}" == "true" ]] || continue
        restart_profile "$id" || true
    done
}

migrate_single_profile() {
    require_root "$@"
    ensure_profile_dirs
    [[ -f "$ENV_FILE" ]] || die_user "未找到旧单线路配置：${ENV_FILE}"
    [[ ! -f "$(profile_env_path default)" ]] || die_user "default profile 已存在。"
    load_env || die_user "无法读取旧单线路配置。"
    PROFILE_ID="default"
    PROFILE_NAME="default"
    ENABLED="true"
    normalize_profile_compat_vars
    save_profile_env default
    log_ok "已迁移旧单线路配置为 default profile。"
}

status() {
    require_root "$@"
    if [[ -d "$PROFILES_DIR" && "$(profile_count)" != "0" ]]; then
        status_profile "$(resolve_profile_id "")"
        return 0
    fi
    print_config_summary || true
    printf '\n'
    status_easytier
    if [[ "${ROLE:-}" == "nat-ingress" ]]; then
        if [[ "${FORWARD_ENABLED:-true}" == "true" ]]; then
            status_nft
            if command_exists sysctl; then
                printf 'IPv4 转发：%s\n' "$(sysctl -n net.ipv4.ip_forward 2>/dev/null || printf '未知')"
            else
                printf 'IPv4 转发：sysctl 不可用\n'
            fi
        else
            printf '业务转发：未配置\n'
        fi
    fi
    printf '\n提示：运行 bash install.sh doctor 获取详细诊断。\n'
    printf '提示：运行 bash install.sh logs 查看日志。\n'
    printf '提示：运行 bash install.sh show-nft 查看本项目 nftables 规则。\n'
}

path_mode() {
    local path="$1"
    if [[ -e "$path" ]]; then
        stat -c '%a' "$path" 2>/dev/null || printf '未知'
    else
        printf '不存在'
    fi
}

check_ss_port() {
    local proto="$1"
    local port="$2"
    command_exists ss || return 2
    if [[ "$proto" == "tcp" ]]; then
        ss -lntp 2>/dev/null | grep -Eq "[:.]${port}[[:space:]]"
    else
        ss -lnup 2>/dev/null | grep -Eq "[:.]${port}[[:space:]]"
    fi
}

check_listener_proto_port() {
    local proto="$1"
    local port="$2"
    local rc tcp_rc udp_rc
    if [[ "$proto" == "both" ]]; then
        set +e
        check_ss_port tcp "$port"
        tcp_rc=$?
        check_ss_port udp "$port"
        udp_rc=$?
        set -e
        if [[ "$tcp_rc" -eq 2 || "$udp_rc" -eq 2 ]]; then
            return 2
        fi
        [[ "$tcp_rc" -eq 0 && "$udp_rc" -eq 0 ]]
        return $?
    fi

    set +e
    check_ss_port "$proto" "$port"
    rc=$?
    set -e
    return "$rc"
}

check_easytier_version_compat() {
    local landing_version="${1:-}"
    local et_path local_version answer
    [[ -n "$landing_version" ]] || return 0

    et_path="$(detect_easytier_binary 2>/dev/null || true)"
    if [[ -z "$et_path" ]]; then
        log_warn "本机未找到 EasyTier，后续将按需安装。"
        return 0
    fi

    local_version="$(get_easytier_version "$et_path")"
    [[ "$local_version" == "$landing_version" ]] && return 0

    cat >&2 <<EOF
[WARN] 落地机 EasyTier 版本：${landing_version}
[WARN] 本机 EasyTier 版本：${local_version}
[WARN] 建议运行 update-easytier 保持一致。
EOF
    if [[ "${EUID}" -ne 0 ]]; then
        log_warn "当前不是 root，无法自动更新 EasyTier；请稍后用 root 运行 bash install.sh update-easytier。"
    elif is_interactive_input; then
        answer="$(prompt_yes_no "是否现在更新 EasyTier" "true")" || answer="false"
        if [[ "$answer" == "true" ]]; then
            update_easytier
        else
            log_warn "已继续使用当前 EasyTier 版本；doctor 会继续提示版本不一致。"
        fi
    fi
}

doctor() {
    local et_path et_version active ip_forward rc service_type active_since ts now age nc_cmd
    if [[ -d "$PROFILES_DIR" && "$(profile_count)" != "0" ]]; then
        local profile_id
        profile_id="$(resolve_profile_id "${1:-}")"
        run_line_health_check "$profile_id" false
        printf '\n端口映射：\n'
        show_port_map "$profile_id" || true
        printf '\n提示：Profile 模式使用 systemd 实例 %s。\n' "$(profile_service_name "$profile_id")"
        return 0
    fi
    printf 'ix-transit-fabric 诊断\n'
    printf '是否 root：%s\n' "$([[ "${EUID}" -eq 0 ]] && printf 是 || printf 否)"
    printf '配置文件：%s\n' "$([[ -f "$ENV_FILE" ]] && printf 存在 || printf 不存在)"
    printf '配置目录权限：%s\n' "$(path_mode "$CONFIG_DIR")"
    printf 'env 文件权限：%s\n' "$(path_mode "$ENV_FILE")"

    if [[ -f "$ENV_FILE" && ! -r "$ENV_FILE" ]]; then
        printf '[WARN] 配置文件存在但当前用户不可读，请使用 sudo 重新运行 doctor。\n'
    fi

    if load_env; then
        printf '\n配置摘要：\n'
        print_config_summary loaded || true
    else
        printf '\n[WARN] 未找到可读取的配置文件：%s。\n' "$ENV_FILE"
    fi

    et_path="$(detect_easytier_binary 2>/dev/null || true)"
    et_version=""
    if [[ -n "$et_path" ]]; then
        et_version="$(get_easytier_version "$et_path")"
        printf '\nEasyTier：已安装\n'
        printf 'EasyTier 程序路径：%s\n' "$et_path"
        printf 'EasyTier 版本：%s\n' "$et_version"
    else
        printf '\nEasyTier：未安装\n'
        printf '[WARN] 请运行：bash install.sh install-easytier\n'
        printf '[WARN] 国内机器下载失败时，请设置 IXTF_GITHUB_MIRRORS 或 IXTF_EASYTIER_DOWNLOAD_URL。\n'
    fi

    if [[ -n "${LANDING_EASYTIER_VERSION:-${CODE_EASYTIER_VERSION:-}}" && -n "$et_version" && "$et_version" != "${LANDING_EASYTIER_VERSION:-${CODE_EASYTIER_VERSION:-}}" ]]; then
        printf '[WARN] EasyTier 版本不一致：落地机 %s，本机 %s。建议运行 bash install.sh update-easytier。\n' "${LANDING_EASYTIER_VERSION:-${CODE_EASYTIER_VERSION:-}}" "$et_version"
    fi

    printf 'systemd：%s\n' "$(command_exists systemctl && printf 可用 || printf 不可用)"
    printf 'nft：%s\n' "$(command_exists nft && printf 可用 || printf 不可用)"

    if command_exists systemctl; then
        active="$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || true)"
        printf 'EasyTier 服务状态：%s\n' "${active:-未知}"
        service_type="$(systemctl show "$SERVICE_NAME" -p Type --value 2>/dev/null || true)"
        [[ -n "$service_type" ]] && printf 'EasyTier systemd Type：%s\n' "$service_type"
        if [[ -n "$service_type" && "$service_type" != "simple" ]]; then
            printf '[WARN] 如果 easytier-core 是前台常驻进程，systemd Type 建议使用 simple。请重新运行安装生成服务文件。\n'
        fi
        if [[ "$active" == "activating" ]]; then
            active_since="$(systemctl show "$SERVICE_NAME" -p ActiveEnterTimestamp --value 2>/dev/null || true)"
            ts="$(date -d "$active_since" +%s 2>/dev/null || printf '')"
            now="$(date +%s)"
            if [[ -n "$ts" ]]; then
                age=$((now - ts))
                printf '[WARN] EasyTier 服务仍在 activating（约 %s 秒）。建议运行：journalctl -u %s -n 80 --no-pager\n' "$age" "$SERVICE_NAME"
            else
                printf '[WARN] EasyTier 服务仍在 activating。建议运行：journalctl -u %s -n 80 --no-pager\n' "$SERVICE_NAME"
            fi
            printf '\n最近 20 行 EasyTier 日志摘要（已隐藏密钥）：\n'
            print_recent_service_logs 20
        fi
        [[ "$active" == "active" ]] || printf '[WARN] EasyTier 服务未运行，请运行：systemctl restart %s\n' "$SERVICE_NAME"
        analyze_recent_easytier_logs
    fi

    printf '\nEasyTier 详细状态：\n'
    status_easytier_detailed

    case "${ROLE:-}" in
        nat-transit)
            printf '\n落地机检查：\n'
            printf 'EasyTier listener：%s/%s\n' "$(proto_display "${ET_LISTENER_PROTO:-}")" "${ET_LISTENER_PORT:-}"
            set +e
            check_listener_proto_port "${ET_LISTENER_PROTO:-tcp}" "${ET_LISTENER_PORT:-0}"
            rc=$?
            set -e
            if [[ "$rc" -eq 0 ]]; then
                printf 'listener 监听：已检测到\n'
            elif [[ "$rc" -eq 2 ]]; then
                printf 'listener 监听：ss 命令不可用\n'
            else
                printf 'listener 监听：未检测到\n'
                printf '[WARN] landing listener 未监听，请检查 EasyTier 参数和 logs。\n'
            fi
            check_business_core || true
            ;;
        nat-ingress)
            printf '\n入口机检查：\n'
            if [[ "${FORWARD_ENABLED:-true}" != "true" ]]; then
                printf '业务转发：未配置\n'
                printf '[INFO] 可先确认 EasyTier 互通，再运行 bash install.sh configure-forward 配置业务转发。\n'
            fi
            if command_exists sysctl; then
                ip_forward="$(sysctl -n net.ipv4.ip_forward 2>/dev/null || printf 未知)"
                printf 'ip_forward：%s\n' "$ip_forward"
                if [[ "${FORWARD_ENABLED:-true}" == "true" ]]; then
                    [[ "$ip_forward" == "1" ]] || printf '[WARN] ip_forward 未开启，请重新运行 add-nat-ingress-from-listener-code 或执行 sysctl --system。\n'
                fi
            fi

            if [[ "${FORWARD_ENABLED:-true}" == "true" ]] && command_exists nft; then
                if nft list table ip "$NFT_TABLE" >/dev/null 2>&1; then
                    printf 'nftables 项目表：存在\n'
                else
                    printf 'nftables 项目表：不存在\n'
                    printf '[WARN] nftables 表不存在，请重新运行 add-nat-ingress-from-listener-code。\n'
                fi
            fi

            if [[ "${FORWARD_ENABLED:-true}" == "true" ]] && command_exists ss; then
                if ss -lntup 2>/dev/null | grep -Eq "[:.]${LOCAL_PORT:-0}[[:space:]]"; then
                    printf '[WARN] LOCAL_PORT %s 已被本机进程监听，可能和 nft DNAT 冲突。\n' "${LOCAL_PORT:-}"
                else
                    printf 'LOCAL_PORT 本机监听冲突：未检测到\n'
                fi
            fi

            if [[ "${CNIX_ENTRY_PROTO:-}" == "tcp" || "${CNIX_ENTRY_PROTO:-}" == "both" ]]; then
                if nc_cmd="$(detect_nc_cmd 2>/dev/null)"; then
                    if "$nc_cmd" -vz -w 3 "$CNIX_ENTRY_HOST" "$CNIX_ENTRY_PORT" >/dev/null 2>&1; then
                        printf 'CNIX TCP 可达性：可达\n'
                    else
                        printf 'CNIX TCP 可达性：不可达\n'
                        if [[ "${CNIX_ENTRY_PROTO:-}" == "both" ]]; then
                            printf '[WARN] CNIX TCP 不通，但当前入口协议为 TCP/UDP，UDP 可能仍可用。UDP 探测不可靠。\n'
                        else
                            printf '[WARN] CNIX TCP 不通，请检查 CNIX 面板入口、协议、端口和安全组。\n'
                        fi
                    fi
                else
                    printf 'CNIX TCP 可达性：nc/ncat 不可用\n'
                    suggest_install_nc
                fi
            fi

            if [[ "${CNIX_ENTRY_PROTO:-}" == "udp" || "${CNIX_ENTRY_PROTO:-}" == "both" ]]; then
                printf 'CNIX UDP 探测：跳过，UDP 探测不可靠；如果 CNIX 支持 UDP 且 TCP 不通，可尝试 TCP/UDP 或 UDP。\n'
            fi

            if command_exists ping && [[ -n "${LANDING_ET_IP:-}" ]]; then
                if ping -c 1 -W 3 "$LANDING_ET_IP" >/dev/null 2>&1; then
                    printf '落地机 EasyTier IP ping：成功\n'
                else
                    printf '[WARN] ping 落地机 EasyTier IP 失败，这只是排障线索，不代表一定不可用。\n'
                    printf '[WARN] 请先确认 CNIX 面板出口是否填写 LISTENER_PORT，不要填写 REMOTE_PORT。\n'
                fi
            fi
            check_business_core || true
            ;;
    esac

    printf '\n更多命令：\n'
    printf '  bash install.sh check-port\n'
    printf '  bash install.sh check-business\n'
    printf '  bash install.sh check-route\n'
    printf '  bash install.sh show-port-map\n'
    printf '  bash install.sh panel-guide\n'
    printf '  bash install.sh show-nft\n'
}

logs() {
    require_root "$@"
    command_exists journalctl || die_user "未找到 journalctl。"

    local secret=""
    if load_env; then
        secret="${ET_NETWORK_SECRET:-}"
    fi

    journalctl -u "$SERVICE_NAME" -n 80 --no-pager 2>&1 | while IFS= read -r line; do
        if [[ -n "$secret" ]]; then
            line="${line//$secret/[hidden]}"
        fi
        printf '%s\n' "$line"
    done
    analyze_recent_easytier_logs
}

check_wrapper() {
    local mode service_exec
    printf 'EasyTier 启动包装器检查\n'
    printf 'wrapper 路径：%s\n' "$WRAPPER_FILE"

    if [[ -f "$WRAPPER_FILE" ]]; then
        mode="$(path_mode "$WRAPPER_FILE")"
        printf 'wrapper 是否存在：是\n'
        printf 'wrapper 权限：%s\n' "$mode"
        case "$mode" in
            700|750|755) printf 'wrapper 权限是否合理：是\n' ;;
            *) printf '[WARN] wrapper 权限不常见，建议 700、750 或 755。\n' ;;
        esac

        if grep -q 'set -x' "$WRAPPER_FILE"; then
            printf '[WARN] wrapper 包含 set -x，可能暴露敏感运行信息。\n'
        else
            printf 'wrapper set -x：未发现\n'
        fi

        if grep -Eq 'echo[[:space:]].*ET_NETWORK_SECRET|printf[[:space:]].*ET_NETWORK_SECRET' "$WRAPPER_FILE"; then
            printf '[WARN] wrapper 可能直接输出 ET_NETWORK_SECRET。\n'
        else
            printf 'wrapper 直接输出密钥：未发现\n'
        fi

        if grep -q "$ENV_FILE" "$WRAPPER_FILE"; then
            printf 'wrapper 引用 EnvironmentFile：是\n'
        else
            printf '[WARN] wrapper 未引用 %s。\n' "$ENV_FILE"
        fi

        if grep -q 'exec "$EASYTIER_BIN"' "$WRAPPER_FILE"; then
            printf 'wrapper 前台运行 easytier-core：是\n'
        else
            printf '[WARN] wrapper 可能没有用 exec 前台运行 easytier-core。\n'
        fi
    else
        printf 'wrapper 是否存在：否\n'
        printf '[WARN] 请重新运行 add-nat-listener-profile 或 add-nat-ingress-from-listener-code 生成 wrapper。\n'
    fi

    if [[ -f "$SYSTEMD_SERVICE" ]]; then
        service_exec="$(grep -E '^ExecStart=' "$SYSTEMD_SERVICE" | tail -n 1 || true)"
        printf 'systemd ExecStart：%s\n' "${service_exec:-未找到}"
        if [[ "$service_exec" == "ExecStart=${WRAPPER_FILE}" ]]; then
            printf 'systemd 是否指向 wrapper：是\n'
        else
            printf '[WARN] systemd ExecStart 未指向 wrapper。\n'
        fi
    else
        printf 'systemd 服务文件：不存在\n'
    fi
}

check_port() {
    local target="${1:-}" ss_output ip_forward nc_cmd
    if [[ "$target" == "--all" ]]; then
        local id
        for id in $(profile_ids); do
            printf '\n===== 线路 %s =====\n' "$id"
            check_port "$id" || true
        done
        return 0
    fi
    if [[ -n "$target" || ( -d "$PROFILES_DIR" && "$(profile_count)" != "0" ) ]]; then
        local resolved
        if ! resolved="$(resolve_profile_id_for_cmd "$target" check-port)"; then
            return_or_exit 2 || return $?
        fi
        if ! load_profile "$resolved"; then
            print_profile_selection_hint "$resolved" check-port
            return_or_exit 2 || return $?
        fi
    else
        load_env_or_warn || return 0
    fi
    normalize_profile_compat_vars

    case "${ROLE:-}" in
        nat-transit)
            printf '落地机端口检查\n'
            if [[ -z "${ET_LISTENER_PORT:-${LISTENER_PORT:-}}" ]]; then
                printf '[WARN] Profile 缺少 LISTENER_PORT，请检查配置文件。\n'
                return 0
            fi
            printf 'EasyTier listener：%s/%s\n' "$(proto_display "${ET_LISTENER_PROTO:-${LISTENER_PROTOS:-}}")" "${ET_LISTENER_PORT:-${LISTENER_PORT:-}}"
            if ! command_exists ss; then
                printf '[WARN] 未找到 ss 命令，无法检查监听端口。\n'
                return 0
            fi

            case "${ET_LISTENER_PROTO:-tcp}" in
                tcp)
                    ss_output="$(ss -lntp 2>/dev/null | grep -E "[:.]${ET_LISTENER_PORT:-${LISTENER_PORT:-0}}[[:space:]]" || true)"
                    ;;
                udp)
                    ss_output="$(ss -lnup 2>/dev/null | grep -E "[:.]${ET_LISTENER_PORT:-${LISTENER_PORT:-0}}[[:space:]]" || true)"
                    ;;
                both)
                    ss_output="$({
                        ss -lntp 2>/dev/null | grep -E "[:.]${ET_LISTENER_PORT:-${LISTENER_PORT:-0}}[[:space:]]" || true
                        ss -lnup 2>/dev/null | grep -E "[:.]${ET_LISTENER_PORT:-${LISTENER_PORT:-0}}[[:space:]]" || true
                    })"
                    ;;
                *)
                    ss_output="$({
                        ss -lntp 2>/dev/null | grep -E "[:.]${ET_LISTENER_PORT:-${LISTENER_PORT:-0}}[[:space:]]" || true
                        ss -lnup 2>/dev/null | grep -E "[:.]${ET_LISTENER_PORT:-${LISTENER_PORT:-0}}[[:space:]]" || true
                    })"
                    ;;
            esac

            if [[ -n "$ss_output" ]]; then
                printf '监听状态：已检测到\n'
                printf '%s\n' "$ss_output"
            else
                printf '[WARN] 未检测到 EasyTier listener 端口监听。\n'
            fi
            if [[ -n "${PROFILE_ID:-}" && "${PROFILE_ID:-default}" != "default" ]]; then
                nat_guide_profile "$PROFILE_ID" || true
            else
                nat_guide || true
            fi
            ;;
        nat-ingress)
            printf '入口机端口检查\n'
            if [[ "${FORWARD_ENABLED:-true}" != "true" ]]; then
                printf '业务转发：未配置\n'
                printf '运行 bash install.sh configure-forward 后再检查 LOCAL_PORT 和 nftables。\n'
                return 0
            fi

            if command_exists ss; then
                ss_output="$(ss -lntup 2>/dev/null | grep -E "[:.]${LOCAL_PORT:-0}[[:space:]]" || true)"
                if [[ -n "$ss_output" ]]; then
                    printf '[WARN] LOCAL_PORT %s 已被本机进程监听，可能和 nft DNAT 冲突。\n' "$LOCAL_PORT"
                    printf '%s\n' "$ss_output"
                else
                    printf 'LOCAL_PORT 本机监听冲突：未检测到\n'
                fi
            else
                printf '[WARN] 未找到 ss 命令，无法检查 LOCAL_PORT。\n'
            fi

            status_nft

            if command_exists sysctl; then
                ip_forward="$(sysctl -n net.ipv4.ip_forward 2>/dev/null || printf 未知)"
                printf 'ip_forward：%s\n' "$ip_forward"
                [[ "$ip_forward" == "1" ]] || printf '[WARN] ip_forward 未开启。\n'
            fi

            if [[ "${FORWARD_PROTO:-both}" == "tcp" || "${FORWARD_PROTO:-both}" == "both" ]]; then
                if nc_cmd="$(detect_nc_cmd 2>/dev/null)"; then
                    if [[ -n "${LANDING_ET_IP:-}" && -n "${REMOTE_PORT:-}" ]] && "$nc_cmd" -vz -w 3 "$LANDING_ET_IP" "$REMOTE_PORT" >/dev/null 2>&1; then
                        printf '落地机业务 TCP 可达性：可达\n'
                    else
                        printf '[WARN] TCP 检查失败：%s:%s。\n' "${LANDING_ET_IP:-LANDING_ET_IP}" "${REMOTE_PORT:-REMOTE_PORT}"
                    fi
                else
                    printf '[WARN] nc/ncat 不可用，跳过 TCP 可达性探测。\n'
                    suggest_install_nc
                fi
            fi

            if [[ "${FORWARD_PROTO:-both}" == "udp" || "${FORWARD_PROTO:-both}" == "both" ]]; then
                printf 'UDP 探测：跳过，UDP 可达性探测不可靠。\n'
            fi
            ;;
        *)
            printf '[WARN] 未知角色：%s\n' "${ROLE:-未设置}"
            ;;
    esac
}

check_business_core() {
    local ss_output tcp_ok="false" udp_ok="false" business_port nc_cmd
    case "${ROLE:-}" in
        nat-transit)
            printf '落地机业务端口检查\n'
            business_port="${REMOTE_PORT:-${SERVICE_PORT:-}}"
            if [[ -z "$business_port" ]]; then
                printf '当前未配置业务端口，可在入口机 configure-forward 时填写。\n'
                return 0
            fi
            printf 'REMOTE_PORT / 业务端口：%s\n' "$business_port"
            if ! command_exists ss; then
                printf '[WARN] 未找到 ss 命令，无法检查业务端口监听。\n'
                return 0
            fi
            ss_output="$({
                ss -lntup 2>/dev/null || true
                ss -lnuap 2>/dev/null || true
            } | grep -E "[:.]${business_port}[[:space:]]" || true)"
            [[ -n "$ss_output" ]] && printf '%s\n' "$ss_output"
            if ss -lntup 2>/dev/null | grep -Eq "[:.]${business_port}[[:space:]]"; then
                tcp_ok="true"
            fi
            if ss -lnuap 2>/dev/null | grep -Eq "[:.]${business_port}[[:space:]]"; then
                udp_ok="true"
            fi
            if [[ "$tcp_ok" == "true" || "$udp_ok" == "true" ]]; then
                printf '香港业务服务端口监听：已检测到\n'
            else
                cat <<EOF
[WARN] 香港业务服务端口未监听。
[WARN] REMOTE_PORT 是 Xray/sing-box/Web 服务端口，不是 EasyTier listener 端口。
[WARN] 请确保业务服务监听 0.0.0.0:${business_port} 或 EasyTier 虚拟 IP:${business_port}。
[WARN] 如果只监听 127.0.0.1，入口机转发无法访问。
EOF
            fi
            ;;
        nat-ingress)
            printf '入口机业务端口检查\n'
            if [[ "${FORWARD_ENABLED:-true}" != "true" ]]; then
                printf '业务转发：未配置。可运行 bash install.sh configure-forward。\n'
                return 0
            fi
            if command_exists ping && [[ -n "${LANDING_ET_IP:-}" ]]; then
                if ping -c 1 -W 3 "$LANDING_ET_IP" >/dev/null 2>&1; then
                    printf '落地机 EasyTier IP ping：成功\n'
                else
                    printf '[WARN] EasyTier 到落地机可能未打通，先运行 doctor/check-route，不要直接判断业务端口失败。\n'
                    printf '[WARN] 请先确认 CNIX 面板出口是否填写 LISTENER_PORT，不要填写 REMOTE_PORT。\n'
                fi
            fi
            if [[ "${FORWARD_PROTO:-both}" == "tcp" || "${FORWARD_PROTO:-both}" == "both" ]]; then
                if nc_cmd="$(detect_nc_cmd 2>/dev/null)"; then
                    if "$nc_cmd" -vz -w 3 "$LANDING_ET_IP" "$REMOTE_PORT" >/dev/null 2>&1; then
                        printf 'LANDING_ET_IP:REMOTE_PORT TCP 可达：是（%s:%s）\n' "$LANDING_ET_IP" "$REMOTE_PORT"
                    else
                        printf '[WARN] LANDING_ET_IP:REMOTE_PORT TCP 不可达：%s:%s。\n' "$LANDING_ET_IP" "$REMOTE_PORT"
                        printf '[WARN] 请检查落地机业务服务是否监听 REMOTE_PORT。\n'
                        printf '[WARN] REMOTE_PORT 不是 CNIX 面板出口端口。\n'
                        printf '[WARN] 如果 Remnawave/VLESS 监听 %s，则入口机 nftables 应转发到 %s:%s。\n' "$REMOTE_PORT" "$LANDING_ET_IP" "$REMOTE_PORT"
                    fi
                else
                    printf '[WARN] nc/ncat 不可用，跳过 TCP 业务可达性探测。\n'
                    suggest_install_nc
                fi
            fi
            if [[ "${FORWARD_PROTO:-both}" == "udp" || "${FORWARD_PROTO:-both}" == "both" ]]; then
                printf 'UDP 业务探测：跳过，UDP 可达性探测不可靠。\n'
            fi
            ;;
        nat-ingress)
            printf 'NAT-IX 入口机中转端口检查\n'
            if command_exists ping && [[ -n "${NAT_ET_IP:-}" ]]; then
                if ping -c 1 -W 3 "$NAT_ET_IP" >/dev/null 2>&1; then
                    printf 'NAT_ET_IP ping：成功\n'
                else
                    printf '[WARN] NAT_ET_IP ping 失败，请先确认 NAT IX 机器 EasyTier 已连接。\n'
                fi
            fi
            if [[ "${FORWARD_PROTO:-both}" == "tcp" || "${FORWARD_PROTO:-both}" == "both" ]]; then
                if nc_cmd="$(detect_nc_cmd 2>/dev/null)"; then
                    if "$nc_cmd" -vz -w 3 "$NAT_ET_IP" "$TRANSIT_PORT" >/dev/null 2>&1; then
                        printf 'NAT_ET_IP:TRANSIT_PORT TCP 可达：是（%s:%s）\n' "$NAT_ET_IP" "$TRANSIT_PORT"
                    else
                        printf '[WARN] NAT_ET_IP:TRANSIT_PORT TCP 不可达：%s:%s。\n' "$NAT_ET_IP" "$TRANSIT_PORT"
                    fi
                else
                    printf '[WARN] nc/ncat 不可用，跳过 TCP 中转端口探测。\n'
                    suggest_install_nc
                fi
            fi
            ;;
        nat-transit)
            printf 'NAT-IX 中转机落地端口检查\n'
            if [[ -n "${LANDING_HOST:-}" ]]; then
                if validate_ipv4 "$LANDING_HOST"; then
                    printf 'LANDING_IP：%s\n' "$LANDING_HOST"
                elif landing_ip="$(landing_ip_for_nft "$LANDING_HOST" 2>/dev/null)"; then
                    printf 'LANDING_HOST 解析：%s -> %s\n' "$LANDING_HOST" "$landing_ip"
                else
                    printf '[WARN] LANDING_HOST 解析失败：%s\n' "$LANDING_HOST"
                fi
            fi
            if [[ "${FORWARD_PROTO:-both}" == "tcp" || "${FORWARD_PROTO:-both}" == "both" ]]; then
                if nc_cmd="$(detect_nc_cmd 2>/dev/null)"; then
                    if "$nc_cmd" -vz -w 3 "$LANDING_HOST" "$LANDING_PORT" >/dev/null 2>&1; then
                        printf 'LANDING_HOST:LANDING_PORT TCP 可达：是（%s:%s）\n' "$LANDING_HOST" "$LANDING_PORT"
                    else
                        printf '[WARN] LANDING_HOST:LANDING_PORT TCP 不可达：%s:%s。\n' "$LANDING_HOST" "$LANDING_PORT"
                    fi
                else
                    printf '[WARN] nc/ncat 不可用，跳过 TCP 落地端口探测。\n'
                    suggest_install_nc
                fi
            fi
            printf 'TRANSIT_PORT 不要求 userspace 监听；它是 nftables DNAT 接收端口。\n'
            ;;
        *)
            printf '[WARN] 未知角色：%s\n' "${ROLE:-未设置}"
            ;;
    esac
}

check_business() {
    require_root "$@"
    local target="${1:-}" id resolved
    if [[ "$target" == "--all" ]]; then
        for id in $(profile_ids); do
            printf '\n===== 线路 %s =====\n' "$id"
            load_profile "$id" || { printf '[WARN] 无法读取线路：%s\n' "$id"; continue; }
            check_business_core || true
        done
        return 0
    fi
    if [[ -n "$target" || ( -d "$PROFILES_DIR" && "$(profile_count)" != "0" ) ]]; then
        if ! resolved="$(resolve_profile_id_for_cmd "$target" check-business)"; then
            return_or_exit 2 || return $?
        fi
        if ! load_profile "$resolved"; then
            print_profile_selection_hint "$resolved" check-business
            return_or_exit 2 || return $?
        fi
    else
        load_env_or_warn || return 0
    fi
    check_business_core
}

show_port_map() {
    local target="" compact="" all="false" arg
    while (($#)); do
        arg="$1"
        case "$arg" in
            "")
                ;;
            --compact)
                compact="--compact"
                ;;
            --all)
                all="true"
                ;;
            --*)
                printf '[ERROR] 未知 show-port-map 参数：%s\n' "$arg" >&2
                printf '用法：\n' >&2
                printf '  bash install.sh show-port-map [PROFILE_ID] [--compact]\n' >&2
                printf '  bash install.sh show-port-map --all [--compact]\n' >&2
                return_or_exit 2 || return $?
                ;;
            *)
                if [[ -n "$target" ]]; then
                    printf '[ERROR] show-port-map 只能指定一个 PROFILE_ID。\n' >&2
                    printf '用法：\n' >&2
                    printf '  bash install.sh show-port-map [PROFILE_ID] [--compact]\n' >&2
                    printf '  bash install.sh show-port-map --all [--compact]\n' >&2
                    return_or_exit 2 || return $?
                fi
                target="$arg"
                ;;
        esac
        shift || true
    done
    if [[ "$all" == "true" ]]; then
        if [[ -n "$target" ]]; then
            printf '[ERROR] --all 不能同时指定 PROFILE_ID：%s\n' "$target" >&2
            printf '用法：bash install.sh show-port-map --all [--compact]\n' >&2
            return_or_exit 2 || return $?
        fi
        show_port_map_all "$compact"
        return 0
    fi
    if [[ -n "$target" || -d "$PROFILES_DIR" ]]; then
        local resolved
        if ! resolved="$(resolve_profile_id_for_cmd "$target" show-port-map)"; then
            return_or_exit 2 || return $?
        fi
        if ! load_profile "$resolved"; then
            print_profile_selection_hint "$resolved" show-port-map
            return_or_exit 2 || return $?
        fi
    else
        load_env_or_warn || return 0
    fi
    if [[ "$compact" == "--compact" ]]; then
        print_port_map_compact
        return 0
    fi
    if [[ "${ROLE:-}" == "nat-ingress" || "${ROLE:-}" == "nat-transit" ]]; then
        if [[ "${NAT_DIRECTION:-ingress-listener}" == "nat-listener" ]]; then
            if [[ "${ROLE:-}" == "nat-transit" ]]; then
                cat <<EOF
线路：${PROFILE_ID:-default}（NAT IX 中转线路）

商家入口：
${NAT_PUBLIC_HOST:-商家 NAT/IX 入口地址}:${NAT_PUBLIC_PORTS:-${NAT_LISTENER_PORT:-商家分配入口端口}}
用途：公网入口机通过 EasyTier 连接到这里。

虚拟网：
NAT IX 虚拟 IP：${NAT_ET_IP:-未配置}
公网入口机虚拟 IP：${INGRESS_ET_IP:-未配置}

转发规则：
$(format_rules_for_port_map "${PROFILE_ID:-default}")
说明：虚拟网中转端口只在 EasyTier 虚拟网内部使用，不是公网端口，不需要商家放行。

客户端连接：
公网入口机导入接入码后，客户端连接：公网入口机地址:客户端入口端口（公网入口机侧指定）
EOF
            else
                cat <<EOF
线路：${PROFILE_ID:-default}（公网入口线路）

客户端连接：
公网入口机地址:$(rule_client_port_display)

连接 NAT IX：
${NAT_PUBLIC_HOST:-商家 NAT/IX 入口地址}:${NAT_PUBLIC_PORTS:-${NAT_LISTENER_PORT:-商家分配入口端口}}

转发规则：
$(format_rules_for_port_map "${PROFILE_ID:-default}")

说明：虚拟网中转端口只在 EasyTier 虚拟网内部使用，不是公网端口，不是商家入口端口。
EOF
            fi
            return 0
        fi
        cat <<EOF
线路：${PROFILE_ID:-default}（兼容旧模式，enabled=${ENABLED:-true}）

客户端
-> ${INGRESS_PUBLIC_HOST:-公网入口机公网 IP}:${LOCAL_PORT:-客户端入口端口}
-> 公网入口机 nftables
-> NAT IX 虚拟 IP:虚拟网中转端口
-> EasyTier 隧道
-> NAT IX 机器 nftables
-> 落地机地址:落地业务端口

转发规则：
$(format_rules_for_port_map "${PROFILE_ID:-default}")

注意：
  NAT IX 机器不需要安装代理服务，只做 nftables 中转。
  虚拟网中转端口只在 EasyTier 虚拟网内部使用，不是公网端口，不是商家入口端口。
  落地机地址如果是域名，应用 nftables 时会解析为 LANDING_IP；DDNS 默认定时刷新域名解析（bash install.sh ddns-status 查看状态）。
EOF
        return 0
    fi
    local local_display cnix_display listener_display remote_display
    local_display="${LOCAL_PORT:-LOCAL_PORT}"
    cnix_display="${CNIX_ENTRY_HOST:-CNIX_ENTRY_HOST}:${CNIX_ENTRY_PORT:-CNIX_ENTRY_PORT}"
    listener_display="落地 VPS 公网 IP:${LISTENER_PORT:-${ET_LISTENER_PORT:-${CODE_LISTENER_PORT:-LISTENER_PORT}}}"
    remote_display="${LANDING_ET_IP:-10.144.144.2}:${REMOTE_PORT:-${SERVICE_PORT:-REMOTE_PORT}}"
    cat <<EOF
Profile：${PROFILE_ID:-default}（${ROLE:-未设置}，enabled=${ENABLED:-true}）

四端口映射：

1. LOCAL_PORT / 客户端入口端口
   用途：客户端连接入口 VPS。
   示例：入口 VPS 公网 IP:${local_display}

2. CNIX_ENTRY_PORT / CNIX 商家入口端口
   用途：入口机 EasyTier peer 连接 CNIX 商家入口。
   示例：${cnix_display}

3. LISTENER_PORT / 落地机 EasyTier listener 端口
   用途：填写到 CNIX 面板出口。
   示例：${listener_display}
   注意：这相当于 WG ListenPort。

4. REMOTE_PORT / 落地机业务端口
   用途：Remnawave / VLESS / Xray / sing-box 的真实服务端口。
   示例：${remote_display}
   注意：不要把这个端口填到 CNIX 面板出口。

当前已保存值：
EOF
    case "${ROLE:-}" in
        nat-transit)
            printf '  LISTENER_PORT=%s\n' "${LISTENER_PORT:-${ET_LISTENER_PORT:-未配置}}"
            printf '  REMOTE_PORT=%s\n' "${REMOTE_PORT:-${SERVICE_PORT:-未配置}}"
            ;;
        nat-ingress)
            printf '  LOCAL_PORT=%s\n' "${LOCAL_PORT:-未配置}"
            printf '  CNIX_ENTRY_PORT=%s\n' "${CNIX_ENTRY_PORT:-未配置}"
            printf '  LISTENER_PORT=%s\n' "${CODE_LISTENER_PORT:-接入码未保存该值}"
            printf '  REMOTE_PORT=%s\n' "${REMOTE_PORT:-未配置}"
            ;;
        *)
            printf '  当前角色未知：%s\n' "${ROLE:-未设置}"
            ;;
    esac
}

show_port_map_all() {
    require_root "$@"
    local compact="${1:-}" id
    for id in $(profile_ids); do
        printf '\n===== 线路 %s =====\n' "$id"
        show_port_map "$id" "$compact"
    done
}

show_port_map_compact() {
    show_port_map --compact "${1:-}"
}

check_route() {
    local target="${1:-}" et_ip route_output id
    if [[ "$target" == "--all" ]]; then
        for id in $(profile_ids); do
            printf '\n===== 线路 %s =====\n' "$id"
            check_route "$id" || true
        done
        return 0
    fi
    if [[ -n "$target" || ( -d "$PROFILES_DIR" && "$(profile_count)" != "0" ) ]]; then
        load_profile_or_die "$(resolve_profile_id "$target")"
    else
        load_env_or_warn || return 0
    fi
    et_ip="$(et_ip_addr)"

    printf 'EasyTier 路由检查\n'
    printf '当前角色：%s\n' "$ROLE"
    printf '配置的 ET_IPV4：%s\n' "$ET_IPV4"

    if command_exists ip; then
        if ip addr show 2>/dev/null | grep -Fq "$et_ip"; then
            printf 'ip addr 中是否存在 ET IP：是（%s）\n' "$et_ip"
            ip addr show 2>/dev/null | grep -F "$et_ip" || true
        else
            printf '[WARN] ip addr 中未找到 ET IP：%s。\n' "$et_ip"
        fi

        if [[ "$ROLE" == "nat-ingress" && -n "${LANDING_ET_IP:-}" ]]; then
            printf '到落地机 EasyTier IP 的路由：\n'
            ip route get "$LANDING_ET_IP" 2>/dev/null || printf '[WARN] ip route get 未找到到 %s 的路由。\n' "$LANDING_ET_IP"
            route_output="$(ip route 2>/dev/null | grep -F "$LANDING_ET_IP" || true)"
            [[ -n "$route_output" ]] && printf '%s\n' "$route_output"
        else
            printf '请在入口机上尝试：ping %s\n' "$et_ip"
        fi
    else
        printf '[WARN] 未找到 ip 命令，无法检查地址和路由。\n'
    fi

    if [[ "$ROLE" == "nat-ingress" ]]; then
        if [[ "${FORWARD_ENABLED:-true}" != "true" ]]; then
            printf '业务转发未配置；如需检查业务路由，请先运行 bash install.sh configure-forward。\n'
            return 0
        fi
        if command_exists ping; then
            if ping -c 1 -W 3 "$LANDING_ET_IP" >/dev/null 2>&1; then
                printf 'ping 落地机 EasyTier IP：成功\n'
            else
                printf '[WARN] ping 落地机 EasyTier IP 失败。这只是排障线索，不代表一定不可用。\n'
            fi
        fi
    fi
}

self_test() {
    local passed=0 warning=0 failed=0 output rc

    self_show_config() {
        print_config_summary || printf '[WARN] show-config 无法读取已保存配置。\n'
        return 0
    }

    run_self_step() {
        local name="$1"
        shift
        printf '\n===== %s =====\n' "$name"
        set +e
        output="$("$@" 2>&1)"
        rc=$?
        set -e
        printf '%s\n' "$output"
        if [[ "$rc" -ne 0 ]]; then
            failed=$((failed + 1))
            printf '[自检] %s：失败（退出码 %s）\n' "$name" "$rc"
        elif grep -q '\[WARN\]' <<<"$output"; then
            warning=$((warning + 1))
            printf '[自检] %s：有警告\n' "$name"
        else
            passed=$((passed + 1))
            printf '[自检] %s：通过\n' "$name"
        fi
    }

    run_self_step "show-config" self_show_config
    run_self_step "status" status
    run_self_step "doctor" doctor
    run_self_step "check-port" check_port
    run_self_step "check-business" check_business
    run_self_step "check-route" check_route
    run_self_step "show-port-map" show_port_map

    printf '\n自检完成：\n'
    printf '%s\n' "- 通过：${passed}"
    printf '%s\n' "- 警告：${warning}"
    printf '%s\n' "- 失败：${failed}"
    return 0
}

uninstall() {
    require_root "$@"
    local remove_et answer

    if command_exists systemctl; then
        systemctl stop "$DDNS_TIMER_NAME" "$DDNS_SERVICE_NAME" "$MONITOR_TIMER_NAME" "$MONITOR_SERVICE_NAME" >/dev/null 2>&1 || true
        systemctl disable "$DDNS_TIMER_NAME" "$MONITOR_TIMER_NAME" >/dev/null 2>&1 || true
        stop_disable_profile_services
        systemctl stop "$SERVICE_NAME" >/dev/null 2>&1 || true
        cleanup_own_service_processes
        systemctl disable "$SERVICE_NAME" >/dev/null 2>&1 || true
        systemctl reset-failed "$SERVICE_NAME" >/dev/null 2>&1 || true
    else
        log_warn "systemctl 不可用，跳过服务停止和禁用。"
    fi

    delete_nft_runtime_and_file
    rm -f -- "$SYSTEMD_SERVICE" "$PROFILE_SERVICE_TEMPLATE" "$DDNS_SERVICE_FILE" "$DDNS_TIMER_FILE" "$MONITOR_SERVICE_FILE" "$MONITOR_TIMER_FILE" "$ENV_FILE" "$LANDING_CODE_FILE" "$WRAPPER_FILE"
    rm -f -- "$SYSCTL_FILE"
    remove_ix_cli_shortcut
    log_ok "已删除项目 service、wrapper、配置、接入码和 sysctl 文件（如果存在）。"

    rmdir "$CONFIG_DIR" >/dev/null 2>&1 || true
    rmdir "$LIBEXEC_DIR" >/dev/null 2>&1 || true

    remove_et="false"
    if [[ "${IXTF_SKIP_EASYTIER_DELETE_PROMPT:-}" != "1" ]] && is_interactive_input && [[ -e "$EASYTIER_TARGET" ]]; then
        answer="$(prompt_yes_no "是否删除 /usr/local/bin/easytier-core" "false")" || answer="false"
        remove_et="$answer"
    fi
    if [[ "$remove_et" == "true" ]]; then
        rm -f -- "$EASYTIER_TARGET"
        log_ok "已删除：${EASYTIER_TARGET}"
    elif [[ "${IXTF_SKIP_EASYTIER_DELETE_PROMPT:-}" != "1" && -e "$EASYTIER_TARGET" ]]; then
        log_info "保留 easytier-core：${EASYTIER_TARGET}"
    fi

    if command_exists systemctl; then
        systemctl daemon-reload
    fi

    log_ok "卸载完成，备份仍保留：${BACKUP_DIR}"
}

safe_remove_project_dir() {
    local path="$1"
    case "$path" in
        "$CONFIG_DIR"|"$BACKUP_DIR"|"$LIBEXEC_DIR")
            rm -rf -- "$path"
            ;;
        *)
            die_user "拒绝删除非本项目路径：${path}"
            ;;
    esac
}

purge() {
    require_root "$@"
    require_tty

    local confirm answer remove_et remove_script script_path
    cat >&2 <<'EOF'
完全清理将删除：
* systemd 服务
* wrapper
* 配置目录
* 线路配置
* 接入码
* state/history
* nftables 项目表
* sysctl 文件
* 备份目录

EOF
    printf '请输入 DELETE 继续：' >&2
    IFS= read -r confirm
    confirm="$(trim_space "${confirm%$'\r'}")"
    if [[ "$confirm" != "DELETE" ]]; then
        log_warn "已取消完全清理。请输入大写 DELETE 才会继续。"
        return 0
    fi

    remove_et="false"
    if [[ -e "$EASYTIER_TARGET" ]]; then
        answer="$(prompt_yes_no "是否删除 /usr/local/bin/easytier-core" "false")" || answer="false"
        remove_et="$answer"
    fi
    script_path="${BASH_SOURCE[0]:-$0}"
    if [[ "$script_path" != /* ]]; then
        script_path="$(pwd -P)/$script_path"
    fi
    cat >&2 <<EOF
${script_path} 是用户手动下载或执行的安装脚本，不属于 systemd 服务或项目运行文件。
完全清理默认不会删除你手动下载的 install.sh，除非你确认删除。
EOF
    remove_script="$(prompt_yes_no "是否删除当前安装脚本 ${script_path}" "false")" || remove_script="false"

    IXTF_SKIP_EASYTIER_DELETE_PROMPT=1 uninstall
    if [[ "$remove_et" == "true" ]]; then
        rm -f -- "$EASYTIER_TARGET"
        log_ok "已删除 easytier-core：${EASYTIER_TARGET}"
    elif [[ -e "$EASYTIER_TARGET" ]]; then
        log_info "已保留 easytier-core：${EASYTIER_TARGET}"
    else
        log_info "未发现 easytier-core：${EASYTIER_TARGET}"
    fi
    rm -f -- "$NFT_FILE" "$SYSCTL_FILE" "$SYSTEMD_SERVICE" "$PROFILE_SERVICE_TEMPLATE" "$MONITOR_SERVICE_FILE" "$MONITOR_TIMER_FILE" "$WRAPPER_FILE" "$ENV_FILE" "$LANDING_CODE_FILE"
    safe_remove_project_dir "$CONFIG_DIR"
    safe_remove_project_dir "$BACKUP_DIR"
    safe_remove_project_dir "$LIBEXEC_DIR"

    rmdir "$LIBEXEC_DIR" >/dev/null 2>&1 || true

    if command_exists systemctl; then
        systemctl daemon-reload
    fi
    if [[ "$remove_script" == "true" ]]; then
        if [[ -f "$script_path" && "$script_path" != /dev/fd/* && "$script_path" != /proc/* ]]; then
            rm -f -- "$script_path"
            log_ok "已删除当前安装脚本：${script_path}"
        else
            log_info "当前脚本不是普通文件，跳过自删除。"
        fi
    fi

    cat <<EOF
完全清理完成：
  已删除配置目录：${CONFIG_DIR}
  已删除执行目录：${LIBEXEC_DIR}
  已删除备份目录：${BACKUP_DIR}
  已删除 nftables 文件：${NFT_FILE}
  已删除 sysctl 文件：${SYSCTL_FILE}
  easytier-core：$([[ "$remove_et" == "true" ]] && printf '已删除' || printf '已保留')
  install.sh：$([[ "$remove_script" == "true" ]] && printf '已按确认处理' || printf '已保留')
EOF
}

run_advanced_menu_action() {
    local choice
    choice="$(normalize_menu_choice "$1")"
    [[ -z "$choice" ]] && return 0
    case "$choice" in
        1) list_profiles ;;
        2) show_profile_from_menu ;;
        3) status_all ;;
        4) show_port_map_all ;;
        5) show_nft ;;
        6) export_diagnostic ;;
        7) install_nc_tool ;;
        8) uninstall ;;
        9) purge ;;
        10) self_check ;;
        11) cleanup_history ;;
        12) cleanup_state ;;
        13) show_monitor_menu ;;
        0) return 10 ;;
        *) log_warn "未知选项，请重新选择。"; return 0 ;;
    esac
}

show_advanced_menu() {
    local choice rc
    while true; do
        cat >&2 <<'MENU'

ix-transit-fabric 高级维护

  1) 线路列表
  2) 查看指定线路配置
  3) 查看所有状态
  4) 查看端口地图
  5) 查看 nftables 项目表
  6) 导出脱敏诊断报告
  7) 安装诊断工具
  8) 卸载服务（保留配置备份）
  9) 完全清理（删除配置、服务和备份）
 10) 最终自检
 11) 清理 history
 12) 清理 state
 13) 监控 / 通知 / DDNS
  0) 返回主菜单
MENU
        printf '请选择：' >&2
        IFS= read -r choice || { printf '\n' >&2; return 0; }
        choice="$(normalize_menu_choice "$choice")"
        [[ -z "$choice" ]] && continue

        set +e
        trap - ERR
        export IXTF_IN_MENU=1
        export IXTF_ALLOW_INTERACTIVE=1
        ( trap - ERR; set +e; run_advanced_menu_action "$choice" )
        rc=$?
        trap 'on_error $LINENO' ERR
        set -e

        [[ "$rc" -eq 10 ]] && return 0
        if [[ "$rc" -ne 0 ]]; then
            log_error "菜单操作失败（退出码 ${rc}），已返回菜单。"
        fi
    done
}

manage_profiles_menu() {
    local choice profile_id
    cat >&2 <<'MENU'

线路维护

  1) 启用线路
  2) 禁用线路
  3) 删除线路
  0) 返回
MENU
    printf '请选择：' >&2
    IFS= read -r choice || return 0
    choice="$(normalize_menu_choice "$choice")"
    [[ -z "$choice" ]] && return 0
    [[ "$choice" == "0" ]] && return 0
    printf '请输入线路 ID：' >&2
    IFS= read -r profile_id || return 1
    profile_id="$(normalize_menu_choice "$profile_id")"
    case "$choice" in
        1) enable_profile "$profile_id" ;;
        2) disable_profile "$profile_id" ;;
        3) delete_profile "$profile_id" ;;
        *) log_warn "未知选项。" ;;
    esac
}

run_nat_mode_b_menu() {
    local choice
    cat >&2 <<'MENU'

推荐模式：NAT IX 监听 / 公网入口机连接 NAT IX

  1) NAT IX 机器：生成接入码
  2) 公网入口机：导入 NAT IX 接入码
  3) 返回
MENU
    printf '请选择：' >&2
    IFS= read -r choice || return 1
    choice="$(normalize_menu_choice "$choice")"
    [[ -z "$choice" ]] && return 0
    case "$choice" in
        1) add_nat_listener_profile ;;
        2) add_nat_ingress_from_listener_code ;;
        3|0) return 0 ;;
        *) log_warn "未知选项，请重新选择。"; return 0 ;;
    esac
}

show_nat_advanced_explanation() {
    cat <<'EOF'
NAT-IX 高级说明

推荐模式：
  NAT IX 机器监听，公网入口机连接 NAT IX。
  适合商家给了 NAT/IX 入口 IP:端口。

端口命名：
  客户端入口端口：最终客户端连接公网入口机的端口。
  商家 NAT/IX 入口地址和商家分配入口端口：商家给 NAT IX 机器使用的入站地址和端口。
  虚拟网中转端口：只在 EasyTier 虚拟网内部使用，不是公网端口，不是商家入口端口。
  落地机地址和落地业务端口：NAT IX 机器最终转发到的真实服务。

技术字段只在 show-config、导出配置、脱敏诊断和高级排障中显示。
EOF
}

run_nat_menu_action() {
    local choice profile_id
    choice="$(normalize_menu_choice "$1")"
    [[ -z "$choice" ]] && return 0
    case "$choice" in
        1) add_nat_listener_profile ;;
        2) add_nat_ingress_from_listener_code ;;
        3) show_port_map --all --compact ;;
        4) health_profile_from_menu ;;
        5) latency_report_from_menu ;;
        6) show_nat_advanced_explanation ;;
        7) return 10 ;;
        0) return 10 ;;
        *) log_warn "未知选项，请重新选择。"; return 0 ;;
    esac
}

show_nat_menu() {
    local choice rc
    while true; do
        cat >&2 <<'MENU'

NAT-IX 中转模式

正式流程：NAT IX 机器监听，公网入口机连接 NAT IX。适合商家给了 NAT/IX 入口 IP:端口。

  1) 创建 NAT IX 中转线路
  2) 公网入口机导入接入码
  3) 查看端口地图
  4) 健康检查
  5) 延迟诊断
  6) 高级说明
  7) 返回
MENU
        printf '请选择：' >&2
        IFS= read -r choice || { printf '\n' >&2; return 0; }
        choice="$(normalize_menu_choice "$choice")"
        [[ -z "$choice" ]] && continue

        set +e
        trap - ERR
        export IXTF_IN_MENU=1
        export IXTF_ALLOW_INTERACTIVE=1
        ( trap - ERR; set +e; run_nat_menu_action "$choice" )
        rc=$?
        trap 'on_error $LINENO' ERR
        set -e

        [[ "$rc" -eq 10 ]] && return 0
        if [[ "$rc" -ne 0 ]]; then
            log_error "菜单操作失败（退出码 ${rc}），已返回菜单。"
        fi
    done
}

run_health_menu_action() {
    local choice profile_id group target
    choice="$(normalize_menu_choice "$1")"
    [[ -z "$choice" ]] && return 0
    case "$choice" in
        1) health_report ;;
        2)
            printf '请输入 PROFILE_ID：' >&2
            IFS= read -r profile_id || return 1
            check_line "$profile_id"
            ;;
        3) health_all ;;
        4)
            printf '请输入 LINE_GROUP：' >&2
            IFS= read -r group || return 1
            show_group "$group"
            ;;
        5)
            printf '请输入 LINE_GROUP：' >&2
            IFS= read -r group || return 1
            primary_backup_check "$group"
            ;;
        6)
            printf '请输入 LINE_GROUP：' >&2
            IFS= read -r group || return 1
            primary_backup_runbook "$group"
            ;;
        7) primary_backup_summary ;;
        8)
            printf '请输入 LINE_GROUP：' >&2
            IFS= read -r group || return 1
            printf '请输入目标 PROFILE_ID：' >&2
            IFS= read -r target || return 1
            switch_dry_run "$group" "$target"
            ;;
        9)
            printf '请输入 LINE_GROUP：' >&2
            IFS= read -r group || return 1
            printf '请输入目标 PROFILE_ID：' >&2
            IFS= read -r target || return 1
            switch_line "$group" "$target"
            ;;
        10) switch_history ;;
        11) switch_rollback_last ;;
        12) verify_nft_profiles ;;
        0) return 10 ;;
        *) log_warn "未知选项，请重新选择。"; return 0 ;;
    esac
}

run_monitor_menu_action() {
    local choice profile_id group minutes
    choice="$(normalize_menu_choice "$1")"
    [[ -z "$choice" ]] && return 0
    case "$choice" in
        1) monitor_run_once ;;
        2) monitor_enable ;;
        3) monitor_disable ;;
        4) monitor_status ;;
        5) monitor_logs ;;
        6) notify_config ;;
        7) notify_test ;;
        8) notify_enable ;;
        9) notify_disable ;;
        10) notify_status ;;
        11) health_history ;;
        12) traffic_status ;;
        13) traffic_report ;;
        14) traffic_reset_all ;;
        15)
            if ddns_user_disabled; then
                log_warn "DDNS 定时刷新已禁用；本次为手动刷新。"
            fi
            ddns_refresh_all
            ;;
        16) ddns_enable ;;
        17) ddns_disable ;;
        18) ddns_status ;;
        0) return 10 ;;
        *) log_warn "未知选项，请重新选择。"; return 0 ;;
    esac
}

show_monitor_menu() {
    local choice rc
    while true; do
        cat >&2 <<'MENU'

监控 / 通知 / 流量统计 / DDNS

  1) 立即运行一次监控
  2) 启用定时健康检查
  3) 禁用定时健康检查
  4) 查看监控状态
  5) 查看监控日志
  6) 配置通知
  7) 测试通知
  8) 启用通知
  9) 禁用通知
 10) 查看通知状态
 11) 查看健康历史
 12) 查看流量统计
 13) 查看流量报告
 14) 重置流量计数
 15) 立即刷新 DDNS（手动）
 16) 启用 DDNS 定时刷新
 17) 禁用 DDNS 定时刷新
 18) 查看 DDNS 状态
  0) 返回
MENU
        printf '请选择：' >&2
        IFS= read -r choice || { printf '\n' >&2; return 0; }
        choice="$(normalize_menu_choice "$choice")"
        [[ -z "$choice" ]] && continue

        set +e
        trap - ERR
        export IXTF_IN_MENU=1
        export IXTF_ALLOW_INTERACTIVE=1
        ( trap - ERR; set +e; run_monitor_menu_action "$choice" )
        rc=$?
        trap 'on_error $LINENO' ERR
        set -e

        [[ "$rc" -eq 10 ]] && return 0
        if [[ "$rc" -ne 0 ]]; then
            log_error "菜单操作失败（退出码 ${rc}），已返回菜单。"
        fi
    done
}

show_health_menu() {
    local choice rc
    while true; do
        cat >&2 <<'MENU'

健康检查 / 主备切换

  1) 查看健康报告
  2) 检查指定线路
  3) 检查全部线路
  4) 查看线路组
  5) 主备组完整性检查
  6) 主备组操作手册
  7) 主备组汇总
  8) 切换预演 dry-run
  9) 手动切换线路
  10) 查看切换历史
  11) 最近一次切换回滚辅助
  12) 校验 nftables 与 Profile 一致性
  0) 返回
MENU
        printf '请选择：' >&2
        IFS= read -r choice || { printf '\n' >&2; return 0; }
        choice="$(normalize_menu_choice "$choice")"
        [[ -z "$choice" ]] && continue

        set +e
        trap - ERR
        export IXTF_IN_MENU=1
        export IXTF_ALLOW_INTERACTIVE=1
        ( trap - ERR; set +e; run_health_menu_action "$choice" )
        rc=$?
        trap 'on_error $LINENO' ERR
        set -e

        [[ "$rc" -eq 10 ]] && return 0
        if [[ "$rc" -ne 0 ]]; then
            log_error "菜单操作失败（退出码 ${rc}），已返回菜单。"
        fi
    done
}

run_rule_menu_action() {
    local choice profile_id="$2"
    choice="$(normalize_menu_choice "$1")"
    [[ -z "$choice" ]] && return 0
    case "$choice" in
        1) menu_add_rule "$profile_id" ;;
        2) menu_edit_rule "$profile_id" ;;
        3) menu_enable_rule "$profile_id" ;;
        4) menu_disable_rule "$profile_id" ;;
        5) menu_delete_rule "$profile_id" ;;
        6) menu_refresh_rule_code "$profile_id" ;;
        7) menu_apply_rules "$profile_id" ;;
        9|0|"") return 10 ;;
        *) log_warn "未知选项，请重新选择。"; return 0 ;;
    esac
}

show_rule_menu() {
    local choice rc profile_id
    if ! profile_id="$(select_profile_for_rule_menu)"; then
        return 0
    fi
    while true; do
        printf '\n转发规则管理\n'
        print_rule_menu_header "$profile_id"
        print_rule_menu_rules "$profile_id"
        cat >&2 <<'MENU'

操作：

  1) 新增转发规则
  2) 修改转发规则
  3) 启用转发规则
  4) 停止转发规则
  5) 删除转发规则
  6) 刷新接入码
  7) 重新应用转发规则
  8) 切换线路
  9) 返回主菜单
MENU
        printf '请选择：' >&2
        IFS= read -r choice || { printf '\n' >&2; return 0; }
        choice="$(normalize_menu_choice "$choice")"
        [[ -z "$choice" ]] && continue

        if [[ "$choice" == "8" ]]; then
            if profile_id="$(select_profile_for_rule_menu)"; then
                continue
            fi
            return 0
        fi

        set +e
        trap - ERR
        export IXTF_IN_MENU=1
        export IXTF_ALLOW_INTERACTIVE=1
        ( trap - ERR; set +e; run_rule_menu_action "$choice" "$profile_id" )
        rc=$?
        trap 'on_error $LINENO' ERR
        set -e

        [[ "$rc" -eq 10 ]] && return 0
        if [[ "$rc" -ne 0 ]]; then
            log_error "菜单操作失败（退出码 ${rc}），已返回菜单。"
        fi
    done
}

run_menu_action() {
    local choice profile_id
    choice="$(normalize_menu_choice "$1")"
    [[ -z "$choice" ]] && return 0
    case "$choice" in
        1) add_nat_listener_profile ;;
        2) add_nat_ingress_from_listener_code ;;
        3) show_rule_menu ;;
        4) status_all ;;
        5) health_profile_from_menu ;;
        6) latency_report_from_menu ;;
        7) traffic_report ;;
        8) install_easytier ;;
        9) show_advanced_menu ;;
        10) return 10 ;;
        0) return 10 ;;
        *) log_warn "未知选项，请重新选择。"; return 0 ;;
    esac
}

show_menu() {
    require_tty --menu
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        ensure_ix_cli_shortcut || true
    fi
    local choice rc
    while true; do
        cat >&2 <<'MENU'

ix-transit-fabric 管理菜单

  1) 创建 NAT IX 中转线路
  2) 公网入口机导入接入码
  3) 转发规则管理
  4) 线路列表 / 状态
  5) 健康检查
  6) 延迟诊断
  7) 流量统计
  8) 安装 / 更新 EasyTier
  9) 高级维护
 10) 退出
MENU
        printf '请选择：' >&2
        IFS= read -r choice || { printf '\n' >&2; return 0; }
        choice="$(normalize_menu_choice "$choice")"
        [[ -z "$choice" ]] && continue

        set +e
        trap - ERR
        export IXTF_IN_MENU=1
        export IXTF_ALLOW_INTERACTIVE=1
        ( trap - ERR; set +e; run_menu_action "$choice" )
        rc=$?
        trap 'on_error $LINENO' ERR
        set -e

        [[ "$rc" -eq 10 ]] && return 0
        if [[ "$rc" -ne 0 ]]; then
            log_error "菜单操作失败（退出码 ${rc}），已返回菜单。"
        fi
    done
}

main() {
    local args=()
    local arg cmd

    unset IXTF_IN_MENU IXTF_ALLOW_INTERACTIVE

    while (($#)); do
        arg="$1"
        case "$arg" in
            --auto-install-easytier)
                AUTO_INSTALL_EASYTIER="true"
                shift
                ;;
            --env-file)
                shift
                [[ $# -gt 0 ]] || die_user "--env-file 后面必须跟 env 文件路径。"
                INSTALL_ENV_FILE_PATH="$1"
                shift
                ;;
            --code)
                shift
                [[ $# -gt 0 ]] || die_user "--code 后面必须跟 IXTF1 接入码。"
                CODE_ARG="$1"
                shift
                ;;
            --code-file)
                shift
                [[ $# -gt 0 ]] || die_user "--code-file 后面必须跟接入码文件路径。"
                CODE_FILE_ARG="$1"
                shift
                ;;
            --debug)
                IXTF_DEBUG="true"
                export IXTF_DEBUG
                shift
                ;;
            *)
                args+=("$arg")
                shift
                ;;
        esac
    done

    cmd="${args[0]:-}"
    case "$cmd" in
        --help|-h|help)
            usage
            ;;
        --version|version)
            printf '%s %s\n' "$APP_NAME" "$SCRIPT_VERSION"
            ;;
        --menu|menu|ix|IX)
            show_menu
            ;;
        install-ix-cli)
            install_ix_cli
            ;;
        install-easytier)
            install_easytier
            ;;
        update-easytier)
            update_easytier
            ;;
        install-netcat)
            install_nc_tool
            ;;
        install-diagnostics-tools)
            install_nc_tool
            ;;
        preflight)
            preflight_check "${args[1]:-all}"
            ;;
        list-profiles)
            list_profiles
            ;;
        list-rules|list-forwards)
            list_rules "${args[1]:-}"
            ;;
        show-rule|show-forward)
            show_rule "${args[1]:-}" "${args[2]:-}"
            ;;
        add-rule|add-forward)
            add_rule "${args[1]:-}"
            ;;
        edit-rule|edit-forward)
            edit_rule "${args[1]:-}" "${args[2]:-}"
            ;;
        enable-rule|enable-forward)
            enable_rule "${args[1]:-}" "${args[2]:-}"
            ;;
        disable-rule|disable-forward)
            disable_rule "${args[1]:-}" "${args[2]:-}"
            ;;
        delete-rule|delete-forward)
            delete_rule "${args[1]:-}" "${args[2]:-}"
            ;;
        apply-rules)
            apply_rules "${args[1]:-}"
            ;;
        show-profile)
            show_profile "${args[1]:-}"
            ;;
        add-nat-ingress-profile)
            add_nat_ingress_profile
            ;;
        add-nat-transit-profile-from-code)
            add_nat_transit_profile_from_code
            ;;
        add-nat-listener-profile)
            add_nat_listener_profile
            ;;
        add-nat-ingress-from-listener-code)
            add_nat_ingress_from_listener_code
            ;;
        enable-profile)
            enable_profile "${args[1]:-}"
            ;;
        disable-profile)
            disable_profile "${args[1]:-}"
            ;;
        delete-profile)
            delete_profile "${args[1]:-}"
            ;;
        rename-profile)
            rename_profile "${args[1]:-}" "${args[2]:-}"
            ;;
        start-profile)
            start_profile "${args[1]:-}"
            ;;
        stop-profile)
            stop_profile "${args[1]:-}"
            ;;
        restart-profile)
            restart_profile "${args[1]:-}"
            ;;
        set-easytier-protocol)
            set_easytier_protocol "${args[1]:-}"
            ;;
        status-profile)
            status_profile "${args[1]:-}"
            ;;
        logs-profile)
            logs_profile "${args[1]:-}"
            ;;
        status-all)
            status_all "${args[1]:-}"
            ;;
        doctor-all)
            doctor_all
            ;;
        check-line)
            check_line "${args[1]:-}"
            ;;
        health)
            health_profile "${args[1]:-}"
            ;;
        nat-health)
            health_profile "${args[1]:-}"
            ;;
        health-all)
            health_all
            ;;
        health-report)
            health_report "${args[1]:-}" "${args[2]:-}"
            ;;
        export-health-report)
            export_health_report "${args[1]:-}" "${args[2]:-}"
            ;;
        set-health)
            set_health "${args[@]:1}"
            ;;
        list-groups)
            list_groups
            ;;
        show-group)
            show_group "${args[1]:-}"
            ;;
        validate-primary-backup)
            validate_primary_backup "${args[1]:-}"
            ;;
        primary-backup-check)
            primary_backup_check "${args[1]:-}"
            ;;
        primary-backup-runbook)
            primary_backup_runbook "${args[1]:-}"
            ;;
        primary-backup-summary)
            primary_backup_summary
            ;;
        switch-dry-run)
            switch_dry_run "${args[1]:-}" "${args[2]:-}"
            ;;
        switch-line)
            switch_line "${args[1]:-}" "${args[2]:-}"
            ;;
        switch-to)
            switch_to "${args[1]:-}"
            ;;
        switch-history)
            switch_history "${args[@]:1}"
            ;;
        clear-switch-history)
            clear_switch_history
            ;;
        switch-rollback-last)
            switch_rollback_last
            ;;
        monitor-run-once)
            monitor_run_once "${args[@]:1}"
            ;;
        monitor-enable)
            monitor_enable
            ;;
        monitor-disable)
            monitor_disable
            ;;
        monitor-status)
            monitor_status
            ;;
        ddns-refresh)
            if [[ "${args[1]:-}" == "--timer" ]]; then
                ddns_run_once
            else
                if ddns_user_disabled; then
                    log_warn "DDNS 定时刷新已禁用；本次为手动刷新。"
                fi
                ddns_refresh_all
            fi
            ;;
        ddns-status)
            ddns_status
            ;;
        ddns-enable)
            ddns_enable
            ;;
        ddns-disable)
            ddns_disable
            ;;
        monitor-logs)
            monitor_logs
            ;;
        monitor-config)
            monitor_config
            ;;
        monitor-set-interval)
            monitor_set_interval "${args[1]:-}"
            ;;
        health-history)
            health_history "${args[@]:1}"
            ;;
        clear-health-history)
            clear_health_history
            ;;
        notify-config)
            notify_config
            ;;
        notify-test)
            notify_test
            ;;
        notify-enable)
            notify_enable
            ;;
        notify-disable)
            notify_disable
            ;;
        notify-status)
            notify_status
            ;;
        traffic-status)
            traffic_status "${args[1]:-}"
            ;;
        traffic-report)
            traffic_report "${args[@]:1}"
            ;;
        latency-report)
            latency_report "${args[@]:1}"
            ;;
        nat-latency)
            nat_latency "${args[@]:1}"
            ;;
        latency-all)
            latency_all "${args[@]:1}"
            ;;
        traffic-reset)
            traffic_reset "${args[1]:-}"
            ;;
        traffic-reset-all)
            traffic_reset_all
            ;;
        set-line-group)
            set_line_group "${args[1]:-}" "${args[2]:-}"
            ;;
        set-line-priority)
            set_line_priority "${args[1]:-}" "${args[2]:-}"
            ;;
        set-primary)
            set_primary "${args[1]:-}"
            ;;
        set-backup)
            set_backup "${args[1]:-}"
            ;;
        set-standalone)
            set_standalone "${args[1]:-}"
            ;;
        set-forward)
            set_forward "${args[1]:-}" "${args[2]:-}"
            ;;
        restart-all)
            restart_all
            ;;
        apply-nft-all|apply-all-forwards)
            apply_nft_all
            ;;
        verify-nft-profiles)
            verify_nft_profiles
            ;;
        migrate-single-profile)
            migrate_single_profile
            ;;
        refresh-code)
            refresh_code "${args[1]:-}"
            ;;
        refresh-nat-code)
            refresh_nat_code "${args[1]:-}"
            ;;
        status)
            status
            ;;
        show-config)
            show_config "${args[1]:-}"
            ;;
        doctor)
            doctor "${args[1]:-}"
            ;;
        logs)
            logs
            ;;
        check-port)
            check_port "${args[1]:-}"
            ;;
        check-business)
            check_business "${args[1]:-}"
            ;;
        check-route)
            check_route "${args[1]:-}"
            ;;
        show-port-map)
            show_port_map "${args[@]:1}"
            ;;
        nat-port-map)
            show_port_map "${args[@]:1}"
            ;;
        nat-status)
            status_all "${args[1]:-}"
            ;;
        show-port-map-compact)
            show_port_map_compact "${args[1]:-}"
            ;;
        self-check)
            self_check
            ;;
        export-diagnostic)
            export_diagnostic
            ;;
        cleanup-history)
            cleanup_history "${args[@]:1}"
            ;;
        cleanup-state)
            cleanup_state
            ;;
        self-test)
            self_test
            ;;
        check-wrapper)
            check_wrapper
            ;;
        show-easytier-command)
            show_easytier_command "${args[1]:-}"
            ;;
        show-easytier-status)
            show_easytier_status "${args[1]:-}"
            ;;
        diagnose)
            diagnose "${args[1]:-}"
            ;;
        nat-guide)
            nat_guide_cmd "${args[1]:-}"
            ;;
        show-nft)
            show_nft
            ;;
        show-code)
            show_code "${args[1]:-}"
            ;;
        show-nat-code)
            show_code "${args[1]:-}"
            ;;
        import-code)
            add_nat_ingress_from_listener_code
            ;;
        uninstall)
            uninstall
            ;;
        purge)
            purge
            ;;
        "")
            if is_tty; then
                show_menu
            else
                usage
                exit 1
            fi
            ;;
        *)
            usage
            die_user "未知命令：${cmd}"
            ;;
    esac
}

if [[ "${IXTF_TEST_SOURCE:-}" != "1" ]]; then
    main "$@"
fi
