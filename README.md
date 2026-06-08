# ix-transit-fabric

**版本**：`1.2.0`  
**作者**：ike  
**仓库**：[https://github.com/ike-sh/ix-transit-fabric](https://github.com/ike-sh/ix-transit-fabric)

用于管理 **NAT-IX 中转线路**：公网入口机接收客户端连接，经 EasyTier 虚拟网连到 NAT IX 机器，再由 nftables 转发到落地业务端口。

脚本只负责 EasyTier 组网、线路配置、项目级 nftables、转发规则、健康检查、延迟诊断与流量统计。  
**不负责**：安装代理内核（Xray / sing-box 等）、接管全局防火墙、自动切线、自动修复配置。

---

## 架构

```text
客户端
  → 公网入口机公网 IP:客户端入口端口
  → 公网入口机 nftables
  → 商家 NAT/IX 入口:商家入口端口
  → EasyTier 虚拟网
  → NAT IX 虚拟 IP:虚拟网中转端口
  → NAT IX 机器 nftables
  → 落地机:业务端口
```

典型部署：**两台 Linux**（公网入口 + NAT IX），各装一份脚本；落地机只需业务端口可达。

---

## 安装

推荐使用 **版本标签** 安装（避免 GitHub raw 缓存）：

```bash
curl -fsSL -o install.sh \
  "https://raw.githubusercontent.com/ike-sh/ix-transit-fabric/v1.2.0/install.sh?ts=$(date +%s)"
chmod +x install.sh
```

安装 EasyTier：

```bash
bash install.sh install-easytier
```

安装全局快捷命令（推荐）：

```bash
bash install.sh install-ix-cli
```

之后可直接使用：

| 命令 | 说明 |
|------|------|
| `ix` / `IX` | 进入交互管理菜单 |
| `ix --version` | 查看版本 |
| `ix health` | 健康检查 |
| `ix diagnose 线路ID` | 一键诊断 |
| `ix list-profiles` | 列出线路 |

带参数时等同 `bash install.sh <子命令> ...`。

---

## 快速部署（推荐模式）

**模式**：NAT IX 机器监听商家入口，公网入口机作为 EasyTier 客户端连接 NAT IX。

### 1. NAT IX 机器

```bash
bash install.sh install-ix-cli
ix
# 菜单 → 1) 创建 NAT IX 中转线路
```

按提示填写商家 NAT/IX 地址与端口、落地机地址与端口。完成后会生成 **接入码**。

### 2. 公网入口机

```bash
bash install.sh install-ix-cli
ix
# 菜单 → 2) 公网入口机导入接入码
```

粘贴 NAT IX 生成的接入码，为每条规则指定 **客户端入口端口**。

### 3. 客户端连接

```text
公网入口机公网 IP:<客户端入口端口>
```

### 4. 验证

```bash
ix health
ix show-port-map --compact
```

期望 `HEALTH_STATUS=healthy`，nftables 与流量计数器有命中。

---

## 多转发规则

每条线路可有多条独立转发规则，路径为：

```text
公网入口端口 → 商家入口:端口 → 虚拟网中转端口 → 落地目标
```

**变更流程**（NAT IX 改规则后）：

1. NAT IX：`ix` → 转发规则管理 → 修改/新增规则 → 刷新接入码  
2. 公网入口：重新导入接入码  
3. 两端：`ix health` 确认

常用命令：

```bash
ix list-rules 线路ID
ix add-rule 线路ID
ix edit-rule 线路ID 规则ID
ix refresh-code 线路ID
ix apply-rules 线路ID
```

接入码格式 `code_schema=4`，每条规则有独立 `nat_public_port`。接入码含组网密钥，勿公开；泄露后请 `refresh-code` 并重新导入。

---

## DDNS（商家域名）

商家只给域名时，脚本**默认每 3 分钟**解析 `LANDING_HOST` / `NAT_PUBLIC_HOST` / `INGRESS_PUBLIC_HOST`，IP 变化自动刷新 nftables；入口域名变化时重启 EasyTier。

```bash
ix ddns-status
ix ddns-refresh      # 手动刷新
ix ddns-disable      # 关闭定时刷新
ix ddns-enable       # 重新开启
```

菜单：**高级维护 → 监控 / 通知 / DDNS**。

---

## EasyTier 协议

创建线路时可选 TCP/UDP、UDP、TCP、WebSocket、WSS、QUIC、WireGuard、ALL。两端需一致；变更后刷新接入码并重新导入。

```bash
ix set-easytier-protocol 线路ID
```

---

## 常用运维命令

```bash
ix --help
ix status-all
ix show-config 线路ID
ix show-port-map 线路ID --compact
ix latency-report 线路ID
ix traffic-report --sample 10
ix verify-nft-profiles
ix export-diagnostic
ix self-check
```

---

## 端口术语

| 名称 | 说明 |
|------|------|
| 客户端入口端口 | 客户端连接公网入口机的端口 |
| 商家入口端口 | 商家分配给 NAT IX 的公网端口（每条规则可独立） |
| 虚拟网中转端口 | 仅 EasyTier 内网使用，不需公网放行 |
| 落地业务端口 | 真实业务服务端口 |

---

## 安全边界

- 不安装 / 不配置代理服务  
- 不接管、不清空全局 nftables  
- 不全局结束业务或 EasyTier 进程  
- 不自动切换线路、不自动改转发开关  
- 诊断导出对接入码与密钥脱敏  

---

## 升级

```bash
curl -fsSL -o install.sh \
  "https://raw.githubusercontent.com/ike-sh/ix-transit-fabric/v1.2.0/install.sh?ts=$(date +%s)"
bash install.sh install-ix-cli
ix --version
```

---

## 环境变量（可选）

| 变量 | 说明 |
|------|------|
| `IXTF_EASYTIER_VERSION` | 指定 EasyTier 版本 |
| `IXTF_COLOR=never` / `NO_COLOR=1` | 禁用彩色输出 |
| `IXTF_DEBUG=true` | 详细调试输出 |

---

## 变更记录

见 [CHANGELOG.md](CHANGELOG.md)。

## 许可

见 [LICENSE](LICENSE)。
