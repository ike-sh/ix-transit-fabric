#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -w "${TMPDIR:-/tmp}" ]]; then
    export TMPDIR="${ROOT_DIR}/.tmp"
    mkdir -p "$TMPDIR"
fi

bash -n install.sh

version_output="$(bash install.sh --version)"
[[ "$version_output" == "ix-transit-fabric 1.1.0-alpha.5" ]]

bash install.sh --help >/dev/null

for token in \
    list-profiles \
    add-landing-profile \
    add-ingress-profile-from-code \
    add-nat-ingress-profile \
    add-nat-transit-profile-from-code \
    add-nat-listener-profile \
    add-nat-ingress-from-listener-code \
    show-nat-code \
    refresh-nat-code \
    nat-guide \
    nat-status \
    nat-health \
    nat-port-map \
    nat-ingress \
    nat-transit \
    NAT-IX \
    TRANSIT_PORT \
    LANDING_HOST \
    LANDING_PORT \
    NAT_ET_IP \
    INGRESS_ET_IP \
    NAT_DIRECTION \
    ingress-listener \
    nat-listener \
    NAT_PUBLIC_HOST \
    NAT_LISTENER_PORT \
    "商家入口可达性" \
    "连接 NAT IX" \
    "show-port-map 支持 nat" \
    "verify-nft-profiles 支持 nat" \
    "traffic-report 支持 nat" \
    "traffic-report 支持 nat-ingress / nat-transit，可用 --sample N" \
    latency-report \
    nat-latency \
    latency-all \
    show-easytier-status \
    ping_summary \
    parse_ping_summary \
    print_latency_metric \
    tcp_connect_time \
    nc_connect_time \
    bash_tcp_connect_time \
    show_easytier_status \
    show-easytier-status \
    tunnel_type \
    TCP-over-TCP \
    status-all \
    doctor-all \
    start-profile \
    stop-profile \
    restart-profile \
    delete-profile \
    enable-profile \
    disable-profile \
    migrate-single-profile \
    apply-nft-all \
    ix-transit-easytier@ \
    validate_profile_id \
    validate_profile_config \
    check_profile_conflicts \
    check_all_profiles_conflicts \
    validate_all_enabled_profiles \
    profile_env_value_from_path \
    profile_subnet_from_path \
    stop_disable_profile_services \
    validate_switch_target \
    ensure_single_forward_enabled_in_group \
    record_switch_event \
    switch-history.tsv \
    primary-backup-check \
    primary-backup-runbook \
    primary-backup-summary \
    validate-primary-backup \
    switch-dry-run \
    switch-history \
    clear-switch-history \
    switch-rollback-last \
    monitor-run-once \
    monitor-enable \
    monitor-disable \
    monitor-status \
    preflight \
    install-netcat \
    install-diagnostics-tools \
    install_nc_tool \
    ensure_nc_tool \
    IXTF_ASSUME_YES \
    IXTF_AUTO_INSTALL_EASYTIER \
    assume_yes_enabled \
    auto_install_easytier_enabled \
    monitor-set-interval \
    notify-config \
    notify-test \
    notify-enable \
    notify-disable \
    notify-status \
    health-history \
    clear-health-history \
    traffic-status \
    traffic-report \
    traffic-reset \
    traffic-reset-all \
    self-check \
    IXTF_COLOR \
    NO_COLOR \
    color_init \
    print_port_map_compact \
    resolve_profile_id_for_cmd \
    print_profile_selection_hint \
    nft_profile_rule_status \
    nft_forwarding_verify_status \
    print_no_group_message \
    profile_group_count \
    group_issue_lines \
    show-port-map-compact \
    detect_nc_cmd \
    suggest_install_nc \
    netcat-openbsd \
    save_profile_runtime_state \
    show_profile_summary \
    status_profile \
    panel_guide_profile \
    panel_guide_cmd \
    export-diagnostic \
    cleanup-history \
    cleanup-state \
    ix-transit-monitor.timer \
    notify.env \
    TG_BOT_TOKEN \
    NOTIFY_ENABLED \
    export-health-report \
    verify-nft-profiles \
    health-report \
    health-all \
    check-line \
    show-group \
    switch-line \
    switch-to \
    set-primary \
    set-backup \
    set-forward \
    FORWARD_ENABLED \
    LINE_GROUP \
    LINE_ROLE \
    HEALTH_STATUS \
    ROLLBACK \
    SWITCH \
    OFF \
    wait_for_easytier_ready \
    wait_for_et_ip \
    wait_for_peer_or_route \
    detect_public_ipv4 \
    detect_public_host \
    suggest_ingress_public_host \
    IXTF_PUBLIC_IP \
    IXTF_INGRESS_PUBLIC_HOST \
    "使用环境变量指定的公网入口地址" \
    "未自动检测到公网 IPv4" \
    "检测到当前公网 IPv4" \
    "请输入公网入口机公网 IP 或域名 INGRESS_PUBLIC_HOST" \
    "ICMP ping 不通" \
    "NAT_ET_IP:TRANSIT_PORT" \
    "可能不命中 PREROUTING" \
    profile_counter_health_status \
    pending_peer \
    mode_nat_transit \
    mode_nat_ingress \
    render_explicit_only_arg \
    refresh_nat_code \
    show_easytier_command \
    show-easytier-command \
    EasyTier_peer_not_established \
    show_code_skip_security \
    "推荐：NAT IX 机器生成接入码" \
    "推荐：公网入口机导入 NAT IX 接入码" \
    "虚拟网中转端口" \
    "是否自定义高级参数" \
    "商家 NAT/IX 入口地址" \
    "商家分配入口端口" \
    "当前操作适用于 NAT IX 机器" \
    "当前操作适用于公网入口机" \
    "是否删除当前安装脚本" \
    "已删除 easytier-core" \
    "已保留 easytier-core"; do
    grep -q -- "$token" install.sh
done

for token in \
    "一行安装" \
    "EasyTier 替代 WireGuard" \
    "四端口说明" \
    "主备线路与手动切换" \
    "监控 / 通知 / 流量统计" \
    "不做自动切换" \
    "不清空全局 nftables ruleset" \
    "不全局 kill" \
    "NAT-IX Transit Mode" \
    "NAT-IX 中转模式" \
    "推荐模式" \
    "NAT IX 机器生成接入码" \
    "公网入口机导入 NAT IX 接入码" \
    "NAT_PUBLIC_HOST" \
    "NAT_LISTENER_PORT" \
    "虚拟网中转端口" \
    "普通用户无需关心" \
    "Realm-xwPF" \
    "商家分配的入站端口" \
    "公网入口机" \
    "NAT IX 机器" \
    "TRANSIT_PORT" \
    "LANDING_HOST" \
    "LANDING_PORT" \
    "不需要 CNIX 面板出口配置" \
    "access code 包含 EasyTier 组网密钥" \
    "self-check" \
    "export-diagnostic" \
    "安全边界" \
    "Roadmap" \
    "raw.githubusercontent.com/ike-sh/ix-transit-fabric/main/install.sh" \
    "1.1.0-alpha.5" \
    "IXTF_PUBLIC_IP" \
    "IXTF_INGRESS_PUBLIC_HOST" \
    "NAT-IX 延迟诊断" \
    "latency-report" \
    "traffic-report --sample" \
    "TCP-over-TCP" \
    "ICMP ping 不是业务延迟" \
    "协议 A/B 测试" \
    "PREROUTING" \
    "商家 NAT/IX 入口地址" \
    "落地机地址:落地业务端口" \
    "refresh-nat-code" \
    "NAT-IX Alpha 注意事项" \
    "NAT IX 机器本机"; do
    grep -q "$token" README.md
