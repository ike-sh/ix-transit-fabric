# Changelog

## 1.1.0-alpha.1

### Added

- NAT-IX Transit Mode.
- `nat-ingress` / `nat-transit` Profile roles.
- NAT-IX access-code workflow.
- NAT-IX nftables rendering.
- NAT-IX health / doctor / port-map / traffic support.

### Compatibility

- Existing CNIX Panel Mode remains unchanged.
- Existing 1.0.0 panel profiles remain compatible.

### Safety

- No automatic switching.
- No global nftables takeover.
- No global nftables ruleset reset.
- No global process kill.

## 1.0.0

正式长期使用版。

### Added

- CNIX 转发面板 + EasyTier + nftables 核心链路。
- 多 Profile 管理。
- 多入口 / 多落地 / 多线路场景。
- 手动主备切换和回滚历史。
- 健康检查、`doctor-all`、`health-report` 和脱敏诊断导出。
- 只读监控、systemd timer、Telegram 通知。
- `health-history` 和 `switch-history`。
- nftables counter 基础流量统计。
- GitHub 一行安装命令。
- `preflight`、`install-netcat`、`install-diagnostics-tools`。

### Changed

- EasyTier 缺失时，交互式模式默认提示安装；非交互模式需要显式命令或环境变量。
- netcat 诊断工具提供默认安装入口；安装失败不阻断核心安装。
- health 状态写回只更新运行时健康字段，不再制造大量配置备份。
- README / examples / tests 全面使用占位符和文档地址。
- landing-only 场景下 `verify-nft-profiles` 输出合并为一段跳过说明。
- 无 `LINE_GROUP` 的 standalone Profile 明确跳过主备组检查。

### Security

- 不接管全局 nftables。
- 不清空全局 nftables ruleset。
- 不全局 kill 业务进程或 EasyTier 进程。
- 不自动切换线路。
- 不自动修改 `FORWARD_ENABLED`。
- 不自动修复 nftables。
- access code / network secret / Telegram token 使用占位符或脱敏输出。

### Known Limitations

- 不做自动切换。
- 不安装或配置代理服务。
- 流量统计基于本项目 nftables counter，不等同于云厂商账单。
- 不提供 Web 面板或远程控制中心。

## 0.5.x

- 收敛只读监控、通知、健康历史、流量统计和诊断导出。
- 加固 landing-only、standalone、无线路组和 nftables 校验场景。
- 引入 `preflight`、netcat 安装入口和 health 运行时写回。

## 0.4.x

- 增加健康检查、主备线路、手动切换、dry-run、切换历史和回滚。
- 所有切换保持人工确认。

## 0.3.x

- 增加多 Profile、多入口、多落地、多线路。
- 引入 Profile systemd 模板实例和多 profile nftables 统一渲染。

## 0.2.x

- 支持更换落地机 / 入口机。
- 接入码刷新、随机化和多协议参数收敛。

## 0.1.x

- 跑通 CNIX 转发面板 + EasyTier 替代 WireGuard + nftables 核心链路。
