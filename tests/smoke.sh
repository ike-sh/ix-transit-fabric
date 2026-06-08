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
[[ "$version_output" == "ix-transit-fabric 1.2.0-alpha.14" ]]
[[ "$(tr -d '\r\n' < VERSION)" == "1.2.0-alpha.14" ]]
bash install.sh --help >/dev/null
help_no_color="$(IXTF_COLOR=never bash install.sh --help)"
! grep -q $'\033' <<<"$help_no_color"

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
    "code_schema=4" \
    "NAT_PUBLIC_PORT" \
    "NAT_PUBLIC_PORTS" \
    "nat_public_port" \
    "rule-main" \
    "read_access_code_from_tty" \
    "IXTF1:" \
    "traffic-report --sample" \
    "latency-report" \
    "公网入口机侧指定" \
    "公网入口端口" \
    "完整路径" \
    "接入码包含规则" \
    "接入码包含" \
    "建议公网入口端口" \
    "回车即可确认" \
    "同步结果" \
    "新增规则" \
    "更新规则" \
    "停用规则" \
    "失败规则" \
    "规则数：" \
    "客户端连接：" \
    "转发路径：" \
    "IXTF_COLOR" \
    "NO_COLOR" \
    "IXTF_DEBUG" \
    "rule-main\" { main = 1" \
    "如果接入码已经出现在日志、截图、聊天记录或工单" \
    "不允许两条规则共用一个 CLIENT_PORT" \
    "不允许两条规则共用一个 TRANSIT_PORT" \
    "公网入口机侧指定 ->" \
    "当前线路：" \
    "当前转发规则：" \
    "请选择转发规则" \
    "请输入序号" \
    "无效选择，请输入列表中的序号" \
    "公网入口机不建议直接新增落地规则" \
    "NAT IX 机器新增转发规则" \
    "公网入口机需要重新导入接入码才能同步该规则" \
    "公网入口机需要重新导入新的接入码" \
    "已应用全部线路的 nftables 项目表" \
    "TCP/UDP" \
    "线路类型：" \
    "线路模式：" \
    "组网协议：" \
    "当前机器角色：" \
    "NAT IX 机器（生成接入码）" \
    "监控定时器" \
    "已停止，不参与转发" \
    "多规则，请查看转发规则" \
    "show-config PROFILE_ID" \
    "profiles/PROFILE_ID.env" \
    "当前没有线路" \
    "若只有一条线路，自动选择唯一线路" \
    "规则数" \
    "状态列表不显示主备角色" \
    "show_profile_from_menu" \
    "resolve_profile_id_for_menu" \
    "format_rules_for_show_config" \
    "print_config_summary_diagnostic" \
    "saved_nat_public" \
    "是否现在生成新的接入码" \
    "稍后可在\"转发规则管理 -> 刷新接入码\"中生成" \
    "nat_public_port_spec" \
    "导入未完全成功" \
    "EasyTier peer 未包含商家入口端口" \
    "正在写入配置..." \
    "正在应用转发规则..." \
    "正在重启 EasyTier..." \
    "verify_nat_ingress_import_consistency" \
    "verify_nat_transit_rule_consistency" \
    "print_easytier_endpoint_summary" \
    "nftables 转发规则校验" \
    "快速检查：bash install.sh diagnose" \
    "diagnose_profile" \
    "新增规则 ID" \
    "更新规则 ID" \
    "NAT IX 侧 listener 已更新" \
    "prompt_refresh_access_code_after_rule_change"; do
    grep -q -- "$token" install.sh
done

for token in \
    "多转发规则" \
    "多端口转发" \
    "备注" \
    "EasyTier 组网协议" \
    "1.1.0 单规则兼容" \
    "公网入口机重新导入接入码" \
    "转发规则管理" \
    "alpha 注意事项" \
    "公网入口机侧指定" \
    "1.2.0-alpha.14" \
    "IXTF_COLOR=never"; do
    grep -q -- "$token" README.md
done