done

for file in \
    examples/profile-landing.env \
    examples/profile-ingress.env \
    examples/multi-line-notes.md \
    examples/primary-backup-notes.md \
    examples/switch-runbook.md \
    examples/manual-failover-runbook.md \
    examples/notify.env.example \
    examples/monitor-runbook.md \
    examples/traffic-notes.md \
    examples/nat-ingress.env \
    examples/nat-transit.env \
    examples/nat-transit-runbook.md \
    examples/README.md \
    examples/profile-ingress-primary.env \
    examples/profile-ingress-backup.env; do
    [[ -f "$file" ]]
done

expected_examples="$(
    printf '%s\n' \
        README.md \
        profile-landing.env \
        profile-ingress.env \
        multi-line-notes.md \
        primary-backup-notes.md \
        profile-ingress-primary.env \
        profile-ingress-backup.env \
        switch-runbook.md \
        manual-failover-runbook.md \
        notify.env.example \
        monitor-runbook.md \
        traffic-notes.md \
        nat-ingress.env \
        nat-transit.env \
        nat-transit-runbook.md | sort
)"
actual_examples="$(find examples -maxdepth 1 -type f -print | sed 's#^examples/##' | sort)"
if [[ "$actual_examples" != "$expected_examples" ]]; then
    echo "examples directory does not match release package list" >&2
    diff -u <(printf '%s\n' "$expected_examples") <(printf '%s\n' "$actual_examples") >&2 || true
    exit 1
fi

forbidden_client_name="$(printf '\345\260\217\347\201\253\347\256\255')"
forbidden_real_code_prefix="$(printf '\111\130\124\106\061\072\145\171\112')"
forbidden_nft_reset="$(printf '\146\154\165\163\150\040\162\165\154\145\163\145\164')"
forbidden_pkill_rw="$(printf '\160\153\151\154\154\040\055\146\040\162\167\055\143\157\162\145')"
forbidden_pkill_et="$(printf '\160\153\151\154\154\040\055\146\040\145\141\163\171\164\151\145\162\055\143\157\162\145')"
forbidden_killall_rw="$(printf '\153\151\154\154\141\154\154\040\162\167\055\143\157\162\145')"
forbidden_killall_et="$(printf '\153\151\154\154\141\154\154\040\145\141\163\171\164\151\145\162\055\143\157\162\145')"
forbidden_tg_token="$(printf '\061\062\063\064\065\066\072\101\102\103')"
forbidden_tg_token_pattern="$(printf '\124\107\137\102\117\124\137\124\117\113\105\116\075\056\052\133\060\055\071\135\056\052\072')"
forbidden_real_deploy_pattern="$(printf '\061\066\063[.]\062\062\063[.]|\061\060[.]\061\062\064[.]\063\070[.]|\062\066\066\070\064|\062\067\060\070\071|\065\060\063\062\071|\063\067\065\071\062')"
forbidden_old_051="$(printf '\060[.]\065[.]\061\055\141\154\160\150\141')"
forbidden_old_056="$(printf '\060[.]\065[.]\066\055\141\154\160\150\141')"

! grep -R -q "$forbidden_client_name" README.md install.sh tests examples CHANGELOG.md
! grep -R -q "$forbidden_real_code_prefix" README.md tests examples CHANGELOG.md
! grep -R -q "$forbidden_nft_reset" install.sh examples
! grep -R -q "$forbidden_pkill_rw" install.sh examples
! grep -R -q "$forbidden_pkill_et" install.sh examples
! grep -R -q "$forbidden_killall_rw" install.sh examples
! grep -R -q "$forbidden_killall_et" install.sh examples
! grep -R -q "$forbidden_tg_token" README.md tests examples CHANGELOG.md
! grep -R -E -q "$forbidden_tg_token_pattern" README.md tests examples CHANGELOG.md
! grep -R -E -q "$forbidden_real_deploy_pattern" README.md install.sh examples CHANGELOG.md

if grep -R -Eq '8[.]163[.]46[.]205|163[.]223[.]125[.]6|103[.]100[.]176[.]107' README.md examples tests; then
    echo "docs/examples/tests contain real deployment IPv4 literal" >&2
    exit 1
fi

if grep -R -n '^ET_NETWORK_SECRET=' examples | grep -v '=change-me$' >/dev/null; then
    echo "examples contain non-placeholder secret" >&2
    exit 1
fi

! grep -R -E -q "${forbidden_old_051}|${forbidden_old_056}" README.md install.sh examples

[[ "$(tr -d '\r\n' < VERSION)" == "1.1.0-alpha.5" ]]

! grep -R -E -q '（默认 [^）]+）（默认' install.sh README.md tests examples CHANGELOG.md
! grep -q '模式 B 接入码' install.sh
! grep -q 'NAT-IX 模式 B 接入码' install.sh
! grep -q '模式 A' install.sh README.md
! grep -q '模式 B' install.sh README.md

grep -q 'ix-transit-easytier@%s.service' install.sh
grep -q 'show_profile_summary "$PROFILE_ID"' install.sh
grep -q 'panel_guide_profile' install.sh
grep -q 'install_if_changed' install.sh
grep -q 'curl -fL -sS --connect-timeout 6 --max-time 20' install.sh
grep -q 'nft_profile_rule_present' install.sh
grep -q '当前机器没有启用中的入口转发 Profile，nftables 转发校验已跳过。' install.sh
grep -q '当前没有已配置的线路组' install.sh
grep -q 'LINE_GROUP 为空' install.sh
grep -q 'standalone' install.sh
grep -q 'standalone 模式下主备组检查已跳过' install.sh
grep -q 'profile_group_count' install.sh
grep -q 'group_issue_lines' install.sh
grep -q 'save_profile_runtime_state' install.sh
grep -q 'install-netcat' install.sh
grep -q 'IXTF_ASSUME_YES=true / IXTF_AUTO_INSTALL_EASYTIER=true' install.sh
grep -q 'nc 不可用，跳过 TCP 业务端口探测' install.sh
grep -q 'log_warn "已取消完全清理' install.sh
grep -q 'examples/profile-landing.env' install.sh
grep -q 'examples/profile-ingress.env' install.sh

