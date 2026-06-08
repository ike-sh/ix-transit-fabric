# ix-transit-fabric

当前版本：`1.2.0-alpha.16`

`ix-transit-fabric` 用于管理 NAT-IX 中转线路：公网入口机接收客户端连接，通过 EasyTier 连接 NAT IX 机器，NAT IX 机器再用 nftables 转发到落地机业务端口。

脚本只负责 EasyTier 组网、线路配置、项目 nftables 规则、转发规则管理、健康检查、延迟诊断和流量命中统计。它不安装代理服务，不配置 Remnawave / Xray / sing-box，不接管全局 nftables，不清空全局规则集，不全局结束 `rw-core` / `easytier-core`，不自动切换线路，不自动修复配置。

## 适用场景

- 商家给了 NAT/IX 入口地址和入口端口。
- 你有一台公网入口机、一台 NAT IX 机器，以及一个或多个落地机业务服务。
- 客户端最终连接公网入口机。
- NAT IX 机器只做 EasyTier listener 和 nftables 中转。

## 兼容说明（panel 旧模式）

`panel-landing` / `panel-ingress` 为 **CNIX 面板时代遗留路径**，新部署请只用主菜单的 **NAT IX 中转线路 + 公网入口机导入接入码**。旧模式 CLI（如 `install-panel-landing`）仍保留兼容，但不再推荐，后续版本可能移除。

## 架构图

```text
客户端
  -> 公网入口机公网 IP:客户端入口端口
  -> 公网入口机 nftables
  -> 商家 NAT/IX 入口地址:商家入口端口
  -> EasyTier 虚拟网
  -> NAT IX 虚拟 IP:虚拟网中转端口
  -> NAT IX 机器 nftables
  -> 落地机地址:落地业务端口
```

## 一行安装

```bash
curl -fsSL -o install.sh https://raw.githubusercontent.com/ike-sh/ix-transit-fabric/main/install.sh && bash install.sh
```

安装或更新 EasyTier：

```bash
bash install.sh install-easytier
```

如果 GitHub 下载慢，可以指定版本或下载地址：

```bash
IXTF_EASYTIER_VERSION=v2.6.4 bash install.sh install-easytier
IXTF_EASYTIER_DOWNLOAD_URL=https://example.com/easytier.tar.gz bash install.sh install-easytier
```

## 快速开始

1. 在 NAT IX 机器创建中转线路：

```bash
bash install.sh
```

菜单选择：

```text
创建 NAT IX 中转线路
```

2. 在公网入口机导入接入码：

```bash
bash install.sh
```

菜单选择：

```text
公网入口机导入接入码
```

3. 客户端连接公网入口机端口：

```text
公网入口机公网 IP:客户端入口端口
```

## 多转发规则 / 多端口转发

每条线路可以配置多转发规则，用于把多个客户端入口端口转发到不同的落地目标。每条规则都是独立路径：

```text
公网入口端口 -> 商家 NAT/IX 入口地址:商家入口端口 -> NAT IX 虚拟 IP:虚拟网中转端口 -> 落地目标
```

示例：

```text
规则 A：
37593 -> nat.example:20000 -> 10.88.0.2:58603 -> landing-a.example:443

规则 B：
37594 -> nat.example:20001 -> 10.88.0.2:58768 -> landing-b.example:8443
```

1. 在 NAT IX 机器新增转发规则。
2. 刷新接入码。
3. 在公网入口机重新导入接入码。
4. 为每条启用规则指定独立客户端入口端口。
5. 查看转发规则列表和流量统计。

常用命令：

```bash
bash install.sh list-rules 线路ID
bash install.sh add-rule 线路ID
bash install.sh edit-rule 线路ID 规则ID
bash install.sh enable-rule 线路ID 规则ID
bash install.sh disable-rule 线路ID 规则ID
bash install.sh delete-rule 线路ID 规则ID
bash install.sh refresh-code 线路ID
bash install.sh apply-rules 线路ID
```

每条转发规则包含规则 ID、备注、启用状态、客户端入口端口、商家入口端口、虚拟网中转端口、落地机地址、落地业务端口和转发协议。NAT IX 机器创建线路时可输入单个商家入口端口、端口段或逗号列表；`rule-main` 使用第一个端口，新增规则自动使用下一个未占用端口。NAT IX 机器新增落地规则并刷新接入码；公网入口机重新导入接入码时，会逐条显示远端规则，并按 `rule_id` 更新本地规则。公网入口机必须为每条启用规则指定独立客户端入口端口，不允许端口复用；同 `rule_id` 重新导入时默认保留原客户端入口端口。端口冲突会显示占用规则；停用规则不转发。远端已删除的规则默认提示停用本地对应规则，不会自动删除。删除规则后需要刷新接入码并重新导入。

