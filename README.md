# ix-transit-fabric

当前版本：`1.1.0-alpha.4`

`ix-transit-fabric` 是一个面向 CNIX / IX 转发面板场景的 EasyTier 隧道编排脚本。它用于将商家常见的 WireGuard 隧道接入方式替换为 EasyTier，并自动完成公网入口机上的 nftables 转发。

它只负责 EasyTier 组网、Profile 管理、入口机转发规则、健康诊断和只读监控。它不安装代理服务，不配置 Remnawave / Xray / sing-box，不接管全局 nftables，不清空全局 ruleset，不全局 kill `rw-core` / `easytier-core`，不自动切换线路，不自动修改 `FORWARD_ENABLED`，也不自动修复 nftables。

## 两种模式

### CNIX Panel Mode

适用于商家提供 CNIX 转发面板，面板里需要填写出口 IP:端口。这是 1.0.0 已实机验证通过的模式，现有 `panel-landing` / `panel-ingress` Profile 继续兼容。

### NAT-IX Transit Mode

适用于用户有一台单独 NAT IX / 沪日 IX / 类似中转服务器。公网入口机与 NAT IX 机器通过 EasyTier 组网，公网入口机把客户端流量转发到 NAT IX 机器的 EasyTier IP:TRANSIT_PORT，NAT IX 机器再通过自身 IX 路由转发到落地机公网 IP:LANDING_PORT。

这个模式不需要 CNIX 面板出口配置。NAT IX 机器不安装代理服务，只做 nftables 中转；`LANDING_HOST:LANDING_PORT` 是最终落地服务，`TRANSIT_PORT` 是 NAT IX 机器在 EasyTier 虚拟网内接收入口机转发流量的端口。

## 项目简介

典型场景是：CNIX / IX 面板提供商家入口 IP 和入口端口，你有一台公网入口 VPS 和一台落地 VPS，希望客户端连接入口 VPS 后，经由 EasyTier 隧道和 CNIX 转发面板到达落地业务服务。

脚本会在入口机维护项目自己的 nftables table，只渲染本项目 Profile 对应的 DNAT/SNAT 规则，不清空系统规则集。

EasyTier 是必需组件。netcat 只是诊断工具，缺少 `nc/ncat` 时 TCP 端口探测会跳过，但核心链路仍可安装和运行。

## 适用场景

- CNIX / IX 转发面板已经提供入口 IP 和入口端口。
- 需要用 EasyTier 替代 WireGuard 隧道。
- 入口 VPS 需要将客户端端口转发到落地机 EasyTier 虚拟 IP。
- 需要多 Profile、多入口、多落地或多线路管理。
- 需要人工主备切换、健康检查、通知、健康历史和基础转发命中统计。

## 不适用场景

- 需要自动切换或自动修复。
- 需要 Web 面板、远程控制中心或云厂商 API。
- 需要安装或配置 Remnawave / Xray / sing-box 等代理服务。
- 需要账单级流量统计、限速或完整防火墙托管。
- 需要脚本接管整台机器的网络策略。

## 核心链路

```text
客户端
  -> 公网入口 VPS:LOCAL_PORT
  -> 入口机 nftables
  -> LANDING_ET_IP:REMOTE_PORT
  -> EasyTier 隧道
  -> CNIX 商家入口 IP:CNIX_ENTRY_PORT
  -> CNIX 转发面板
  -> 落地机公网 IP:LISTENER_PORT
  -> 落地机 EasyTier listener
  -> 落地业务服务 REMOTE_PORT
```

## 四端口说明

- `LOCAL_PORT`：客户端连接公网入口 VPS 的端口。
- `CNIX_ENTRY_PORT`：CNIX 商家提供的入口端口。
- `LISTENER_PORT`：落地机 EasyTier listener 端口，填写到 CNIX 面板出口，相当于 WG ListenPort。
- `REMOTE_PORT`：落地业务服务端口，不是 CNIX 面板出口端口。

最短填写关系：

```text
客户端：入口 VPS:LOCAL_PORT
CNIX 面板入口：CNIX_ENTRY_HOST:CNIX_ENTRY_PORT
CNIX 面板出口：落地 VPS:LISTENER_PORT
内部转发：LANDING_ET_IP:REMOTE_PORT
```

