# Changelog

## 1.1.0-rc.3

### Changed

- Simplified EasyTier install logs for normal users.
- Chinese-ified preflight output.
- Removed legacy mode entries from all interactive menus.
- Strengthened access-code safety reminder.

### Compatibility

- Legacy profile compatibility code may remain internally, but legacy workflows are no longer exposed in interactive menus.

## 1.1.0-rc.2

### Changed

- Polished ordinary install and health output before 1.1.0 final.
- Hid long nftables verification details from normal create/import summaries; detailed checks remain in `verify-nft-profiles`, `doctor-all`, and `export-diagnostic`.
- Reworded preflight output in Chinese for NAT IX 中转线路 and 公网入口线路.
- Reduced env-style technical fields in normal health/install summaries.
- Strengthened access-code security reminder.

## 1.1.0-rc.1

### Changed

- Promoted NAT IX listener workflow to the default and only recommended user flow.
- Removed old NAT-IX direction from normal menus.
- Moved CNIX Panel Mode and old NAT-IX flow to legacy/advanced compatibility.
- Reworked user-facing menus, setup wizard, health output, port maps and README for formal release.
- Hid internal virtual-network fields from normal setup.
- Cleaned duplicate access-code/security output.
- Improved purge cleanup wording and optional install.sh removal.

### Compatibility

- Legacy commands may remain available under advanced maintenance only.
- Existing alpha profiles should be recreated for the formal workflow if possible.

## 1.1.0-alpha.5

### Changed

- Reworked NAT-IX menus from user-role perspective.
- Hid advanced internal NAT-IX fields from normal setup.
- Renamed user-facing NAT-IX fields to Chinese descriptions.
- Made TRANSIT_PORT an advanced virtual-network-only setting.
- Improved uninstall/purge wording and optional install.sh cleanup.

### Fixed

- Prevented users from mixing recommended NAT-listener codes with old ingress-listener workflows.
- Removed duplicate NAT-IX access-code and security reminder headings.
- Fixed contradictory easytier-core purge output.

## 1.1.0-alpha.4

### Added

- NAT-IX nat-listener direction.
- NAT IX listener workflow.
- Public ingress peer-to-NAT workflow.
- Direction-aware port-map, health, and latency diagnostics.

### Fixed

- Duplicate default text in INGRESS_PUBLIC_HOST prompt.

### Notes

- Existing NAT-IX ingress-listener direction remains compatible.
- CNIX Panel Mode remains unchanged.

## 1.1.0-alpha.3

### Fixed

- Auto-detect INGRESS_PUBLIC_HOST on nat-ingress setup.
- Avoid treating NAT IX local self-test to NAT_ET_IP:TRANSIT_PORT as hard failure.
- Relax NAT-IX health when ICMP ping fails but EasyTier route/peer and nftables are present.
- Fix nat-transit compact port map showing LISTENER_PORT placeholder.
- Improve NAT-IX access-code leakage guidance.

### Compatibility

- CNIX Panel Mode remains unchanged.
- Existing 1.0.0 profiles remain compatible.

## 1.1.0-alpha.2

### Fixed

- NAT-IX EasyTier readiness after profile creation.
- NAT-IX health semantics for pending peer.
- nat-transit preflight mode label.
- Duplicate NAT-IX access-code and security reminder output.
- NAT-IX troubleshooting hints.

### Compatibility

- CNIX Panel Mode remains unchanged.
- Existing 1.0.0 profiles remain compatible.

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