## 转发规则管理

进入转发规则管理后，脚本会自动选择唯一线路；多线路时用数字选择线路。选中线路后，页面顶部会以 1、2、3 编号显示每条规则，并突出备注、状态、客户端入口端口、虚拟网中转端口、落地目标和协议。

修改、启用、停止和删除规则都通过数字选择规则，也支持输入规则 ID 作为高级方式。NAT IX 机器负责新增或修改落地目标；公网入口机负责导入接入码并为远端规则指定客户端入口端口。

新增、删除、停用或修改影响公网入口机的规则后，脚本会询问是否立即刷新接入码；也可稍后在「转发规则管理 -> 刷新接入码」中生成，并让公网入口机重新导入。

接入码不再携带完整展开的 `NAT_PUBLIC_PORTS` 端口池，只包含每条规则实际使用的 `nat_public_port`；端口段以 `nat_public_port_spec` 保留规格说明。

普通创建/导入输出已进一步精简，sysctl / systemd symlink 等详细输出仅在 `IXTF_DEBUG=true` 或 `--debug` 时显示。

如果导入后出现规则数不一致或转发未生效，可运行 `bash install.sh export-diagnostic` 导出脱敏诊断。

## EasyTier 组网协议

创建 NAT IX 中转线路时可以选择 EasyTier 组网协议：

- TCP/UDP（推荐）
- UDP
- TCP
- WebSocket
- WebSocket TLS
- QUIC
- WireGuard
- ALL

后续修改：

```bash
bash install.sh set-easytier-protocol 线路ID
```

如果高延迟或丢包，建议新建测试线路对比 UDP / TCP / TCP/UDP，不建议直接覆盖生产线路。两端协议需要一致时，请刷新接入码并在对端重新导入。

## 接入码

NAT IX 接入码 v4 使用 `code_schema=4`，每条 `rules` 规则包含独立 `nat_public_port`。v3 旧接入码仍继续支持，缺少 `nat_public_port` 时会使用顶层 `nat_listener_port` 兼容；v2 旧接入码仍会兼容成单条 `rule-main`。

粘贴接入码时可以带前后空格、CRLF 换行或提示文字，脚本会自动清理并提取第一个 `IXTF1:` token。公网入口机导入推荐模式接入码时会先显示完整规则表、商家入口端口和建议公网入口端口；每条规则必须使用独立公网入口端口。

安全提醒：

```text
接入码包含 EasyTier 组网密钥，不要发到聊天记录、工单、截图或公开日志；如果接入码已经出现在日志、截图、聊天记录或工单，请正式使用前刷新接入码。
```

## 输出与颜色

普通创建和导入完成摘要已精简，只保留客户端连接、转发路径、简短状态和下一步。详细健康检查、nftables 校验、systemd 详情和排障命令请使用 `health`、`show-port-map`、`export-diagnostic` 或 `doctor`。

脚本默认仅在 TTY 输出颜色。可设置 `IXTF_COLOR=never` 禁用颜色；`NO_COLOR=1` 也会禁用颜色。需要完整过程输出时可设置 `IXTF_DEBUG=true` 或使用 `--debug`。

## 1.1.0 单规则兼容

1.1.0 的单转发配置会自动兼容为一条默认转发规则 `rule-main`，备注为“默认转发”。旧 profile 中的 `LOCAL_PORT / TRANSIT_PORT / LANDING_HOST / LANDING_PORT / FORWARD_PROTO` 会在运行时映射为默认规则，不会让升级后的单规则用户断链。

## alpha 注意事项