add_landing_body="$(sed -n '/^add_landing_profile()/,/^add_ingress_profile_from_code()/p' install.sh)"
! grep -q 'post_install_summary' <<<"$add_landing_body"
! grep -q 'load_env_or_warn' <<<"$add_landing_body"

add_ingress_body="$(sed -n '/^add_ingress_profile_from_code()/,/^install_panel_ingress()/p' install.sh)"
! grep -q 'post_install_summary' <<<"$add_ingress_body"
! grep -q 'load_env_or_warn' <<<"$add_ingress_body"

grep -q '一行安装' README.md
grep -q 'CNIX 面板出口' README.md
grep -q 'EasyTier listener' README.md
grep -q '`REMOTE_PORT` 是落地业务服务端口' README.md
grep -q 'netcat-openbsd' README.md
grep -q 'IXTF_EASYTIER_DOWNLOAD_URL' README.md
grep -q 'IXTF_EASYTIER_VERSION' README.md
grep -q 'access code 包含 EasyTier 组网密钥' README.md
grep -q 'CNIX 面板出口：落地 VPS:LISTENER_PORT' README.md
grep -q '客户端：入口 VPS:LOCAL_PORT' README.md
grep -q '落地机配置' README.md
grep -q '入口机配置' README.md
grep -q 'nftables 转发校验已跳过' README.md
grep -q 'list-profiles' README.md
grep -q 'show-port-map --compact' README.md
grep -q 'standalone Profile' README.md
grep -q '没有线路组' README.md
grep -q '主备组检查已跳过' README.md
grep -q 'LINE_GROUP' README.md
grep -q '1.0.0' README.md
grep -q '1.1.0-alpha.1' README.md
grep -q '1.1.0-alpha.5' README.md
grep -q '推荐模式' README.md
grep -q 'NAT IX 机器生成接入码' README.md
grep -q '公网入口机导入 NAT IX 接入码' README.md
grep -q '虚拟网中转端口' README.md
grep -q '普通用户无需关心' README.md
grep -q 'NAT_PUBLIC_HOST' README.md
grep -q 'NAT_LISTENER_PORT' README.md
grep -q '完全清理默认不会删除你手动下载的 install.sh' README.md
grep -q 'Realm-xwPF' README.md
grep -q '商家分配的入站端口' README.md
grep -q 'NAT-IX 延迟诊断' README.md
grep -q 'latency-report' README.md
grep -q 'traffic-report --sample' README.md
grep -q 'TCP-over-TCP' README.md
grep -q 'ICMP ping 不是业务延迟' README.md
grep -q '协议 A/B 测试' README.md
grep -q 'install-netcat' README.md
grep -q 'preflight' README.md

unit_tmp="$(mktemp -d)"
cleanup_unit_tmp() {
    rm -rf "$unit_tmp"
}
trap cleanup_unit_tmp EXIT

