#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -w "${TMPDIR:-/tmp}" ]]; then
    export TMPDIR="${ROOT_DIR}/.tmp"
    mkdir -p "$TMPDIR"
fi

bash -n install.sh
bash -n tests/smoke.sh

version_output="$(bash install.sh --version)"
[[ "$version_output" == "ix-transit-fabric 1.2.0-alpha.2" ]]
[[ "$(tr -d '\r\n' < VERSION)" == "1.2.0-alpha.2" ]]

bash install.sh --help >/dev/null

for token in \
    "转发规则管理" \
    "查看转发规则" \
    "新增转发规则" \
    "修改转发规则" \
    "启用转发规则" \
    "停止转发规则" \
    "删除转发规则" \
    "规则备注" \
    "虚拟网中转端口" \
    "EasyTier 组网协议" \
    "WebSocket" \
    "WebSocket TLS" \
    "QUIC" \
    "WireGuard" \
    "set-easytier-protocol" \
    "rules" \
    "code_schema" \
    "code_schema=3" \
    "rule-main" \
    "traffic-report --sample" \
    "latency-report" \
    "公网入口机侧指定" \
    "线路ID" \
    "当前机器是 NAT IX 中转机" \
    "当前机器是公网入口机" \
    "nft_rule_state_display" \
    "nftables 规则：" \
    "只读检查：不会切换线路" \
    "必需命令" \
    "运行状态" \
    "计数器只统计本项目转发规则命中的流量" \
    "latency_report_from_menu" \
    "resolve_profile_id_for_menu"; do
    grep -q -- "$token" install.sh
done

for token in \
    "多转发规则" \
    "多端口转发" \
    "备注" \
    "EasyTier 组网协议" \
    "1.1.0 单规则兼容" \
    "公网入口机重新导入接入码" \
    "alpha 注意事项" \
    "公网入口机侧指定"; do
    grep -q -- "$token" README.md
done

for forbidden in \
    'PROFILE_ID\tROLE\tGROUP' \
    "Note: nftables counter only counts" \
    "===== Profile " \
    "current host role" \
    "Required commands:" \
    "Runtime:" \
    "LOCAL_PORT -> LANDING_ET_IP:REMOTE_PORT"; do
    ! grep -qF -- "$forbidden" install.sh
done

for file in \
    examples/multi-rules.md \
    examples/nat-ix-listener.env \
    examples/public-ingress.env \
    examples/operations.md \
    examples/diagnostics.md; do
    [[ -f "$file" ]]
done

expected_examples="$(
    printf '%s\n' \
        README.md \
        diagnostics.md \
        multi-rules.md \
        nat-ix-listener.env \
        operations.md \
        public-ingress.env | sort
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
forbidden_reported_ip_pattern="$(printf '\061\061\064[.]\061\061\061|\070\067[.]\067\066|\070[.]\061\066\063|\070\071[.]\062\061\063|\061\060[.]\071\064|\061\067\070[.]\070\063|\061\060[.]\066\070|\061\060[.]\061\061\060|\061\060[.]\071\065|\061\060[.]\066\065|\061\060[.]\067\066')"