- `1.2.0-alpha.16` 主备 runbook / show-group / health-report 汇总中文化；README 标注 panel 旧模式 deprecated。
- `1.2.0-alpha.15` doctor-all / export-diagnostic / 主备校验输出全面中文化。
- `1.2.0-alpha.14` 新增 `diagnose` 一键诊断；health 逐规则检查商家入口；导入同步展示规则 ID diff。
- `1.2.0-alpha.13` 增强 show-easytier-status 诊断输出；verify-nft-profiles 中文化；NAT IX 规则一致性检查；导入/增规则摘要附带诊断命令。
- `1.2.0-alpha.12` 修复 NAT IX 多 listener 未宣告 `--mapped-listeners` 导致第二条及后续转发不通；规则变更后自动重启 EasyTier 并等待就绪；端口段 prompt 不再打印完整展开列表。
- `1.2.0-alpha.11` 修复公网入口机重复导入接入码时 EasyTier 未重启导致多规则不通；规则变更刷新接入码不再无谓轮换组网密钥；修复端口段 spec 在子 shell 中丢失。
- `1.2.0-alpha.10` 修复端口遍历上下文遗漏 `NAT_PUBLIC_PORT`；导入一致性检查仅校验接入码内规则；清理死代码与重复刷新提示。
- `1.2.0-alpha.9` 修复公网入口机导入后 `saved_nat_public` 未定义报错；新增/修改/启用/停止/删除规则后可立即生成接入码；接入码不再携带完整展开的端口池；普通输出进一步精简；导入后增加规则数、nftables 和 EasyTier peer 一致性检查。
- `1.2.0-alpha.8` 为每条规则增加独立商家入口端口，接入码升级到 `code_schema=4`，并修复重复导入同一 NAT IX 接入码造成新建冲突线路的问题。
- `1.2.0-alpha.7` 修复接入码空白输入、多规则导入保存、同 `rule_id` 端口冲突误判、普通摘要过长和关键提示颜色。
- `1.2.0-alpha.6` 修复多规则独立端口映射、接入码逐条同步和新增规则摘要。
- `1.2.0-alpha.5` 将转发规则管理改为先选线路、再用数字管理规则。
- `1.2.0-alpha.4` 修复 `show-config PROFILE_ID` 直接命令仍走旧配置的问题，并统一状态输出。
- `1.1.0` 仍是稳定正式版。
- 多规则功能需要先实机验证。
- 多规则修改后，NAT IX 机器需要刷新接入码，公网入口机需要重新导入。
- 客户端入口端口只在公网入口机侧指定；NAT IX 机器规则列表会显示“公网入口机侧指定”。
- 商家入口端口是 NAT IX 机器 EasyTier listener / 公网入口机 EasyTier peer 使用的公网入口端口；多规则推荐为每条启用规则分配独立商家入口端口。
- 虚拟网中转端口只在 EasyTier 虚拟网内部使用，不是公网端口。
- 停用规则不会删除配置；删除规则需要二次确认。
- 高级配置显示已中文化，但脱敏诊断仍保留内部字段。

## 常用诊断

```bash
bash install.sh --version
bash install.sh --help
bash install.sh list-profiles
bash install.sh show-port-map --compact 线路ID
bash install.sh health 线路ID
bash install.sh latency-report 线路ID
bash install.sh latency-report 线路ID 规则ID
bash install.sh traffic-report --sample 10
bash install.sh export-diagnostic
```

健康检查会显示总规则数、启用规则数、停止规则数、异常规则数，并逐条显示备注、状态、转发路径、nftables 规则、TCP 可达性和流量计数器。

流量统计按规则显示：

```text
线路ID / 规则ID / 备注 / 状态 / 公网入口端口 / 虚拟网中转端口 / 落地目标 / 数据包 / 字节 / 可读流量
```

## 端口解释

- 商家 NAT/IX 入口地址：商家分配给 NAT IX 机器的入站地址。
- 商家分配入口端口：商家分配给 NAT IX 机器的入站端口；推荐模式下保存为 `NAT_PUBLIC_PORTS` 端口池，并在每条规则中写入独立 `NAT_PUBLIC_PORT`。
- 客户端入口端口：最终客户端连接公网入口机的端口。
- 虚拟网中转端口：只在 EasyTier 虚拟网内部使用，不是公网端口，不需要商家放行。
- 落地机地址：NAT IX 机器最终转发到的业务主机。
- 落地业务端口：真实业务服务端口。

## 安全边界

- 不安装代理服务。
- 不配置 Remnawave / Xray / sing-box。
- 不接管全局 nftables。
- 不清空全局 nftables 规则集。
- 不全局结束业务进程或 EasyTier 进程。
- 不自动切换线路。
- 不自动修改线路转发状态。
- 不自动修复 nftables。
- 不公开接入码、网络密钥、Telegram token；诊断导出会脱敏。
