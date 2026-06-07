# ix-transit-fabric

当前版本：`1.2.0-alpha.4`

`ix-transit-fabric` 用于管理 NAT-IX 中转线路：公网入口机接收客户端连接，通过 EasyTier 连接 NAT IX 机器，NAT IX 机器再用 nftables 转发到落地机业务端口。

脚本只负责 EasyTier 组网、线路配置、项目 nftables 规则、转发规则管理、健康检查、延迟诊断和流量命中统计。它不安装代理服务，不配置 Remnawave / Xray / sing-box，不接管全局 nftables，不清空全局规则集，不全局结束 `rw-core` / `easytier-core`，不自动切换线路，不自动修复配置。

## 适用场景

- 商家给了 NAT/IX 入口地址和入口端口。
- 你有一台公网入口机、一台 NAT IX 机器，以及一个或多个落地机业务服务。
- 客户端最终连接公网入口机。
- NAT IX 机器只做 EasyTier listener 和 nftables 中转。

## 架构图

```text
客户端
  -> 公网入口机公网 IP:客户端入口端口
  -> 公网入口机 nftables
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

每条线路可以配置多转发规则，用于把多个客户端入口端口转发到不同的落地目标。

1. 在 NAT IX 机器新增转发规则。
2. 刷新接入码。
3. 在公网入口机重新导入接入码。
4. 查看转发规则列表和流量统计。

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

每条转发规则包含规则 ID、备注、启用状态、客户端入口端口、虚拟网中转端口、落地机地址、落地业务端口和转发协议。公网入口机重新导入接入码时，会按 `rule_id` 更新本地规则；远端已删除的规则默认提示停用本地对应规则，不会自动删除。

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

NAT IX 接入码 v3 使用 `code_schema=3`，包含 `rules` 数组。v2 旧接入码仍继续支持，并会兼容成单条 `rule-main`。

安全提醒：

```text
接入码包含 EasyTier 组网密钥。
不要把接入码发到聊天记录、工单、截图或公开日志。
建议复制后立即清屏：clear
如果终端日志会被保存，请正式使用前刷新接入码。
```

## 1.1.0 单规则兼容

1.1.0 的单转发配置会自动兼容为一条默认转发规则 `rule-main`，备注为“默认转发”。旧 profile 中的 `LOCAL_PORT / TRANSIT_PORT / LANDING_HOST / LANDING_PORT / FORWARD_PROTO` 会在运行时映射为默认规则，不会让升级后的单规则用户断链。

## alpha 注意事项

- `1.2.0-alpha.4` 修复 `show-config PROFILE_ID` 直接命令仍走旧配置的问题。
- 状态列表移除旧主备字段，统一显示规则数。
- 菜单状态与 CLI 状态输出统一。
- `1.1.0` 仍是稳定正式版。
- 多规则功能需要先实机验证。
- 多规则修改后，NAT IX 机器需要刷新接入码，公网入口机需要重新导入。
- 客户端入口端口只在公网入口机侧指定；NAT IX 机器规则列表会显示“公网入口机侧指定”。
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
线路ID / 规则ID / 备注 / 状态 / 客户端入口端口 / 虚拟网中转端口 / 落地目标 / 数据包 / 字节 / 可读流量
```

## 端口解释

- 商家 NAT/IX 入口地址：商家分配给 NAT IX 机器的入站地址。
- 商家分配入口端口：商家分配给 NAT IX 机器的入站端口。
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