## 一行安装

推荐命令：

```bash
curl -fsSL -o install.sh https://raw.githubusercontent.com/ike-sh/ix-transit-fabric/main/install.sh && bash install.sh --menu
```

也可以使用 process substitution：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ike-sh/ix-transit-fabric/main/install.sh) --menu
```

推荐第一种方式，因为会把脚本保存为 `install.sh`，方便后续复用。如果 GitHub 下载慢，可以先手动下载 `install.sh`，再运行：

```bash
bash install.sh --menu
```

EasyTier 下载失败时可以指定版本或下载地址：

```bash
IXTF_EASYTIER_VERSION=v2.6.4 bash install.sh install-easytier
IXTF_EASYTIER_DOWNLOAD_URL=https://example.com/easytier.tar.gz bash install.sh install-easytier
```

## 单线路快速开始

落地机：

```bash
curl -fsSL -o install.sh https://raw.githubusercontent.com/ike-sh/ix-transit-fabric/main/install.sh && bash install.sh --menu
```

菜单选择：

```text
新增落地线路 / 生成接入码
```

入口机：

```bash
curl -fsSL -o install.sh https://raw.githubusercontent.com/ike-sh/ix-transit-fabric/main/install.sh && bash install.sh --menu
```

菜单选择：

```text
新增入口线路 / 粘贴接入码
```

access code 包含 EasyTier 组网密钥，不要公开。正式使用前如果接入码曾经发到聊天或工单里，建议刷新接入码。

## NAT-IX 快速开始

公网入口机：

```bash
curl -fsSL -o install.sh https://raw.githubusercontent.com/ike-sh/ix-transit-fabric/main/install.sh && bash install.sh --menu
```

菜单选择：

```text
NAT-IX 中转模式 -> 公网入口机：创建 NAT-IX 入口线路 / 生成接入码
```

NAT IX 机器：

```bash
curl -fsSL -o install.sh https://raw.githubusercontent.com/ike-sh/ix-transit-fabric/main/install.sh && bash install.sh --menu
```

菜单选择：

```text
NAT-IX 中转模式 -> NAT IX 机器：粘贴接入码并配置中转
```

客户端连接：

```text
公网入口 VPS:LOCAL_PORT
```

NAT-IX 链路：

```text
客户端
-> 公网入口机公网 IP:LOCAL_PORT
-> 公网入口机 nftables
-> NAT IX 机器 EasyTier IP:TRANSIT_PORT
-> EasyTier 隧道
-> NAT IX 机器 nftables
-> 落地机公网 IP:LANDING_PORT
```

NAT-IX 字段：

- `LOCAL_PORT`：客户端连接公网入口机的端口。
- `INGRESS_ET_IP`：公网入口机 EasyTier 虚拟 IP。
- `NAT_ET_IP`：NAT IX 机器 EasyTier 虚拟 IP。
- `TRANSIT_PORT`：NAT IX 机器在 EasyTier 虚拟网内接收转发流量的端口，通常不需要公网放行。
- `LANDING_HOST`：落地机公网 IP 或域名。
- `LANDING_PORT`：落地机业务服务端口，例如 Remnawave / VLESS / Xray / sing-box 的真实服务端口。

如果落地机只允许特定来源访问，需要允许 NAT IX 机器出口 IP。`LANDING_HOST` 是域名时，应用 nftables 会解析到当前 IPv4；域名 IP 变化后请重新运行 `apply-nft-all` 或更新 Profile。

## 落地机配置

常用命令：

```bash
bash install.sh install-easytier
bash install.sh install-netcat
bash install.sh add-landing-profile
bash install.sh show-code PROFILE_ID
bash install.sh health PROFILE_ID
bash install.sh check-business PROFILE_ID
```

落地机负责：

- 启动 EasyTier listener。
- 生成入口机需要的接入码。
- 提供落地业务服务端口 `REMOTE_PORT`。
- 将 `LISTENER_PORT` 提供给 CNIX 面板出口填写。

## 入口机配置

常用命令：

```bash
bash install.sh install-easytier
bash install.sh install-netcat
bash install.sh add-ingress-profile-from-code
bash install.sh show-port-map --compact PROFILE_ID
bash install.sh verify-nft-profiles
bash install.sh health PROFILE_ID
```

入口机负责：

- 使用接入码加入 EasyTier 网络。
- 维护 `LOCAL_PORT -> LANDING_ET_IP:REMOTE_PORT` 的 nftables 转发。
- 校验项目 nftables 规则是否匹配 Profile。

## CNIX 面板怎么填

CNIX 面板入口填写商家提供的信息：

```text
入口地址：CNIX_ENTRY_HOST
入口端口：CNIX_ENTRY_PORT
入口协议：TCP/UDP，按商家面板要求选择
```

CNIX 面板出口填写落地机信息：

```text
出口地址：落地 VPS 公网 IP 或域名
出口端口：LISTENER_PORT
出口协议：TCP/UDP
```

不要把 `REMOTE_PORT` 填到 CNIX 面板出口。`REMOTE_PORT` 是落地业务服务端口，只在 EasyTier 虚拟网内由入口机转发访问。

## 客户端怎么填

客户端连接入口 VPS：

```text
服务器地址：入口 VPS 公网 IP 或域名
服务器端口：LOCAL_PORT
```

客户端不需要知道 `CNIX_ENTRY_PORT`、`LISTENER_PORT` 或 `LANDING_ET_IP`。

## 常用命令

```bash
bash install.sh --version
bash install.sh --help
bash install.sh --menu
bash install.sh list-profiles
bash install.sh show-profile PROFILE_ID
bash install.sh add-nat-ingress-profile
bash install.sh add-nat-transit-profile-from-code
bash install.sh show-code PROFILE_ID
bash install.sh show-port-map --compact PROFILE_ID
bash install.sh doctor-all
bash install.sh health-report
bash install.sh self-check
bash install.sh export-diagnostic
```

`export-diagnostic` 会生成脱敏诊断报告，不直接输出 Profile secret、access code 或 Telegram token。

## 诊断与排障

安装前检查：

```bash
bash install.sh preflight landing
bash install.sh preflight ingress
```

入口机 nftables 校验：

```bash
bash install.sh verify-nft-profiles
```

如果当前机器没有启用中的入口转发 Profile，会显示：

```text
当前机器没有启用中的入口转发 Profile，nftables 转发校验已跳过。
```

健康检查：

```bash
bash install.sh health PROFILE_ID
bash install.sh health-all
bash install.sh health-report
```

`health` 的运行时状态写回只更新健康字段，不会因为每次健康检查制造完整配置备份。

## 多线路 Profile

每条线路用一个 Profile 表达，保存在：

```text
/etc/ix-transit-fabric/profiles/PROFILE_ID.env
```

Profile 模式使用 systemd 模板实例：

```text
ix-transit-easytier@PROFILE_ID.service
```

常用命令：

```bash
bash install.sh list-profiles
bash install.sh enable-profile PROFILE_ID
bash install.sh disable-profile PROFILE_ID
bash install.sh delete-profile PROFILE_ID
bash install.sh status-all
```

单线路或独立线路正常显示为 standalone Profile，不需要设置 `LINE_GROUP`。

## 主备线路与手动切换

只有需要主备线路或手动切换时，才需要设置：

```text
LINE_GROUP
LINE_ROLE=primary
LINE_ROLE=backup
```

推荐模型：

```text
primary ingress: ENABLED=true, FORWARD_ENABLED=true
backup ingress:  ENABLED=true, FORWARD_ENABLED=false
```

相关命令：

```bash
bash install.sh health-report --group GROUP
bash install.sh primary-backup-check GROUP
bash install.sh primary-backup-summary
bash install.sh switch-dry-run GROUP TARGET_PROFILE
bash install.sh switch-line GROUP TARGET_PROFILE
bash install.sh switch-history GROUP
bash install.sh switch-rollback-last
```

没有线路组时会显示：

```text
当前没有已配置的线路组；standalone 模式下主备组检查已跳过。若需要主备切换，请先设置 LINE_GROUP。
```

`switch-dry-run` 只预演，不写配置、不重启服务、不应用 nftables。`switch-line` 是人工确认后的手动切换命令。本项目不做自动切换。

## 监控 / 通知 / 流量统计

只读监控：

```bash
bash install.sh monitor-run-once
bash install.sh monitor-enable
bash install.sh monitor-disable
bash install.sh monitor-status
bash install.sh monitor-set-interval 5
```

通知：

```bash
bash install.sh notify-config
bash install.sh notify-enable
bash install.sh notify-disable
bash install.sh notify-status
bash install.sh notify-test
```

通知只提醒，不执行切换。`TG_BOT_TOKEN` 保存在 `/etc/ix-transit-fabric/notify.env`，权限建议为 `600`，不要公开该文件。

流量统计：

```bash
bash install.sh traffic-report
bash install.sh traffic-report --group GROUP
bash install.sh traffic-report --sample 10
```

流量统计来自本项目 nftables counter，只表示项目转发规则命中情况，不等同于云厂商账单。
`traffic-report --sample N` 会先读取当前 counter，等待 N 秒后再读取一次，并输出 packets / bytes delta；如果没有增量，请确认客户端正在连接正确的 `LOCAL_PORT`。

## 安全边界

- 不安装代理服务。
- 不配置 Remnawave / Xray / sing-box。
- 不接管全局 nftables。
- 不清空全局 nftables ruleset。
- 不全局 kill `rw-core` / `easytier-core`。
- 不自动切换线路。
- 不自动修改 `FORWARD_ENABLED`。
- 不自动修复 nftables。
- 不公开 access code、network secret、Telegram token；诊断导出会脱敏。

## 卸载 / 完全清理

卸载：

```bash
bash install.sh uninstall
```

完全清理：

```bash
bash install.sh purge
```

`uninstall` 保留备份。`purge` 会要求输入大写 `DELETE`，并删除配置、Profile、codes、state、notify.env、history、项目文件和备份。

## FAQ

**CNIX 面板出口填哪个端口？**

填写落地机 EasyTier listener 端口，也就是 `LISTENER_PORT`。它相当于 WG ListenPort。

**REMOTE_PORT 是什么？**

`REMOTE_PORT` 是落地业务服务端口，例如你的业务服务监听端口。它不是 CNIX 面板出口端口。

**netcat 必须安装吗？**

不是。netcat 只是诊断工具。建议安装 `netcat-openbsd` 或 `ncat`，这样 health 可以做 TCP 端口探测。

**通知会自动切换吗？**

不会。通知只提醒，并给出手动检查或手动切换建议。

**access code 可以公开吗？**

不可以。access code 包含组网密钥，公开后应刷新。

## NAT-IX Alpha 注意事项

1.1.0-alpha.4 是 NAT-IX 连接方向增强版，新增 `NAT_DIRECTION=nat-listener`，并保留旧的 `ingress-listener` 方向。

- 模式 A：公网入口机监听，NAT IX 机器连接入口机。适合 NAT IX 机器可以稳定访问公网入口机，且路径质量好。
- 模式 B：NAT IX 机器监听，公网入口机连接 NAT IX 商家入口。适合商家给 NAT IX 机器分配了入站 IP/端口，且该方向延迟更低。
- 如果 Realm-xwPF 使用服务端模式延迟明显更低，推荐测试模式 B。
- `NAT_PUBLIC_HOST` 不一定等于 NAT IX 机器 `curl` 出口 IP；它应填写商家分配给你入站访问的 NAT/IX IP 或域名。
- `NAT_LISTENER_PORT` 应填写商家分配的入站端口。
- 模式 A 推荐先在入口机创建 nat-ingress，再在 NAT IX 机器导入。
- 模式 B 推荐先在 NAT IX 机器运行 `bash install.sh add-nat-listener-profile`，再在公网入口机运行 `bash install.sh add-nat-ingress-from-listener-code`。
- `add-nat-ingress-profile` 会自动检测 `INGRESS_PUBLIC_HOST`，检测到公网 IPv4 后可直接回车使用；也可以设置 `IXTF_PUBLIC_IP=203.0.113.10` 或 `IXTF_INGRESS_PUBLIC_HOST=ingress.example` 覆盖自动检测。1.1.0-alpha.4 修复了 `INGRESS_PUBLIC_HOST` prompt 默认值重复显示。
- nat-ingress 第一端创建后，NAT_ET_IP ping 失败属于正常 pending peer 状态，等 nat-transit 导入后再测试。
- nat-transit 创建后，如果 NAT_ET_IP 不存在，优先看 EasyTier service 日志和 `bash install.sh show-easytier-command PROFILE_ID`。
- ICMP ping 不是 NAT-IX 成功的唯一标准；如果 EasyTier route/peer、nftables 规则、`LANDING_HOST:LANDING_PORT` TCP 和 traffic counter 正常，应以这些业务信号为准。
- 只有 EasyTier peer 配置和到入口机 ET IP 的 route 都不存在时，才应按 `EasyTier peer 未建立` 方向排查。
- NAT IX 机器本机 `nc NAT_ET_IP:TRANSIT_PORT` 失败不一定代表链路失败，因为本机直连可能不命中 PREROUTING DNAT；推荐从入口机或客户端侧测试。
- 入口机侧可以运行 `nc -vz -w 3 NAT_ET_IP TRANSIT_PORT`，客户端侧以连接 `INGRESS_PUBLIC_HOST:LOCAL_PORT` 为准。
- `show-port-map --compact` 已修复 nat-transit 的 EasyTier peer 端口显示；缺少端口时会显示 `INGRESS_LISTENER_PORT 未配置`。
- NAT IX 机器需要能访问入口机 EasyTier listener。
- 落地机需要允许 NAT IX 机器出口 IP 访问 LANDING_PORT。
- NAT IX 机器不需要安装代理服务，只做 nftables 中转。
- NAT-IX 接入码包含 EasyTier `network_secret`；如果接入码发到聊天、工单或日志，请正式使用前运行 `bash install.sh refresh-nat-code PROFILE_ID` 刷新或重建 nat-ingress Profile。
- `refresh-nat-code` 会生成新 `network_secret`，旧接入码失效，旧 nat-transit Profile 需要重新导入新的接入码。

模式 B 对比：

```text
Realm-xwPF 服务端模式：
公网入口机 -> NAT IX 商家入口 IP:端口 -> NAT IX 机器 -> 落地

