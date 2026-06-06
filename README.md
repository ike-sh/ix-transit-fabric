# ix-transit-fabric

当前版本：`1.1.0-rc.2`

`ix-transit-fabric` 用于管理 NAT-IX 中转线路：公网入口机接收客户端连接，通过 EasyTier 连接 NAT IX 机器，NAT IX 机器再用 nftables 转发到落地机业务端口。

脚本只负责 EasyTier 组网、线路配置、项目 nftables 规则、健康检查、延迟诊断和流量命中统计。它不安装代理服务，不配置 Remnawave / Xray / sing-box，不接管全局 nftables，不清空全局 ruleset，不全局 kill `rw-core` / `easytier-core`，不自动切换线路，不自动修复配置。

## 适用场景

- 商家给了 NAT/IX 入口地址和入口端口。
- 你有一台公网入口机、一台 NAT IX 机器，以及一个落地机业务服务。
- 客户端最终连接公网入口机。
- NAT IX 机器只做中转，不运行代理服务。

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

商家入口：

```text
公网入口机 -> 商家 NAT/IX 入口地址:商家分配入口端口 -> NAT IX 机器 EasyTier listener
```

## 一行安装

```bash
curl -fsSL -o install.sh https://raw.githubusercontent.com/ike-sh/ix-transit-fabric/main/install.sh && bash install.sh
```

也可以先下载 `install.sh`，再运行：

```bash
bash install.sh
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

第一步，在 NAT IX 机器执行：

```bash
bash install.sh
```

菜单选择：

```text
创建 NAT IX 中转线路
```

按提示输入：

1. 商家 NAT/IX 入口地址。
2. 商家分配入口端口。
3. 落地机地址。
4. 落地业务端口。

脚本会自动生成线路 ID、线路名称、EasyTier 网络名、网络密钥、NAT IX 虚拟 IP、公网入口机虚拟 IP、虚拟网中转端口和默认 TCP/UDP 协议。完成后复制整段 NAT IX 接入码。

第二步，在公网入口机执行：

```bash
bash install.sh
```

菜单选择：

```text
公网入口机导入接入码
```

按提示粘贴接入码，并输入客户端入口端口。直接回车会随机生成端口。

第三步，客户端连接：

```text
公网入口机公网 IP:客户端入口端口
```

安全提醒：

```text
接入码包含 EasyTier 组网密钥。
不要把接入码发到聊天记录、工单、截图或公开日志。
如果已经发出，请正式使用前重新生成接入码或重建线路。
```

## 端口解释

- 商家 NAT/IX 入口地址：商家分配给 NAT IX 机器的入站地址。
- 商家分配入口端口：商家分配给 NAT IX 机器的入站端口。
- 客户端入口端口：最终客户端连接公网入口机的端口。
- 虚拟网中转端口：脚本自动生成，只在 EasyTier 虚拟网内部使用，不是公网端口，不需要商家放行。
- 落地机地址：NAT IX 机器最终转发到的业务主机。
- 落地业务端口：Xray / sing-box / Remnawave 等真实业务服务端口。

技术字段只在高级诊断、导出配置、`show-config` 和技术附录中使用，例如 `LOCAL_PORT`、`TRANSIT_PORT`、`LANDING_HOST`、`LANDING_PORT`、`NAT_PUBLIC_HOST`、`NAT_LISTENER_PORT`、`NAT_ET_IP`、`INGRESS_ET_IP`、`FORWARD_PROTO`。

## 常用命令

```bash
bash install.sh --version
bash install.sh --help
bash install.sh
bash install.sh list-profiles
bash install.sh show-port-map --compact 线路ID
bash install.sh health 线路ID
bash install.sh latency-report 线路ID
bash install.sh traffic-report --sample 10
bash install.sh export-diagnostic
```

`export-diagnostic` 会生成脱敏诊断报告，不直接输出网络密钥、接入码或 Telegram token。

## 健康检查

```bash
bash install.sh health 线路ID
```

普通健康检查按业务语言输出：

```text
线路健康检查：线路ID