for forbidden in \
    "当前角色：nat-transit" \
    "线路角色：standalone" \
    "ENABLED=true FORWARD_ENABLED=true" \
    "(both, 启用)" \
    "not-found，active=inactive" \
    "current host role" \
    "Required commands:" \
    "Runtime:" \
    "===== ""Profile " \
    "已应用全部 ""Profile"" 的 nftables 项目表" \
    "(""both"")" \
    "公网入口机""生成接入码" \
    "模式 ""A" \
    "模式 ""B" \
    'PROFILE_ID\tROLE\tGROUP' \
    'Created symlink' \
    'log_ok "已开启 IPv4 转发' \
    'log_ok "已重启 Profile 服务' \
    'saved_nat_public: unbound variable' \
    'nat_public_ports="18301,18302,18303,18304"'; do
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
forbidden_reported_ip_pattern="$(printf '\061\061\064[.]\061\061\061|\070\067[.]\067\066|\070[.]\061\066\063|\070\071[.]\062\061\063|\061\060[.]\071\064|\061\067\070[.]\070\063|\061\060[.]\066\070|\061\060[.]\061\061\060|\061\060[.]\071\065|\061\060[.]\066\065|\061\060[.]\067\066|\061\060[.]\061\060\067|\061\060[.]\061\061\066')"

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

    IXTF_COLOR=never
    unset NO_COLOR
    color_init
    [[ "$(c_red test)" == "test" ]]
    IXTF_COLOR=always
    color_init
    [[ "$(c_green ok)" == $'\033[32mok\033[0m' ]]
    NO_COLOR=1
    color_init
    [[ "$(c_yellow warn)" == "warn" ]]
    IXTF_COLOR=never
    unset NO_COLOR
    color_init

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
    NAT_PUBLIC_PORTS=20000,20001,20002
    NAT_PUBLIC_PORT_MODE=list
    NAT_LISTENER_PROTO=both
    NAT_LISTENER_PROTOS="tcp udp"
    NAT_LISTENER_PORT=20000
    ET_LISTENER_PROTO=both
    ET_LISTENER_PORT=20000
    ET_LISTENERS="tcp://0.0.0.0:20000 udp://0.0.0.0:20000"
    ET_NO_LISTENER=false
    LOCAL_PORT=
    TRANSIT_PORT=40000
    LANDING_HOST=10.88.0.1
    LANDING_PORT=50000
    FORWARD_PROTO=both

    save_profile_env "$PROFILE_ID" >/dev/null

    RULE_ID=rule-game
    RULE_NOTE=game
    RULE_ENABLED=true
    CLIENT_PORT=
    NAT_PUBLIC_PORT=20001
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
    grep -q 'tcp dport 40001 counter dnat to 10.88.0.1:50000' "$nft_render"

    code="$(generate_nat_code)"
    [[ "$(extract_landing_code "  ${code}  ")" == "$code" ]]
    [[ "$(extract_landing_code "$(printf '提示文本 %s\r\n' "$code")")" == "$code" ]]
    wrapped_code="${code:0:40}"$'\r\n'"${code:40}"
    [[ "$(extract_landing_code "$wrapped_code")" == "$code" ]]
    parse_nat_code "$code"
    [[ "$CODE_CODE_SCHEMA" == "4" ]]
    [[ "$CODE_RULE_COUNT" == "2" ]]
    grep -q $'rule-main\t默认转发\ttrue\t20000\t40000' <<<"$CODE_RULES_TSV"
    grep -q $'rule-game\tgame\ttrue\t20001\t40001' <<<"$CODE_RULES_TSV"

    resolved_latency="$(resolve_profile_id_for_menu latency-report "")"
    [[ "$resolved_latency" == "nat-listen" ]]
    [[ "$(rule_client_port_display)" == "公网入口机侧指定" ]]

    config_output="$(print_config_summary loaded)"
    grep -q '线路类型：NAT IX 中转线路' <<<"$config_output"
    grep -q '组网协议：TCP/UDP' <<<"$config_output"
    ! grep -q 'ENABLED=true' <<<"$config_output"
    ! grep -q 'nat-transit' <<<"$config_output"
    cli_config_output="$(show_config "$PROFILE_ID")"
    menu_config_output="$(show_profile "$PROFILE_ID")"
    [[ "$cli_config_output" == "$menu_config_output" ]]
    ! grep -q '配置文件：未找到' <<<"$cli_config_output"
    ! grep -q '没有可显示的已保存配置' <<<"$cli_config_output"
    ! grep -q '主备角色' <<<"$cli_config_output"
    ! grep -q 'standalone' <<<"$cli_config_output"

    status_output="$(status_all)"
    grep -q $'线路ID\t角色\t启用\t转发\t服务\t健康\t规则数\t最近检查' <<<"$status_output"
    grep -q $'nat-listen\tNAT IX 中转线路\t启用\t转发中\t未知\t未检查\t2\t-' <<<"$status_output"
    grep -q '汇总：线路总数=1 启用=1 转发中=1 健康=0 警告=0 故障=0 未检查=1' <<<"$status_output"
    ! grep -q '主备角色' <<<"$status_output"
    ! grep -q 'standalone' <<<"$status_output"

    selected_rule_profile="$(select_profile_for_rule_menu)"
    [[ "$selected_rule_profile" == "nat-listen" ]]
    [[ "$(rule_id_by_number "$PROFILE_ID" 1)" == "rule-main" ]]
    [[ "$(rule_id_by_number "$PROFILE_ID" 02)" == "rule-game" ]]
    ! rule_id_by_number "$PROFILE_ID" 0 >/dev/null
    rule_menu_output="$({
        print_rule_menu_header "$PROFILE_ID"
        print_rule_menu_rules "$PROFILE_ID"
    } 2>&1)"
    grep -q '当前线路：nat-listen（NAT IX 中转线路）' <<<"$rule_menu_output"
    grep -q '当前转发规则：' <<<"$rule_menu_output"
    grep -Eq '^[0-9]+[.] rule-main  启用  \[默认转发\]' <<<"$rule_menu_output"
    grep -Eq '^[0-9]+[.] rule-game  启用  \[game\]' <<<"$rule_menu_output"
    grep -q '公网入口端口：公网入口机侧指定' <<<"$rule_menu_output"
    grep -q '商家入口端口：20001' <<<"$rule_menu_output"
    grep -q '虚拟网中转端口：40001' <<<"$rule_menu_output"
    grep -q '落地目标：10.88.0.1:50000' <<<"$rule_menu_output"
    grep -q '完整路径：公网入口机侧指定 -> nat-ix.example:20001 -> 10.88.0.2:40001 -> 10.88.0.1:50000' <<<"$rule_menu_output"
    grep -q '协议：TCP' <<<"$rule_menu_output"
    ! grep -q "请输入线路 ""ID（留空时自动选择唯一线路）" <<<"$rule_menu_output"
    ! grep -q 'PROFILE_ID 格式不正确：2' <<<"$rule_menu_output"
    ! grep -q "无法读取 ""Profile：" <<<"$rule_menu_output"

    rule_choice_output="$(print_rule_choice_list "$PROFILE_ID" 2>&1)"
    grep -q '请选择转发规则' <<<"$rule_choice_output"
    grep -Eq '^[0-9]+[.] rule-main  启用  \[默认转发\]' <<<"$rule_choice_output"

    code_summary="$(format_rules_for_code_summary "$PROFILE_ID")"
    grep -q '（TCP/UDP）' <<<"$code_summary"
    ! grep -q "(""both"")" <<<"$code_summary"

    apply_nft_all() { render_nft_all_file "$NFT_FILE" ix_test >/dev/null; }
    RULE_ID=rule-dda8
    RULE_NOTE=test
    RULE_ENABLED=true
    NAT_PUBLIC_PORT=20002
    TRANSIT_PORT=40002
    LANDING_HOST=landing-new.example
    LANDING_PORT=52000
    FORWARD_PROTO=both
    save_rule_env "$PROFILE_ID" "$RULE_ID"
    load_rule "$PROFILE_ID" rule-dda8
    [[ "$RULE_NOTE" == "test" ]]
    [[ "$LANDING_HOST" == "landing-new.example" ]]
    [[ "$LANDING_PORT" == "52000" ]]
    [[ "$NAT_PUBLIC_PORT" == "20002" ]]
    [[ "$TRANSIT_PORT" != "40000" ]]
    [[ "$TRANSIT_PORT" != "40001" ]]

    code_after_add="$(generate_nat_code)"
    parse_nat_code "$code_after_add"
    [[ "$CODE_CODE_SCHEMA" == "4" ]]
    [[ "$CODE_RULE_COUNT" == "3" ]]
    grep -q $'rule-dda8\ttest\ttrue\t20002\t' <<<"$CODE_RULES_TSV"
    grep -q '"nat_public_port":20002' <<<"$(base64url_decode "${code_after_add#IXTF1:}")"
    [[ "$(base64url_decode "$CODE_RULES_B64")" == "$CODE_RULES_TSV" ]]

    NAT_PUBLIC_PORT_SPEC="18301-18399"
    NAT_PUBLIC_PORT_MODE="range"
    NAT_PUBLIC_PORTS="$(normalize_nat_public_ports_input "$NAT_PUBLIC_PORT_SPEC")"
    NAT_LISTENER_PORT="$(first_nat_public_port "$NAT_PUBLIC_PORTS")"
    save_profile_env "$PROFILE_ID" >/dev/null
    range_code="$(generate_nat_code)"
    ! grep -q '"nat_public_ports":"18301,18302,18303' <<<"$(base64url_decode "${range_code#IXTF1:}")"
    grep -q '"nat_public_port_spec":"18301-18399"' <<<"$(base64url_decode "${range_code#IXTF1:}")"
    grep -q '"nat_public_port":20001' <<<"$(base64url_decode "${range_code#IXTF1:}")"

    value="18301-18399"
    normalized="$(normalize_nat_public_ports_input "$value")"
    PROMPT_NAT_PUBLIC_PORT_RAW="$value"
    PROMPT_NAT_PUBLIC_PORT_MODE="$(nat_public_port_mode_for_input "$value")"
    PROMPT_NAT_PUBLIC_PORTS_NORMALIZED="$normalized"
    spec_from_prompt="${PROMPT_NAT_PUBLIC_PORT_RAW:-$PROMPT_NAT_PUBLIC_PORTS_NORMALIZED}"
    [[ "$spec_from_prompt" == "18301-18399" ]]
    [[ "$PROMPT_NAT_PUBLIC_PORT_MODE" == "range" ]]

    CODE_NAT_LISTENER_PORT=29999
    CODE_RULES_TSV=$'rule-old\told\ttrue\t49999\told.example\t59999\ttcp'
    validate_code_rules_tsv
    [[ "$CODE_RULES_COMPAT_NAT_PORT" == "true" ]]
    grep -q $'rule-old\told\ttrue\t29999\t49999\told.example\t59999\ttcp' <<<"$CODE_RULES_TSV"
    parse_nat_code "$code_after_add"

    ROLE=nat-ingress
    NAT_DIRECTION=nat-listener
    PROFILE_ID=ing-sync
    PROFILE_NAME=ing-sync
    ENABLED=true
    FORWARD_ENABLED=true
    ET_NETWORK_NAME="$CODE_NETWORK_NAME"
    ET_NETWORK_SECRET="$CODE_NETWORK_SECRET"
    ET_HOSTNAME=ing-sync
    ET_IPV4="$CODE_INGRESS_ET_CIDR"
    ET_SUBNET="$(cidr_network24 "$ET_IPV4")"
    INGRESS_ET_IP="$CODE_INGRESS_ET_IP"
    INGRESS_ET_CIDR="$CODE_INGRESS_ET_CIDR"
    NAT_ET_IP="$CODE_NAT_ET_IP"
    NAT_ET_CIDR="$CODE_NAT_ET_CIDR"
    NAT_PUBLIC_HOST="$CODE_NAT_PUBLIC_HOST"
    NAT_PUBLIC_PORTS="$CODE_NAT_PUBLIC_PORTS"
    NAT_PUBLIC_PORT_MODE="$CODE_NAT_PUBLIC_PORT_MODE"
    NAT_LISTENER_PROTO="$CODE_NAT_LISTENER_PROTO"
    NAT_LISTENER_PROTOS="$CODE_NAT_LISTENER_PROTOS"
    NAT_LISTENER_PORT="$CODE_NAT_LISTENER_PORT"
    REMOTE_NAT_PROFILE_ID="$CODE_PROFILE_ID"
    REMOTE_NAT_PUBLIC_HOST="$CODE_NAT_PUBLIC_HOST"
    ET_NO_LISTENER=true
    save_profile_env "$PROFILE_ID" >/dev/null
    RULE_ID=rule-main; RULE_NOTE=默认转发; RULE_ENABLED=true; CLIENT_PORT=31010; NAT_PUBLIC_PORT=20000; TRANSIT_PORT=40000; LANDING_HOST=10.88.0.1; LANDING_PORT=50000; FORWARD_PROTO=both; save_rule_env "$PROFILE_ID" rule-main
    RULE_ID=rule-dda8; RULE_NOTE=test; RULE_ENABLED=true; CLIENT_PORT=31011; NAT_PUBLIC_PORT=20002; TRANSIT_PORT=40002; LANDING_HOST=landing-new.example; LANDING_PORT=52000; FORWARD_PROTO=both; save_rule_env "$PROFILE_ID" rule-dda8
    RULE_ID=rule-game; RULE_NOTE=game; RULE_ENABLED=true; CLIENT_PORT=31012; NAT_PUBLIC_PORT=20001; TRANSIT_PORT=40001; LANDING_HOST=10.88.0.1; LANDING_PORT=50000; FORWARD_PROTO=tcp; save_rule_env "$PROFILE_ID" rule-game
    load_profile_or_die "$PROFILE_ID"
    refresh_nat_public_endpoints_for_profile "$PROFILE_ID"
    save_profile_env "$PROFILE_ID" >/dev/null
    load_rule "$PROFILE_ID" rule-main
    [[ "$CLIENT_PORT" == "31010" ]]
    [[ "$NAT_PUBLIC_PORT" == "20000" ]]
    main_transit="$TRANSIT_PORT"
    load_rule "$PROFILE_ID" rule-dda8
    [[ "$CLIENT_PORT" == "31011" ]]
    [[ "$NAT_PUBLIC_PORT" == "20002" ]]
    dda8_transit="$TRANSIT_PORT"
    load_rule "$PROFILE_ID" rule-game
    [[ "$CLIENT_PORT" == "31012" ]]
    [[ "$NAT_PUBLIC_PORT" == "20001" ]]
    game_transit="$TRANSIT_PORT"
    load_profile "$PROFILE_ID" >/dev/null
    grep -q 'nat-ix.example:20000' <<<"$ET_PEERS"
    grep -q 'nat-ix.example:20001' <<<"$ET_PEERS"
    grep -q 'nat-ix.example:20002' <<<"$ET_PEERS"
    grep -q 'nat-ix.example:20000' <<<"$ET_MAPPED_LISTENERS"
    grep -q 'nat-ix.example:20001' <<<"$ET_MAPPED_LISTENERS"
    grep -q 'nat-ix.example:20002' <<<"$ET_MAPPED_LISTENERS"
    verify_nat_transit_rule_consistency "$PROFILE_ID" >/dev/null
    saved_nat_public="${NAT_PUBLIC_PORT:-}"
    RULE_ID=rule-main
    print_nat_ingress_import_complete_summary ing-sync >/dev/null
    [[ "${NAT_PUBLIC_PORT:-}" == "${saved_nat_public:-}" ]]
    spec_rules_b64="$(printf '%s' $'rule-main\tmain\ttrue\t20000\t40000\t10.88.0.1\t50000\tboth\nrule-game\tgame\ttrue\t20001\t40001\t10.88.0.1\t50000\ttcp' | base64url_encode)"
    spec_only_json="$(printf '{"version":3,"code_schema":4,"mode":"nat-transit","direction":"nat-listener","role":"nat-listener-code","profile_id":"nat-listen","profile_name":"nat-listen","network_name":"ix-change-me","network_secret":"change-me-secret","nat_hostname":"nat-ix.example","nat_public_host":"nat-ix.example","nat_public_port_spec":"18301-18399","nat_public_port_mode":"range","nat_listener_port":20000,"nat_listener_proto":"both","nat_listener_protos":["tcp","udp"],"nat_et_ip":"10.88.0.2","nat_et_cidr":"10.88.0.2/24","ingress_et_ip":"10.88.0.1","ingress_et_cidr":"10.88.0.1/24","transit_port":40000,"landing_host":"10.88.0.1","landing_port":50000,"forward_proto":"both","rules":[{"rule_id":"rule-main","note":"main","enabled":true,"nat_public_port":20000,"transit_port":40000,"landing_host":"10.88.0.1","landing_port":50000,"forward_proto":"both"},{"rule_id":"rule-game","note":"game","enabled":true,"nat_public_port":20001,"transit_port":40001,"landing_host":"10.88.0.1","landing_port":50000,"forward_proto":"tcp"}],"rules_b64":"%s","created_at":"2026-01-01T00:00:00Z"}' "$spec_rules_b64")"
    parse_nat_code "$(printf 'IXTF1:%s' "$(base64url_encode "$spec_only_json")")"
    [[ "$CODE_NAT_PUBLIC_PORTS" == "20000,20001" ]]
    parse_nat_code "$code_after_add"
    [[ "$(find_existing_nat_ingress_profile_for_code)" == "ing-sync" ]]
    [[ "$dda8_transit" != "$game_transit" ]]
    [[ "$dda8_transit" != "$main_transit" ]]
    render_nft_all_file "$unit_tmp/render-ingress.nft" ix_test
    grep -q "tcp dport 31010 counter dnat to 10.88.0.2:${main_transit}" "$unit_tmp/render-ingress.nft"
    grep -q "tcp dport 31011 counter dnat to 10.88.0.2:${dda8_transit}" "$unit_tmp/render-ingress.nft"
    grep -q "tcp dport 31012 counter dnat to 10.88.0.2:${game_transit}" "$unit_tmp/render-ingress.nft"

    parse_nat_code "$code_after_add"
    ROLE=nat-ingress
    NAT_DIRECTION=nat-listener
    PROFILE_ID=ing-sync
    PROFILE_NAME=ing-sync
    ENABLED=true
    FORWARD_ENABLED=true
    load_rule "$PROFILE_ID" rule-main
    [[ "$CLIENT_PORT" == "31010" ]]
    [[ "$NAT_PUBLIC_PORT" == "20000" ]]
    load_rule "$PROFILE_ID" rule-dda8
    [[ "$CLIENT_PORT" == "31011" ]]
    [[ "$NAT_PUBLIC_PORT" == "20002" ]]
    load_rule "$PROFILE_ID" rule-game
    [[ "$CLIENT_PORT" == "31012" ]]
    [[ "$NAT_PUBLIC_PORT" == "20001" ]]

    load_profile nat-listen
    load_rule nat-listen rule-game
    RULE_ENABLED=false
    save_rule_env "$PROFILE_ID" rule-game
    render_nft_all_file "$unit_tmp/render-disabled.nft" ix_test
    ! grep -q 'profile: nat-listen rule: rule-game' "$unit_tmp/render-disabled.nft"
    grep -q 'profile: ing-sync rule: rule-game' "$unit_tmp/render-disabled.nft"

    health_out="$(print_forward_rule_health_summary nat-listen)"
    grep -q '已停止，不参与转发' <<<"$health_out"

    rm -f -- "$(rule_env_path "$PROFILE_ID" rule-main)" "$(rule_env_path "$PROFILE_ID" rule-game)" "$(rule_env_path "$PROFILE_ID" rule-dda8)"
    save_profile_env "$PROFILE_ID" >/dev/null

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
    set +e
    conflict_output="$(save_rule_env "$PROFILE_ID" "$RULE_ID" 2>&1)"
    conflict_rc=$?
    set -e
    [[ "$conflict_rc" -ne 0 ]]
    grep -q '端口 31000 已被线路 ing-a 的规则 rule-main' <<<"$conflict_output"

    ROLE=nat-transit
    NAT_DIRECTION=nat-listener
    PROFILE_ID=nat-a
    PROFILE_NAME=nat-a
    ENABLED=true
    FORWARD_ENABLED=true
    ET_NETWORK_NAME=ix-change-me-ta
    ET_NETWORK_SECRET=change-me-secret-ta
    ET_HOSTNAME=nat-a
    ET_IPV4=10.93.0.2/24
    ET_SUBNET=10.93.0.0/24
    INGRESS_ET_IP=10.93.0.1
    INGRESS_ET_CIDR=10.93.0.1/24
    NAT_ET_IP=10.93.0.2
    NAT_ET_CIDR=10.93.0.2/24
    NAT_PUBLIC_HOST=nat-ta.example
    NAT_LISTENER_PROTO=both
    NAT_LISTENER_PROTOS="tcp udp"
    NAT_LISTENER_PORT=23000
    ET_LISTENER_PROTO=both
    ET_LISTENER_PORT=23000
    ET_LISTENERS="tcp://0.0.0.0:23000 udp://0.0.0.0:23000"
    ET_PEERS=
    ET_NO_LISTENER=false
    LOCAL_PORT=
    CLIENT_PORT=
    TRANSIT_PORT=41000
    LANDING_HOST=landing-ta.example
    LANDING_PORT=52000
    FORWARD_PROTO=tcp
    save_profile_env "$PROFILE_ID" >/dev/null

    ROLE=nat-transit
    NAT_DIRECTION=nat-listener
    PROFILE_ID=nat-b
    PROFILE_NAME=nat-b
    ENABLED=true
    FORWARD_ENABLED=true
    ET_NETWORK_NAME=ix-change-me-tb
    ET_NETWORK_SECRET=change-me-secret-tb
    ET_HOSTNAME=nat-b
    ET_IPV4=10.96.0.2/24
    ET_SUBNET=10.96.0.0/24
    INGRESS_ET_IP=10.96.0.1
    INGRESS_ET_CIDR=10.96.0.1/24
    NAT_ET_IP=10.96.0.2
    NAT_ET_CIDR=10.96.0.2/24
    NAT_PUBLIC_HOST=nat-tb.example
    NAT_LISTENER_PROTO=both
    NAT_LISTENER_PROTOS="tcp udp"
    NAT_LISTENER_PORT=24000
    ET_LISTENER_PROTO=both
    ET_LISTENER_PORT=24000
    ET_LISTENERS="tcp://0.0.0.0:24000 udp://0.0.0.0:24000"
    ET_PEERS=
    ET_NO_LISTENER=false
    LOCAL_PORT=
    CLIENT_PORT=
    TRANSIT_PORT=41003
    LANDING_HOST=landing-tb.example
    LANDING_PORT=52001
    FORWARD_PROTO=tcp
    save_profile_env "$PROFILE_ID" >/dev/null

    RULE_ID=rule-transit-conflict
    RULE_NOTE=transit-conflict
    RULE_ENABLED=true
    CLIENT_PORT=
    TRANSIT_PORT=41000
    LANDING_HOST=landing-tb.example
    LANDING_PORT=52002
    FORWARD_PROTO=tcp
    set +e
    transit_conflict_output="$(save_rule_env "$PROFILE_ID" "$RULE_ID" 2>&1)"
    transit_conflict_rc=$?
    set -e
    [[ "$transit_conflict_rc" -ne 0 ]]
    grep -q '端口 41000 已被线路 nat-a 的规则 rule-main' <<<"$transit_conflict_output"
)

echo "smoke ok"