(
    export IXTF_TEST_SOURCE=1
    # shellcheck source=/dev/null
    . ./install.sh

    CONFIG_DIR="$unit_tmp/config"
    ENV_FILE="${CONFIG_DIR}/ix-transit.env"
    PROFILES_DIR="${CONFIG_DIR}/profiles"
    CODES_DIR="${CONFIG_DIR}/codes"
    STATE_DIR="${CONFIG_DIR}/state"
    HEALTH_HISTORY_FILE="${STATE_DIR}/health-history.tsv"
    LAST_NOTIFY_FILE="${STATE_DIR}/last-notify.tsv"
    LAST_HEALTH_STATUS_FILE="${STATE_DIR}/last-health-status.tsv"
    NOTIFY_ENV_FILE="${CONFIG_DIR}/notify.env"
    MONITOR_SERVICE_FILE="${unit_tmp}/ix-transit-monitor.service"
    MONITOR_TIMER_FILE="${unit_tmp}/ix-transit-monitor.timer"
    MONITOR_INTERVAL_FILE="${STATE_DIR}/monitor-interval"
    MONITOR_LAST_RUN_FILE="${STATE_DIR}/monitor-last-run"
    BACKUP_DIR="$unit_tmp/backups"
    NFT_DIR="$unit_tmp/nft"
    NFT_FILE="${NFT_DIR}/ix-transit-fabric.nft"
    SYSTEMD_SERVICE="$unit_tmp/ix-transit-easytier.service"
    PROFILE_SERVICE_TEMPLATE="$unit_tmp/ix-transit-easytier@.service"
    SYSCTL_FILE="$unit_tmp/sysctl.conf"
    LIBEXEC_DIR="$unit_tmp/libexec"
    WRAPPER_FILE="${LIBEXEC_DIR}/easytier-start"
    LANDING_CODE_FILE="${CONFIG_DIR}/landing-code.txt"
    IXTF_TMPDIR="$unit_tmp/tmp"
    IXTF_DIAGNOSTIC_DIR="$unit_tmp"
    export IXTF_TMPDIR IXTF_DIAGNOSTIC_DIR

    require_root() { :; }
    install_nftables() { :; }
    enable_ip_forward() { :; }
    ensure_systemctl() { :; }
    ensure_easytier() { :; }
    render_profile_service_files() { :; }
    start_profile() { :; }
    stop_profile() { :; }
    restart_profile() { :; }
    is_port_in_use() { return 1; }
    validate_listener_port_available() { return 0; }
    command_exists() {
        case "$1" in
            systemctl|nft|ss|sysctl|journalctl|ip|ping|nc) return 1 ;;
            *) command -v "$1" >/dev/null 2>&1 ;;
        esac
    }
    apply_nft_all() {
        mkdir -p "$NFT_DIR"
        render_nft_all_file "$NFT_FILE" "$NFT_TABLE"
        render_nft_all_file "${unit_tmp}/applied.nft" ix_test
    }

    ensure_profile_dirs

    ROLE=panel-ingress
    ET_NETWORK_NAME=ix-old
    ET_NETWORK_SECRET=change-me-old-secret
    ET_HOSTNAME=ix-old-ingress
    ET_IPV4=10.91.1.1/24
    ET_SUBNET=10.91.1.0/24
    CNIX_ENTRY_PROTO=both
    CNIX_ENTRY_HOST=cnix.example.com
    CNIX_ENTRY_PORT=23000
    ET_PEERS=tcp://cnix.example.com:23000
    ET_NO_LISTENER=true
    FORWARD_ENABLED=true
    LOCAL_PORT=26000
    LANDING_ET_IP=10.91.1.2
    REMOTE_PORT=443
    FORWARD_PROTO=both
    save_env >/dev/null 2>&1
    migrate_single_profile >/dev/null 2>&1
    [[ -f "${PROFILES_DIR}/default.env" ]]
    grep -q '^PROFILE_ID=default$' "${PROFILES_DIR}/default.env"

    make_ingress_profile() {
        local id="$1" local_port="$2" enabled="$3" subnet="$4" ip="$5"
        local group="${6:-}" line_role="${7:-standalone}" priority="${8:-100}" forward="${9:-true}" health="${10:-unknown}"
        cat >"${PROFILES_DIR}/${id}.env" <<EOF_PROFILE
PROFILE_ID=${id}
PROFILE_NAME=${id}
ROLE=panel-ingress
ENABLED=${enabled}
LINE_GROUP=${group}
LINE_ROLE=${line_role}
LINE_PRIORITY=${priority}
HEALTH_CHECK_ENABLED=true
HEALTH_STATUS=${health}
ET_NETWORK_NAME=ix-${id}
ET_NETWORK_SECRET=change-me-${id}-secret
ET_SUBNET=${subnet}
ET_HOSTNAME=ix-${id}
ET_IPV4=${ip}
CNIX_ENTRY_PROTO=both
CNIX_ENTRY_HOST=cnix.example.com
CNIX_ENTRY_PORT=23000
ET_PEERS=tcp://cnix.example.com:23000
ET_NO_LISTENER=true
FORWARD_ENABLED=${forward}
LOCAL_PORT=${local_port}
LANDING_ET_IP=${ip%.*}.2
REMOTE_PORT=443
FORWARD_PROTO=both
CODE_LISTENER_PORT=24000
EOF_PROFILE
        chmod 600 "${PROFILES_DIR}/${id}.env"
    }

    make_landing_profile() {
        local id="$1" listener_port="$2" enabled="$3" subnet="$4" ip="$5"
        cat >"${PROFILES_DIR}/${id}.env" <<EOF_PROFILE
PROFILE_ID=${id}
PROFILE_NAME=${id}
ROLE=panel-landing
ENABLED=${enabled}
LINE_ROLE=standalone
LINE_PRIORITY=100
HEALTH_CHECK_ENABLED=true
HEALTH_STATUS=unknown
ET_NETWORK_NAME=ix-${id}
ET_NETWORK_SECRET=change-me-${id}-secret
ET_SUBNET=${subnet}
ET_HOSTNAME=ix-${id}
ET_IPV4=${ip}
LISTENER_PROTOS=tcp+udp
LISTENER_PORT=${listener_port}
ET_LISTENER_PROTO=both
ET_LISTENER_PORT=${listener_port}
ET_LISTENERS=tcp://0.0.0.0:${listener_port} udp://0.0.0.0:${listener_port}
SERVICE_PORT=443
REMOTE_PORT=443
EOF_PROFILE
        chmod 600 "${PROFILES_DIR}/${id}.env"
    }

    make_nat_ingress_profile() {
        local id="$1" local_port="$2" enabled="$3" subnet="$4" ingress_cidr="$5" nat_ip="$6" transit_port="$7"
        cat >"${PROFILES_DIR}/${id}.env" <<EOF_PROFILE
PROFILE_ID=${id}
PROFILE_NAME=${id}
ROLE=nat-ingress
NAT_DIRECTION=ingress-listener
ENABLED=${enabled}
LINE_ROLE=standalone
LINE_PRIORITY=100
HEALTH_CHECK_ENABLED=true
HEALTH_STATUS=unknown
ET_NETWORK_NAME=ix-${id}
ET_NETWORK_SECRET=change-me-${id}-secret
ET_SUBNET=${subnet}
ET_HOSTNAME=ix-${id}
ET_IPV4=${ingress_cidr}
INGRESS_PUBLIC_HOST=ingress.example
INGRESS_HOSTNAME=ingress.example
INGRESS_ET_IP=${ingress_cidr%/*}
INGRESS_ET_CIDR=${ingress_cidr}
INGRESS_LISTENER_PROTO=both
INGRESS_LISTENER_PROTOS="tcp udp"
INGRESS_LISTENER_PORT=20000
ET_LISTENER_PROTO=both
ET_LISTENER_PORT=20000
ET_LISTENERS="tcp://0.0.0.0:20000 udp://0.0.0.0:20000"
NAT_ET_IP=${nat_ip}
NAT_ET_CIDR=${nat_ip}/24
FORWARD_ENABLED=true
LOCAL_PORT=${local_port}
TRANSIT_PORT=${transit_port}
FORWARD_PROTO=both
EOF_PROFILE
        chmod 600 "${PROFILES_DIR}/${id}.env"
    }

    make_nat_transit_profile() {
        local id="$1" enabled="$2" subnet="$3" nat_cidr="$4" ingress_ip="$5" transit_port="$6" landing_host="$7" landing_port="$8"
        cat >"${PROFILES_DIR}/${id}.env" <<EOF_PROFILE
PROFILE_ID=${id}
PROFILE_NAME=${id}
ROLE=nat-transit
NAT_DIRECTION=ingress-listener
ENABLED=${enabled}
LINE_ROLE=standalone
LINE_PRIORITY=100
HEALTH_CHECK_ENABLED=true
HEALTH_STATUS=unknown
ET_NETWORK_NAME=ix-${id}
ET_NETWORK_SECRET=change-me-${id}-secret
ET_SUBNET=${subnet}
ET_HOSTNAME=ix-${id}
ET_IPV4=${nat_cidr}
INGRESS_PUBLIC_HOST=ingress.example
INGRESS_HOSTNAME=ingress.example
INGRESS_ET_IP=${ingress_ip}
INGRESS_ET_CIDR=${ingress_ip}/24
INGRESS_LISTENER_PROTO=both
INGRESS_LISTENER_PROTOS="tcp udp"
INGRESS_LISTENER_PORT=20000
NAT_ET_IP=${nat_cidr%/*}
NAT_ET_CIDR=${nat_cidr}
ET_PEERS="tcp://ingress.example:20000 udp://ingress.example:20000"
ET_NO_LISTENER=true
FORWARD_ENABLED=true
LOCAL_PORT=30000
TRANSIT_PORT=${transit_port}
LANDING_HOST=${landing_host}
LANDING_PORT=${landing_port}
FORWARD_PROTO=both
EOF_PROFILE
        chmod 600 "${PROFILES_DIR}/${id}.env"
    }

    make_nat_listener_profile() {
        local id="$1" enabled="$2" subnet="$3" nat_cidr="$4" ingress_ip="$5" transit_port="$6" landing_host="$7" landing_port="$8"
        cat >"${PROFILES_DIR}/${id}.env" <<EOF_PROFILE
PROFILE_ID=${id}
PROFILE_NAME=${id}
ROLE=nat-transit
NAT_DIRECTION=nat-listener
ENABLED=${enabled}
LINE_ROLE=standalone
LINE_PRIORITY=100
HEALTH_CHECK_ENABLED=true
HEALTH_STATUS=unknown
ET_NETWORK_NAME=ix-${id}
ET_NETWORK_SECRET=change-me-${id}-secret
ET_SUBNET=${subnet}
ET_HOSTNAME=ix-${id}
ET_IPV4=${nat_cidr}
INGRESS_ET_IP=${ingress_ip}
INGRESS_ET_CIDR=${ingress_ip}/24
NAT_ET_IP=${nat_cidr%/*}
NAT_ET_CIDR=${nat_cidr}
NAT_PUBLIC_HOST=nat-ix.example
NAT_LISTENER_PROTO=both
NAT_LISTENER_PROTOS="tcp udp"
NAT_LISTENER_PORT=31000
ET_LISTENER_PROTO=both
ET_LISTENER_PORT=31000
ET_LISTENERS="tcp://0.0.0.0:31000 udp://0.0.0.0:31000"
ET_NO_LISTENER=false
FORWARD_ENABLED=true
TRANSIT_PORT=${transit_port}
LANDING_HOST=${landing_host}
LANDING_PORT=${landing_port}
FORWARD_PROTO=both
EOF_PROFILE
        chmod 600 "${PROFILES_DIR}/${id}.env"
    }

    make_nat_ingress_listener_profile() {
        local id="$1" local_port="$2" enabled="$3" subnet="$4" ingress_cidr="$5" nat_ip="$6" transit_port="$7"
        cat >"${PROFILES_DIR}/${id}.env" <<EOF_PROFILE
PROFILE_ID=${id}
PROFILE_NAME=${id}
ROLE=nat-ingress
NAT_DIRECTION=nat-listener
ENABLED=${enabled}
LINE_ROLE=standalone
LINE_PRIORITY=100
HEALTH_CHECK_ENABLED=true
HEALTH_STATUS=unknown
ET_NETWORK_NAME=ix-${id}
ET_NETWORK_SECRET=change-me-${id}-secret
ET_SUBNET=${subnet}
ET_HOSTNAME=ix-${id}
ET_IPV4=${ingress_cidr}
INGRESS_PUBLIC_HOST=ingress.example
INGRESS_HOSTNAME=ingress.example
INGRESS_ET_IP=${ingress_cidr%/*}
INGRESS_ET_CIDR=${ingress_cidr}
NAT_ET_IP=${nat_ip}
NAT_ET_CIDR=${nat_ip}/24
NAT_PUBLIC_HOST=nat-ix.example
NAT_LISTENER_PROTO=both
NAT_LISTENER_PROTOS="tcp udp"
NAT_LISTENER_PORT=31000
ET_PEERS="tcp://nat-ix.example:31000 udp://nat-ix.example:31000"
ET_NO_LISTENER=true
FORWARD_ENABLED=true
LOCAL_PORT=${local_port}
TRANSIT_PORT=${transit_port}
LANDING_HOST=10.89.0.3
LANDING_PORT=50000
FORWARD_PROTO=both
EOF_PROFILE
        chmod 600 "${PROFILES_DIR}/${id}.env"
    }

    rm -f "${PROFILES_DIR}"/*.env
    make_ingress_profile line-a 26000 true 10.92.1.0/24 10.92.1.1/24
    make_ingress_profile line-b 26000 true 10.92.2.0/24 10.92.2.1/24
    ! ( check_all_profiles_conflicts >/dev/null 2>&1 )

    make_ingress_profile line-b 26000 false 10.92.2.0/24 10.92.2.1/24
    check_all_profiles_conflicts

    make_landing_profile land-a 24000 true 10.93.1.0/24 10.93.1.2/24
    make_landing_profile land-b 24000 true 10.93.2.0/24 10.93.2.2/24
    ! ( check_all_profiles_conflicts >/dev/null 2>&1 )

    make_landing_profile land-b 24001 true 10.93.1.0/24 10.93.1.3/24
    ! ( check_all_profiles_conflicts >/dev/null 2>&1 )

    make_landing_profile land-b 24001 true 10.93.2.0/24 10.93.1.2/24
    ! ( check_all_profiles_conflicts >/dev/null 2>&1 )

    rm -f "${PROFILES_DIR}"/*.env
    make_ingress_profile keep-line 26010 true 10.90.1.0/24 10.90.1.1/24
    make_ingress_profile off-line 26011 false 10.90.2.0/24 10.90.2.1/24
    nft_render="${unit_tmp}/rendered.nft"
    render_nft_all_file "$nft_render" ix_test
    grep -q 'profile: keep-line' "$nft_render"
    grep -q 'counter dnat' "$nft_render"
    grep -q 'counter masquerade' "$nft_render"
    ! grep -q 'profile: off-line' "$nft_render"

    map_output="$(show_port_map --all)"
    grep -q '===== Profile keep-line =====' <<<"$map_output"
    grep -q 'LOCAL_PORT=26010' <<<"$map_output"
    grep -q 'LISTENER_PORT=24000' <<<"$map_output"
    compact_output_a="$(show_port_map --compact keep-line)"
    compact_output_b="$(show_port_map keep-line --compact)"
    grep -q '26010 -> 10.90.1.2:443' <<<"$compact_output_a"
    grep -q '26010 -> 10.90.1.2:443' <<<"$compact_output_b"
    all_compact_output_a="$(show_port_map --all --compact)"
    all_compact_output_b="$(show_port_map --compact --all)"
    grep -q '===== Profile keep-line =====' <<<"$all_compact_output_a"
    grep -q '===== Profile keep-line =====' <<<"$all_compact_output_b"

    rm -f "${PROFILES_DIR}"/*.env
    make_nat_ingress_profile nat-in 30000 true 10.88.0.0/24 10.88.0.1/24 10.88.0.2 20000
    render_nft_all_file "$nft_render" ix_test
    grep -q 'profile: nat-in' "$nft_render"
    grep -q 'tcp dport 30000 counter dnat to 10.88.0.2:20000' "$nft_render"
    grep -q 'udp dport 30000 counter dnat to 10.88.0.2:20000' "$nft_render"
    nat_ingress_map="$(show_port_map --compact nat-in)"
    grep -q '公网入口线路' <<<"$nat_ingress_map"
    grep -q '30000 -> 10.88.0.2:20000' <<<"$nat_ingress_map"
    mkdir -p "$NFT_DIR"
    render_nft_all_file "$NFT_FILE" "$NFT_TABLE"
    [[ "$(nft_profile_rule_status nat-in)" == "present" ]]
    verify_nat_ingress_output="$(verify_nft_profiles_core)"
    grep -q '\[OK\] nftables rules match' <<<"$verify_nat_ingress_output"
    traffic_nat_ingress_output="$(traffic_report)"
    grep -q $'nat-in\t\tnat-ingress\t30000\t10.88.0.2:20000' <<<"$traffic_nat_ingress_output"
    traffic_nat_ingress_sample_output="$(traffic_report --sample 0)"
    grep -q 'PROFILE_ID' <<<"$traffic_nat_ingress_sample_output"
    latency_nat_ingress_output="$(latency_report nat-in --sample 0)"
    grep -q 'NAT-IX latency-report: nat-in' <<<"$latency_nat_ingress_output"
    grep -q 'ROLE=nat-ingress' <<<"$latency_nat_ingress_output"
    grep -q 'EasyTier peer hints' <<<"$latency_nat_ingress_output"
    grep -q 'counter current:' <<<"$latency_nat_ingress_output"

    rm -f "${PROFILES_DIR}"/*.env
    make_nat_transit_profile nat-mid true 10.88.0.0/24 10.88.0.2/24 10.88.0.1 20000 10.88.0.1 50000
    render_nft_all_file "$nft_render" ix_test
    grep -q 'profile: nat-mid' "$nft_render"
    grep -q 'ip daddr 10.88.0.2 tcp dport 20000 counter dnat to 10.88.0.1:50000' "$nft_render"
    grep -q 'ip daddr 10.88.0.2 udp dport 20000 counter dnat to 10.88.0.1:50000' "$nft_render"
    nat_transit_map="$(show_port_map --compact nat-mid)"
    grep -q 'NAT IX 中转线路' <<<"$nat_transit_map"
    grep -q '连接公网入口机' <<<"$nat_transit_map"
    grep -q 'ingress.example:20000' <<<"$nat_transit_map"
    grep -q '10.88.0.2:20000 -> 10.88.0.1:50000' <<<"$nat_transit_map"
    ! grep -q ':LISTENER_PORT' <<<"$nat_transit_map"
    mkdir -p "$NFT_DIR"
    render_nft_all_file "$NFT_FILE" "$NFT_TABLE"
    [[ "$(nft_profile_rule_status nat-mid)" == "present" ]]
    verify_nat_transit_output="$(verify_nft_profiles_core)"
    grep -q '\[OK\] nftables rules match' <<<"$verify_nat_transit_output"
    traffic_nat_transit_output="$(traffic_report)"
    grep -q $'nat-mid\t\tnat-transit\t20000\t10.88.0.1:50000' <<<"$traffic_nat_transit_output"
    latency_nat_transit_output="$(latency_report nat-mid --sample 0)"
    grep -q 'NAT-IX latency-report: nat-mid' <<<"$latency_nat_transit_output"
    grep -q 'ROLE=nat-transit' <<<"$latency_nat_transit_output"
    grep -q 'NAT IX 本机直连 NAT_ET_IP:TRANSIT_PORT 可能不命中 PREROUTING DNAT' <<<"$latency_nat_transit_output"

    rm -f "${PROFILES_DIR}"/*.env
    make_nat_listener_profile nat-listen true 10.89.0.0/24 10.89.0.2/24 10.89.0.1 21000 10.89.0.3 50000
    load_profile nat-listen
    validate_profile_config nat-listen
    nat_listener_cmd="$(render_easytier_args)"
    grep -q -- '--listeners tcp://0.0.0.0:31000' <<<"$nat_listener_cmd"
    grep -q -- '--listeners udp://0.0.0.0:31000' <<<"$nat_listener_cmd"
    ! grep -q -- '--no-listener' <<<"$nat_listener_cmd"
    nat_listener_code="$(generate_nat_code)"
    parse_nat_code "$nat_listener_code"
    [[ "$CODE_NAT_DIRECTION" == "nat-listener" ]]
    [[ "$CODE_NAT_PUBLIC_HOST" == "nat-ix.example" ]]
    [[ "$CODE_NAT_LISTENER_PORT" == "31000" ]]
    render_nft_all_file "$nft_render" ix_test
    grep -q 'profile: nat-listen' "$nft_render"
    grep -q 'ip daddr 10.89.0.2 tcp dport 21000 counter dnat to 10.89.0.3:50000' "$nft_render"
    nat_listener_map="$(show_port_map --compact nat-listen)"
    grep -q 'NAT IX 中转线路' <<<"$nat_listener_map"
    grep -q '商家入口' <<<"$nat_listener_map"
    grep -q 'nat-ix.example:31000' <<<"$nat_listener_map"
    latency_nat_listener_output="$(latency_report nat-listen --sample 0)"
    grep -q 'NAT_DIRECTION=nat-listener' <<<"$latency_nat_listener_output"
    grep -q 'NAT_PUBLIC_HOST=nat-ix.example' <<<"$latency_nat_listener_output"
    grep -q '当前连接方向：NAT IX 机器监听，公网入口机连接 NAT IX。' <<<"$latency_nat_listener_output"

    rm -f "${PROFILES_DIR}"/*.env
    make_nat_ingress_listener_profile nat-in-b 32000 true 10.89.0.0/24 10.89.0.1/24 10.89.0.2 21000
    load_profile nat-in-b
    validate_profile_config nat-in-b
    nat_ingress_listener_cmd="$(render_easytier_args)"
    grep -q -- '--peers tcp://nat-ix.example:31000' <<<"$nat_ingress_listener_cmd"
    grep -q -- '--peers udp://nat-ix.example:31000' <<<"$nat_ingress_listener_cmd"
    grep -q -- '--no-listener' <<<"$nat_ingress_listener_cmd"
    render_nft_all_file "$nft_render" ix_test
    grep -q 'profile: nat-in-b' "$nft_render"
    grep -q 'tcp dport 32000 counter dnat to 10.89.0.2:21000' "$nft_render"
    nat_ingress_listener_map="$(show_port_map --compact nat-in-b)"
    grep -q '公网入口线路' <<<"$nat_ingress_listener_map"
    grep -q '连接 NAT IX' <<<"$nat_ingress_listener_map"
    grep -q 'nat-ix.example:31000' <<<"$nat_ingress_listener_map"
    mkdir -p "$NFT_DIR"
    render_nft_all_file "$NFT_FILE" "$NFT_TABLE"
    [[ "$(nft_profile_rule_status nat-in-b)" == "present" ]]
    verify_nat_listener_ingress_output="$(verify_nft_profiles_core)"
    grep -q '\[OK\] nftables rules match' <<<"$verify_nat_listener_ingress_output"

    rm -f "${PROFILES_DIR}"/*.env
    make_ingress_profile keep-line 26010 true 10.90.1.0/24 10.90.1.1/24
    make_ingress_profile off-line 26011 false 10.90.2.0/24 10.90.2.1/24
    make_ingress_profile broken-line 26012 true 10.90.3.0/24 10.90.3.1/24
    rm -f "${PROFILES_DIR}/broken-line.env"
    printf 'PROFILE_ID=broken-line\nROLE=panel-ingress\nENABLED=true\n' >"${PROFILES_DIR}/broken-line.env"
    chmod 600 "${PROFILES_DIR}/broken-line.env"
    status_output="$(status_all 2>&1)"
    grep -q 'keep-line' <<<"$status_output"
    doctor_output="$(doctor_all 2>&1)"
    grep -q 'keep-line' <<<"$doctor_output"
    grep -q 'broken-line' <<<"$doctor_output"

    missing_profile_output="$(
        set +e
        health_profile missing-line 2>&1
        printf 'rc=%s\n' "$?"
    )"
    grep -q '未找到 Profile：missing-line' <<<"$missing_profile_output"
    grep -q '当前机器已有 Profile' <<<"$missing_profile_output"
    grep -q 'list-profiles' <<<"$missing_profile_output"
    ! grep -q '脚本在第' <<<"$missing_profile_output"

    rm -f "${PROFILES_DIR}"/*.env
    make_landing_profile land-only 24002 true 10.90.4.0/24 10.90.4.2/24
    landing_verify_output="$(verify_nft_profiles_core 2>&1)"
    grep -q '当前机器没有启用中的入口转发 Profile，nftables 转发校验已跳过。' <<<"$landing_verify_output"
    ! grep -q 'verify-nft-profiles skipped' <<<"$landing_verify_output"
    ! grep -q 'no forwarding profiles' <<<"$landing_verify_output"
    [[ "$(nft_forwarding_verify_status)" == "skipped" ]]

    rm -f "${PROFILES_DIR}"/*.env
    make_ingress_profile verify-line 26013 true 10.90.5.0/24 10.90.5.1/24
    mkdir -p "$NFT_DIR"
    render_nft_all_file "$NFT_FILE" "$NFT_TABLE"
    [[ "$(nft_profile_rule_status verify-line)" == "present" ]]
    [[ "$(nft_forwarding_verify_status)" == "ok" ]]
    verify_match_output="$(verify_nft_profiles_core)"
    grep -q '\[OK\] nftables rules match' <<<"$verify_match_output"

    rm -f "${PROFILES_DIR}"/*.env
    make_ingress_profile standalone-line 26014 true 10.90.6.0/24 10.90.6.1/24 "" standalone 100 true healthy
    standalone_doctor_output="$(doctor_all 2>&1)"
    grep -q '当前没有已配置的线路组' <<<"$standalone_doctor_output"
    grep -q 'standalone 模式下主备组检查已跳过' <<<"$standalone_doctor_output"
    grep -q 'group_issue_count=0' <<<"$standalone_doctor_output"
    ! grep -q '脚本在第' <<<"$standalone_doctor_output"
    standalone_report_output="$(health_report 2>&1)"
    grep -q 'standalone-line' <<<"$standalone_report_output"
    grep -q '主备组检查已跳过' <<<"$standalone_report_output"
    standalone_pb_summary="$(primary_backup_summary 2>&1)"
    grep -q '当前没有已配置的线路组' <<<"$standalone_pb_summary"
    show_no_group_output="$(show_group 2>&1)"
    grep -q '当前没有已配置的线路组' <<<"$show_no_group_output"
    switch_no_group_output="$(switch_dry_run 2>&1)"
    grep -q '当前没有已配置的线路组' <<<"$switch_no_group_output"

    rm -f "${PROFILES_DIR}"/*.env
    make_ingress_profile hk-primary 26020 true 10.95.1.0/24 10.95.1.1/24 hk-group primary 10 true down
    make_ingress_profile hk-backup 26021 true 10.95.2.0/24 10.95.2.1/24 hk-group backup 20 false healthy

    report_output="$(health_report --group hk-group)"
    grep -q 'hk-primary' <<<"$report_output"
    grep -q 'PROFILE' <<<"$report_output"
    grep -q 'FWD' <<<"$report_output"
    grep -q 'profiles total:' <<<"$report_output"
    grep -q 'forwarding lines:' <<<"$report_output"
    grep -q 'groups ready / warning / not-ready:' <<<"$report_output"
    grep -q 'monitor timer：' <<<"$report_output"
    grep -q 'notify：' <<<"$report_output"
    grep -q 'traffic counter exists:' <<<"$report_output"
    grep -q 'switch-dry-run hk-group hk-backup' <<<"$report_output"
    grep -q 'switch-line hk-group hk-backup' <<<"$report_output"

    validate_output="$(validate_primary_backup hk-group 2>&1 || true)"
    grep -q 'Primary/backup validation: hk-group' <<<"$validate_output"
    grep -q 'Backup hk-backup is hot standby' <<<"$validate_output"

    pb_check_output="$(primary_backup_check hk-group 2>&1 || true)"
    grep -q 'Primary/backup real-machine check: hk-group' <<<"$pb_check_output"
    grep -q '主备组状态：' <<<"$pb_check_output"

    pb_runbook_output="$(primary_backup_runbook hk-group)"
    grep -q 'Primary/backup runbook: hk-group' <<<"$pb_runbook_output"
    grep -q 'switch-rollback-last' <<<"$pb_runbook_output"

    pb_summary_output="$(primary_backup_summary)"
    grep -q 'GROUP' <<<"$pb_summary_output"
    grep -q 'hk-group' <<<"$pb_summary_output"
    grep -q 'NOTIFY' <<<"$pb_summary_output"

    before_hash="$(sha256sum "${PROFILES_DIR}/hk-primary.env" "${PROFILES_DIR}/hk-backup.env")"
    dry_output="$(switch_dry_run hk-group hk-backup)"
    after_hash="$(sha256sum "${PROFILES_DIR}/hk-primary.env" "${PROFILES_DIR}/hk-backup.env")"
    [[ "$before_hash" == "$after_hash" ]]
    grep -q 'Dry-run guarantee' <<<"$dry_output"
    grep -q 'Current nftables rules for this group' <<<"$dry_output"
    grep -q 'Expected nftables rules after switch' <<<"$dry_output"
    grep -q 'Risk hints' <<<"$dry_output"

    set_line_priority hk-backup 5 >/dev/null 2>&1
    grep -q '^LINE_PRIORITY=5$' "${PROFILES_DIR}/hk-backup.env"

    set_forward hk-backup on >/dev/null 2>&1
    grep -q '^FORWARD_ENABLED=true$' "${PROFILES_DIR}/hk-backup.env"
    set_forward hk-backup off >/dev/null 2>&1
    grep -q '^FORWARD_ENABLED=false$' "${PROFILES_DIR}/hk-backup.env"

    status_output="$(status_all)"
    grep -q 'forwarding=1' <<<"$status_output"
    grep -q 'abnormal_groups=' <<<"$status_output"

    run_line_health_check() {
        _IXTF_HEALTH_STATUS=healthy
        printf 'fake health ok\n'
    }
    switch_line hk-group hk-backup >/dev/null 2>&1
    grep -q '^FORWARD_ENABLED=false$' "${PROFILES_DIR}/hk-primary.env"
    grep -q '^FORWARD_ENABLED=true$' "${PROFILES_DIR}/hk-backup.env"
    grep -q '^LAST_SWITCH_AT=' "${PROFILES_DIR}/hk-backup.env"
    [[ -f "${STATE_DIR}/switch-history.tsv" ]]
    grep -q 'hk-group' "${STATE_DIR}/switch-history.tsv"
    hist_output="$(switch_history hk-group)"
    grep -q 'TIME' <<<"$hist_output"
    grep -q 'FROM_HEALTH' <<<"$hist_output"
    grep -q 'hk-backup' <<<"$hist_output"
    hist_limit_output="$(switch_history hk-group --limit 1)"
    grep -q 'last 1' <<<"$hist_limit_output"

    switch_again_output="$(switch_line hk-group hk-backup 2>&1)"
    grep -q '已经是线路组 hk-group 当前业务线路' <<<"$switch_again_output"

    IXTF_ALLOW_INTERACTIVE=1 switch_rollback_last <<<$'ROLLBACK\nSWITCH' >/dev/null 2>&1
    grep -q '^FORWARD_ENABLED=true$' "${PROFILES_DIR}/hk-primary.env"
    grep -q '^FORWARD_ENABLED=false$' "${PROFILES_DIR}/hk-backup.env"

    groups_output="$(list_groups)"
    grep -q 'hk-group' <<<"$groups_output"
    show_output="$(show_group hk-group)"
    grep -q 'CURRENT FORWARDING PROFILE' <<<"$show_output"
    grep -q 'CURRENT BUSINESS PROFILE' <<<"$show_output"
    grep -q 'GROUP READY' <<<"$show_output"
    grep -q 'RECOMMENDED BACKUP' <<<"$show_output"
    grep -q 'HOT STANDBY COUNT' <<<"$show_output"
    grep -q 'Latest switch history' <<<"$show_output"
    grep -q 'Current group nftables rules' <<<"$show_output"

    verify_output="$(verify_nft_profiles_core 2>&1)"
    grep -q 'nftables profile verification' <<<"$verify_output"

    run_line_health_check() {
        local profile_id="$1" write_back="${2:-false}"
        load_profile_or_die "$profile_id"
        _IXTF_HEALTH_STATUS="${HEALTH_STATUS:-healthy}"
        _IXTF_HEALTH_REASON="fake monitor health"
        printf 'fake health ok\n'
        printf 'HEALTH_STATUS=%s\n' "$_IXTF_HEALTH_STATUS"
        printf 'LAST_HEALTH_REASON=%s\n' "$_IXTF_HEALTH_REASON"
        if [[ "$write_back" == "true" ]]; then
            LAST_HEALTH_CHECK_AT="$(utc_now)"
            LAST_HEALTH_REASON="$_IXTF_HEALTH_REASON"
            save_profile_env "$profile_id"
        fi
    }

    health_all >/dev/null 2>&1
    [[ -f "$HEALTH_HISTORY_FILE" ]]
    grep -q 'hk-primary' "$HEALTH_HISTORY_FILE"
    history_output="$(health_history --group hk-group --limit 5)"
    grep -q 'TIME' <<<"$history_output"

    notify_status_output="$(notify_status)"
    grep -q 'NOTIFY_ENABLED=false' <<<"$notify_status_output"
    grep -q 'TG_BOT_TOKEN=' <<<"$notify_status_output"
    grep -q 'NOTIFY_ENABLED=false' "$NOTIFY_ENV_FILE"
    chmod_mode="$(stat -c '%a' "$NOTIFY_ENV_FILE" 2>/dev/null || true)"
    [[ "$chmod_mode" == "600" || -z "$chmod_mode" ]]

    monitor_config_output="$(monitor_config)"
    grep -q 'monitor interval minutes: 5' <<<"$monitor_config_output"
    monitor_set_interval 7 >/dev/null 2>&1
    grep -q '^7$' "$MONITOR_INTERVAL_FILE"
    monitor_output="$(monitor_run_once 2>&1)"
    grep -q 'read-only' <<<"$monitor_output"
    [[ -f "$MONITOR_LAST_RUN_FILE" ]]
    monitor_status_output="$(monitor_status)"
    grep -q 'monitor timer：' <<<"$monitor_status_output"
    grep -q 'notify：' <<<"$monitor_status_output"
    grep -q 'health history：' <<<"$monitor_status_output"

    traffic_output="$(traffic_report --group hk-group)"
    grep -q 'PROFILE_ID' <<<"$traffic_output"
    grep -q 'hk-primary' <<<"$traffic_output"
    grep -q 'cloud billing traffic' <<<"$traffic_output"

    self_check_output="$(self_check 2>&1)"
    grep -q 'ix-transit-fabric self-check' <<<"$self_check_output"
    grep -q 'read-only' <<<"$self_check_output"
    grep -q 'install-netcat' <<<"$self_check_output"
    grep -q 'backup files' <<<"$self_check_output"

    backup_count_before="$(find "$BACKUP_DIR" -type f 2>/dev/null | wc -l)"
    load_profile hk-primary >/dev/null 2>&1
    HEALTH_STATUS=warning
    LAST_HEALTH_CHECK_AT="$(utc_now)"
    LAST_HEALTH_REASON="runtime writeback smoke"
    save_profile_runtime_state hk-primary
    backup_count_after="$(find "$BACKUP_DIR" -type f 2>/dev/null | wc -l)"
    [[ "$backup_count_before" == "$backup_count_after" ]]
    grep -q '^HEALTH_STATUS=warning$' "${PROFILES_DIR}/hk-primary.env"
    grep -q '^LAST_HEALTH_REASON=.*runtime writeback smoke' "${PROFILES_DIR}/hk-primary.env"

    diagnostic_path="$(export_diagnostic 2>/dev/null | tail -n 1)"
    [[ -s "$diagnostic_path" ]]
    ! grep -q 'change-me' "$diagnostic_path"
    rm -f -- "$diagnostic_path"

    cleanup_history --keep-health 10 --keep-switch 10 >/dev/null 2>&1
    cleanup_state >/dev/null 2>&1

    report_file="${unit_tmp}/health-report.txt"
    export_health_report --file "$report_file" >/dev/null 2>&1
    [[ -s "$report_file" ]]

    IXTF_ALLOW_INTERACTIVE=1 clear_switch_history <<<"CLEAR" >/dev/null 2>&1
    [[ "$(wc -l <"${STATE_DIR}/switch-history.tsv")" -eq 1 ]]
)

echo "smoke ok"