! grep -R -q "$forbidden_client_name" README.md install.sh tests examples CHANGELOG.md
! grep -R -q "$forbidden_real_code_prefix" README.md tests examples CHANGELOG.md
! grep -R -q "$forbidden_nft_reset" install.sh README.md tests examples CHANGELOG.md
! grep -R -q "$forbidden_pkill_rw" install.sh README.md tests examples CHANGELOG.md
! grep -R -q "$forbidden_pkill_et" install.sh README.md tests examples CHANGELOG.md
! grep -R -q "$forbidden_killall_rw" install.sh README.md tests examples CHANGELOG.md
! grep -R -q "$forbidden_killall_et" install.sh README.md tests examples CHANGELOG.md
! grep -R -q "$forbidden_tg_token" README.md tests examples CHANGELOG.md
! grep -R -E -q "$forbidden_tg_token_pattern" README.md tests examples CHANGELOG.md
! grep -R -E -q "$forbidden_reported_ip_pattern" README.md install.sh tests examples CHANGELOG.md

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
    RULES_DIR="${CONFIG_DIR}/rules"
    CODES_DIR="${CONFIG_DIR}/codes"
    STATE_DIR="${CONFIG_DIR}/state"
    BACKUP_DIR="$unit_tmp/backups"
    NFT_DIR="$unit_tmp/nft"
    NFT_FILE="${NFT_DIR}/ix-transit-fabric.nft"
    IXTF_TMPDIR="$unit_tmp/tmp"
    export IXTF_TMPDIR

    require_root() { :; }
    install_nftables() { :; }
    enable_ip_forward() { :; }
    ensure_systemctl() { :; }
    command_exists() {
        case "$1" in
            getent|nft|systemctl|ss|ip|ping|nc|ncat) return 1 ;;
            *) command -v "$1" >/dev/null 2>&1 ;;
        esac
    }
    is_port_in_use() { return 1; }

    ROLE=nat-transit
    NAT_DIRECTION=nat-listener
    PROFILE_ID=nat-listen
    PROFILE_NAME=nat-listen
    ENABLED=true
    FORWARD_ENABLED=true
    ET_NETWORK_NAME=ix-change-me
    ET_NETWORK_SECRET=change-me-secret
    ET_HOSTNAME=nat-ix.example
    ET_IPV4=10.88.0.2/24
    ET_SUBNET=10.88.0.0/24
    INGRESS_ET_IP=10.88.0.1
    INGRESS_ET_CIDR=10.88.0.1/24
    NAT_ET_IP=10.88.0.2
    NAT_ET_CIDR=10.88.0.2/24
    NAT_PUBLIC_HOST=nat-ix.example
    NAT_LISTENER_PROTO=both
    NAT_LISTENER_PROTOS="tcp udp"
    NAT_LISTENER_PORT=20000
    ET_LISTENER_PROTO=both
    ET_LISTENER_PORT=20000
    ET_LISTENERS="tcp://0.0.0.0:20000 udp://0.0.0.0:20000"
    ET_NO_LISTENER=false
    LOCAL_PORT=30000
    TRANSIT_PORT=40000
    LANDING_HOST=10.88.0.1
    LANDING_PORT=50000
    FORWARD_PROTO=both

    save_profile_env "$PROFILE_ID" >/dev/null

    RULE_ID=rule-game
    RULE_NOTE=game
    RULE_ENABLED=true
    CLIENT_PORT=
    TRANSIT_PORT=40001
    LANDING_HOST=10.88.0.1
    LANDING_PORT=50000
    FORWARD_PROTO=tcp
    save_rule_env "$PROFILE_ID" "$RULE_ID"

    nft_render="$unit_tmp/render.nft"
    render_nft_all_file "$nft_render" ix_test
    grep -q 'profile: nat-listen rule: rule-main' "$nft_render"
    grep -q 'profile: nat-listen rule: rule-game' "$nft_render"
    grep -q 'tcp dport 40000 counter dnat to 10.88.0.1:50000' "$nft_render"
    grep -q 'udp dport 40000 counter dnat to 10.88.0.1:50000' "$nft_render"
    grep -q 'tcp dport 40001 counter dnat to 10.88.0.1:50000' "$nft_render"

    code="$(generate_nat_code)"
    parse_nat_code "$code"
    [[ "$CODE_CODE_SCHEMA" == "3" ]]
    [[ "$CODE_RULE_COUNT" == "2" ]]
    grep -q 'rule-main' <<<"$CODE_RULES_TSV"
    grep -q 'rule-game' <<<"$CODE_RULES_TSV"

    resolved_latency="$(resolve_profile_id_for_menu latency-report "")"
    [[ "$resolved_latency" == "nat-listen" ]]
    [[ "$(rule_client_port_display)" == "公网入口机侧指定" ]]

    RULE_ENABLED=false
    save_rule_env "$PROFILE_ID" rule-game
    render_nft_all_file "$unit_tmp/render-disabled.nft" ix_test
    ! grep -q 'rule-game' "$unit_tmp/render-disabled.nft"

    rm -f -- "$(rule_env_path "$PROFILE_ID" rule-main)" "$(rule_env_path "$PROFILE_ID" rule-game)"
    [[ -d "$(profile_rules_dir "$PROFILE_ID")" ]]
    [[ -z "$(profile_rule_ids "$PROFILE_ID")" ]]
    ! load_rule "$PROFILE_ID" rule-main
    save_profile_env "$PROFILE_ID" >/dev/null
    [[ -z "$(profile_rule_ids "$PROFILE_ID")" ]]
    [[ ! -e "$(rule_env_path "$PROFILE_ID" rule-main)" ]]

    ROLE=nat-ingress
    NAT_DIRECTION=nat-listener
    PROFILE_ID=ing-a
    PROFILE_NAME=ing-a
    ENABLED=true
    FORWARD_ENABLED=true
    ET_NETWORK_NAME=ix-change-me-a
    ET_NETWORK_SECRET=change-me-secret-a
    ET_HOSTNAME=ing-a
    ET_IPV4=10.91.0.1/24
    ET_SUBNET=10.91.0.0/24
    INGRESS_ET_IP=10.91.0.1
    INGRESS_ET_CIDR=10.91.0.1/24
    NAT_ET_IP=10.91.0.2
    NAT_ET_CIDR=10.91.0.2/24
    NAT_PUBLIC_HOST=nat-a.example
    NAT_LISTENER_PROTO=both
    NAT_LISTENER_PROTOS="tcp udp"
    NAT_LISTENER_PORT=21000
    ET_PEERS="tcp://nat-a.example:21000 udp://nat-a.example:21000"
    ET_NO_LISTENER=true
    LOCAL_PORT=31000
    CLIENT_PORT=31000
    TRANSIT_PORT=41000
    LANDING_HOST=landing-a.example
    LANDING_PORT=51000
    FORWARD_PROTO=tcp
    save_profile_env "$PROFILE_ID" >/dev/null

    ROLE=nat-ingress
    NAT_DIRECTION=nat-listener
    PROFILE_ID=ing-b
    PROFILE_NAME=ing-b
    ENABLED=true
    FORWARD_ENABLED=true
    ET_NETWORK_NAME=ix-change-me-b
    ET_NETWORK_SECRET=change-me-secret-b
    ET_HOSTNAME=ing-b
    ET_IPV4=10.92.0.1/24
    ET_SUBNET=10.92.0.0/24
    INGRESS_ET_IP=10.92.0.1
    INGRESS_ET_CIDR=10.92.0.1/24
    NAT_ET_IP=10.92.0.2
    NAT_ET_CIDR=10.92.0.2/24
    NAT_PUBLIC_HOST=nat-b.example
    NAT_LISTENER_PROTO=both
    NAT_LISTENER_PROTOS="tcp udp"
    NAT_LISTENER_PORT=22000
    ET_PEERS="tcp://nat-b.example:22000 udp://nat-b.example:22000"
    ET_NO_LISTENER=true
    LOCAL_PORT=31001
    CLIENT_PORT=31001
    TRANSIT_PORT=41001
    LANDING_HOST=landing-b.example
    LANDING_PORT=51001
    FORWARD_PROTO=tcp
    save_profile_env "$PROFILE_ID" >/dev/null
    RULE_ID=rule-conflict
    RULE_NOTE=conflict
    RULE_ENABLED=true
    CLIENT_PORT=31000
    TRANSIT_PORT=41002
    LANDING_HOST=landing-b.example
    LANDING_PORT=51002
    FORWARD_PROTO=tcp
    save_rule_env "$PROFILE_ID" "$RULE_ID"
    set +e
    conflict_output="$(check_all_profiles_conflicts 2>&1)"
    conflict_rc=$?
    set -e
    [[ "$conflict_rc" -ne 0 ]]
    grep -q '31000' <<<"$conflict_output"
)

echo "smoke ok"