ix-transit-fabric 模式 B：
公网入口机 -> NAT IX 商家入口 IP:端口 -> EasyTier listener -> nftables -> 落地
```

## NAT-IX 延迟诊断

常用命令：

```bash
bash install.sh latency-report PROFILE_ID
bash install.sh nat-latency PROFILE_ID
bash install.sh latency-all
bash install.sh latency-report PROFILE_ID --sample 10
bash install.sh traffic-report --sample 10
```

`latency-report` 会按 Profile 角色输出 NAT-IX 分段报告：Profile 基本信息、EasyTier systemd / peer / tunnel hint、组网 ping 摘要、TCP connect time、listener / LOCAL_PORT 检查、nftables rule 状态和 counter delta。`nat-latency` 是同义命令，`latency-all` 会遍历本机 NAT-IX Profile。

ICMP ping 不是业务延迟。ICMP ping 是基础 RTT，不包含 TCP 握手、TLS/REALITY/代理协议握手、应用处理、重传、队列、NAT/隧道开销；客户端显示的延迟通常是完整应用链路耗时。

如果 EasyTier 使用 TCP 承载 TCP 业务，可能出现 TCP-over-TCP 队头阻塞。若环境允许，可以新建测试 Profile 对比 EasyTier listener proto：`tcp`、`udp`、`tcp+udp`。不建议直接覆盖生产 Profile，先用新端口做协议 A/B 测试。

建议按顺序测试：

1. 公网入口机 -> NAT IX 公网 ping
2. NAT IX -> 落地机公网 ping
3. 公网入口机 -> `NAT_ET_IP` ping
4. 公网入口机 -> `NAT_ET_IP:TRANSIT_PORT` TCP connect
5. NAT IX -> `LANDING_HOST:LANDING_PORT` TCP connect
6. `traffic-report --sample 10`
7. 客户端业务延迟

## Roadmap

1.1.0-alpha.1 先引入 NAT-IX Transit Mode，CNIX Panel Mode 继续保持 1.0.0 的稳定边界：

- 保持 CNIX + EasyTier + nftables 核心链路。
- 保持人工主备切换。
- 保持只读监控和通知。
- 不加入自动切换。
- 不加入 Web 面板。
- 不加入远程控制中心。
- 不安装或配置代理服务。