基础状态：
* 配置文件：存在
* 服务状态：运行中
* EasyTier 进程：存在
* 本机虚拟 IP：存在

转发状态：
* nftables 规则：正常
* 商家入口监听：正常
* 连接 NAT IX：正常
* 落地服务：可达

结果：
HEALTH_STATUS=healthy
说明：检查通过
```

需要技术详情时运行：

```bash
bash install.sh export-diagnostic
bash install.sh show-config 线路ID
```

## 延迟诊断

```bash
bash install.sh latency-report 线路ID
bash install.sh latency-report 线路ID --sample 10
```

输出分段：

```text
NAT-IX 延迟诊断：线路ID

分段 1：公网入口机 -> NAT IX 虚拟 IP
* ICMP RTT
* TCP 建连耗时

分段 2：NAT IX 机器 -> 落地机
* ICMP RTT
* TCP 建连耗时

分段 3：客户端流量命中
* nftables 计数器
* sample delta
```

客户端显示的节点延迟可能包含代理协议握手、TLS/REALITY、重传和应用处理，不等同于 ping。

## 流量统计

```bash
bash install.sh traffic-report
bash install.sh traffic-report --sample 10
```

流量统计来自本项目 nftables counter，只表示项目转发规则命中情况，不等同于云厂商账单。

## 卸载与完全清理

卸载服务，保留配置备份：

```bash
bash install.sh uninstall
```

完全清理：

```bash
bash install.sh purge
```

完全清理会要求输入大写 `DELETE`，并列出将删除的 systemd 服务、wrapper、配置目录、线路配置、接入码、state/history、nftables 项目表、sysctl 文件和备份目录。

`purge` 会分别询问是否删除 `easytier-core` 和当前 `install.sh`。install.sh 是用户下载的安装脚本，不是服务残留；完全清理默认不会删除你手动下载的 install.sh，只有确认后才会处理。

## 安全边界

- 不安装代理服务。
- 不配置 Remnawave / Xray / sing-box。
- 不接管全局 nftables。
- 不清空全局 nftables ruleset。
- 不全局 kill `rw-core` / `easytier-core`。
- 不自动切换线路。
- 不自动修改线路转发状态。
- 不自动修复 nftables。
- 不公开接入码、网络密钥、Telegram token；诊断导出会脱敏。

## 旧版兼容说明

CNIX Panel Mode 与 alpha 阶段旧 NAT-IX 方向仍保留兼容命令，但不再作为正式推荐流程。新用户只应使用 NAT IX listener 正式流程：NAT IX 机器生成接入码，公网入口机导入接入码。

旧版工具入口：

```text
高级维护 -> 旧版兼容工具
```

这些入口仅用于迁移 alpha 旧配置或历史 CNIX 面板线路，不推荐新线路使用。

## 技术附录

- `LOCAL_PORT`：客户端入口端口。
- `TRANSIT_PORT`：虚拟网中转端口。
- `LANDING_HOST`：落地机地址。
- `LANDING_PORT`：落地业务端口。
- `NAT_PUBLIC_HOST`：商家 NAT/IX 入口地址。
- `NAT_LISTENER_PORT`：商家分配入口端口。
- `INGRESS_PUBLIC_HOST`：公网入口机地址。
- `NAT_ET_IP`：NAT IX 虚拟 IP。
- `INGRESS_ET_IP`：公网入口机虚拟 IP。
- `FORWARD_PROTO`：转发协议。

## FAQ

**NAT IX 机器需要安装代理服务吗？**

不需要。NAT IX 机器只做 EasyTier listener 和 nftables 中转。

**虚拟网中转端口需要商家放行吗？**

不需要。虚拟网中转端口只在 EasyTier 虚拟网内部使用。

**接入码可以公开吗？**

不可以。接入码包含 EasyTier 组网密钥。不要把接入码发到聊天记录、工单、截图或公开日志；如果已经发出，请正式使用前重新生成接入码或重建线路。

**CNIX Panel Mode 还能用吗？**

能。它在高级维护的旧版兼容工具里保留，但正式推荐流程是 NAT-IX listener mode。
