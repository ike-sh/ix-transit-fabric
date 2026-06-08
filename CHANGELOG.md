# Changelog

## 1.2.0-alpha.17

### Fixed

- 删除重复定义的 `show_group()`（旧英文版），仅保留完整中文版实现。

### Changed

- `health-report` 明细表头改为中文。
- `list-groups` 表头改为中文。
- `switch-dry-run` 预演保证说明改为中文。

## 1.2.0-alpha.16

### Changed

- `primary-backup-runbook`、`show-group`、`primary-backup-summary`、`health-report` 汇总与线路组问题描述中文化。
- README 标注 `panel-landing` / `panel-ingress` 为 deprecated，新部署仅推荐 NAT-IX 流程。

## 1.2.0-alpha.15

### Changed

- `doctor-all`、`export-diagnostic`、主备校验（validate-primary-backup / primary-backup-check）用户面向输出统一为中文。
- `show-easytier-status` 的 systemd 摘要改为中文。
- NAT IX 一致性检查警告建议命令改为 `diagnose`。

## 1.2.0-alpha.14

### Added

- 新增 `bash install.sh diagnose [线路ID]` 一键诊断：合并 EasyTier 状态、nft/一致性检查、转发规则健康与操作提示。

### Fixed

- 健康检查改为逐规则探测商家入口（NAT IX listener / 公网入口 peer），不再只测第一个端口。
- 修正 NAT IX 侧 health 文案（「连接 NAT IX」→「公网入口虚拟网」）。

### Changed

- 公网入口导入同步结果展示新增/更新规则 ID 列表。
- 增规则提示明确 NAT IX 已生效、公网入口需重新导入。
- 完成摘要/增规则后的快速检查改为 `diagnose` 命令。

## 1.2.0-alpha.13

### Fixed

- 增强 `show-easytier-status`：展示 peers/listeners/mapped-listeners 数量与明细，以及 mapped-listeners 运行时是否启用。
- 新增 NAT IX 侧 `verify_nat_transit_rule_consistency`，规则变更后校验 listener/mapped/nft 与启用规则一致。

### Changed

- `verify-nft-profiles` 用户面向输出统一为中文。
- 公网入口导入文案「正在启动」改为「正在重启」；完成摘要与增规则后输出可直接复制的 `show-easytier-status` 命令。
- 删除未使用的 `easytier_supports_mapped_listeners()` 死代码。

## 1.2.0-alpha.12

### Fixed

- 修复 NAT IX 多 listener 未向 EasyTier 宣告 `--mapped-listeners`，导致第二条及后续转发规则 peer 无法正确连接商家公网入口。
- 修复规则变更后 NAT IX 仅更新 env 未重启 EasyTier，listener/peer 未生效。
- 修复 `restart_profile` 重启后未等待 EasyTier 就绪即返回，实机导入时易出现短暂不可用。

### Changed

- NAT IX（nat-listener）刷新 endpoint 时写入 `ET_MAPPED_LISTENERS`，wrapper 在 EasyTier 支持时追加 `--mapped-listeners`。
- `prompt_nat_public_ports` 不再向终端 stdout 打印完整展开端口列表（spec 仍正确写入接入码）。

## 1.2.0-alpha.11

### Fixed

- 修复公网入口机重复导入接入码时使用 `start_profile` 而非 `restart_profile`，导致 EasyTier 仍运行旧 peer/密钥、多规则转发不通。
- 修复 `prompt_nat_public_ports` 在命令替换子 shell 中设置变量丢失，导致端口段接入码 `nat_public_port_spec` 被展开为完整列表。
- 修复 NAT IX 新增/变更规则后 listener 未及时重启的问题。

### Changed

- 规则变更后生成接入码（`regenerate_nat_profile_code`）不再轮换 `network_secret`；手动「刷新接入码」仍会换密钥。
- 规则变更后 NAT IX / 公网入口机会自动重启 EasyTier 以应用 listener/peer 变更。

## 1.2.0-alpha.10

### Fixed

- 修复 `current_profile_forward_client_ports()` 恢复上下文时遗漏 `NAT_PUBLIC_PORT` 的问题。
- 修复公网入口导入一致性检查将磁盘上非接入码规则纳入校验导致误报的问题。

### Changed

- 删除已无调用的 `print_rule_sync_required_notice()` 死代码。
- 规则编辑菜单统一由 `prompt_refresh_access_code_after_rule_change` 提示刷新接入码，移除重复内联文案。

## 1.2.0-alpha.9

### Fixed

- 修复公网入口机导入完成后 `saved_nat_public: unbound variable`。
- 修复普通流程仍显示 systemd symlink / sysctl 原始输出。
- 修复接入码包含完整展开端口池导致接入码过长的问题。

### Changed

- 新增/修改/启用/停止/删除转发规则后，可立即生成新的接入码。
- 普通创建/导入输出进一步精简。
- 接入码只携带每条规则实际使用的商家入口端口。

### Added

- 公网入口导入完成后执行规则数、nftables 和 EasyTier peer 一致性检查。

## 1.2.0-alpha.8

### Fixed

- 修复多规则推荐模式下所有规则复用同一个商家 NAT/IX 入口端口的问题。
- 修复公网入口机重复导入同一 NAT IX 接入码时可能新建线路并触发 `ET_SUBNET` 冲突的问题。
- 精简普通输出中的 systemd 原始输出和重复接入码安全提醒。

### Changed

- 每条转发规则新增独立 `NAT_PUBLIC_PORT`，NAT IX 线路新增 `NAT_PUBLIC_PORTS` / `NAT_PUBLIC_PORT_MODE` 端口池。
- NAT IX 推荐模式接入码升级为 `code_schema=4`，每条规则包含 `nat_public_port`。
- NAT IX EasyTier listener 和公网入口机 EasyTier peer 会按启用规则的商家入口端口去重渲染。
- 刷新、导入和规则列表摘要显示商家入口端口与完整转发路径。

## 1.2.0-alpha.7

### Fixed

- 修复粘贴接入码带空白时可能吞掉下一步交互的问题。
- 修复公网入口机导入 v3 多规则接入码后只保留一条规则的问题。
- 修复同 `rule_id` 重新导入时客户端入口端口被错误判定为冲突的问题。
- 修复导入摘要与实际保存规则不一致的问题。

### Changed

- 公网入口机导入接入码时逐条显示建议公网入口端口，回车即可确认。
- 普通创建和导入完成摘要大幅精简。
- 重要信息增加颜色提示。
- 规则排序固定为 `rule-main` 优先，其余规则稳定排序。

## 1.2.0-alpha.6

### Fixed

- 修复新增规则成功摘要错误复用 rule-main 信息的问题。
- 修复多规则端口模型不清晰导致公网入口端口可能复用的问题。
- 修复公网入口机导入 v3 接入码时未逐条分配独立客户端入口端口的问题。

### Changed

- 多规则同步改为明确的“公网入口端口 -> 虚拟网中转端口 -> 落地目标”模型。
- 刷新接入码前显示接入码包含的全部规则。
- 公网入口机导入接入码时逐条显示规则并分配客户端入口端口。

## 1.2.0-alpha.5

### Fixed

- 修复转发规则管理菜单仍要求用户手动输入线路 ID，导致菜单数字被误判为 PROFILE_ID 的问题。
- 修复规则管理缺少数字化规则列表的问题。

### Changed

- 转发规则管理改为先选择线路，再用数字管理规则。
- 转发规则列表显示序号、备注、状态和端口。
- 公网入口机不再允许通过普通菜单直接新增落地规则。
- 普通输出继续移除 Profile 字样。

## 1.2.0-alpha.4

### Fixed

- 修复 `show-config PROFILE_ID` 直接命令仍读取旧单线路配置的问题。
- 修复主菜单状态和高级状态仍显示旧主备字段的问题。

### Changed

- 状态列表统一为 NAT-IX 多规则主线视角。
- 菜单路径和 CLI 直调用路径复用同一配置摘要输出。

## 1.2.0-alpha.3

### Fixed

- 修复查看指定线路配置后菜单报错。
- 修复 self-check 中残留的 systemctl 原始输出。
- 修复高级线路列表和 show-config 中过多旧字段/英文内部字段。

### Changed

- show-config、线路列表、自检继续中文化。
- 多规则新增/停用/删除/刷新接入码路径继续加固。

## 1.2.0-alpha.2

### Fixed

- 延迟诊断菜单留空自动选择唯一线路失败。
- NAT IX 侧规则列表客户端入口端口为空的问题。
- self-check 旧角色语义。
- 普通状态、流量、端口地图输出中的英文内部字段。

### Changed

- 普通 traffic-report、status、self-check 继续中文化。
- 多规则健康检查输出更适合普通用户。

## 1.2.0-alpha.1

### Added

- Multi forwarding rules per NAT IX line.
- Forward rule add/edit/enable/disable/delete.
- Per-rule notes.
- Multiple client ports forwarding to different landing targets.
- NAT IX v3 access codes with `rules` and `rules_b64`.
- EasyTier protocol selection and protocol update command.
- Per-rule health, latency, and traffic reporting.

### Compatibility

- Existing 1.1.0 single-rule profiles are migrated or mapped to a default rule.
- NAT IX listener workflow remains the only recommended deployment flow.

## 1.1.0

正式版。

### Added

- NAT IX listener 推荐部署流程。
- NAT IX 机器生成接入码，公网入口机导入接入码。
- EasyTier 组网、nftables 转发、健康检查、延迟诊断和流量统计。
- 中文化安装向导和正式主菜单。

### Changed

- 旧 NAT-IX 方向和 CNIX 面板模式不再出现在普通交互菜单。
- EasyTier 安装日志收敛。
- 环境预检输出中文化。
- 普通安装摘要隐藏详细 nftables 调试信息。
- 接入码安全提醒强化。

### Safety

- 不清空全局 nftables 规则集。
- 不全局 kill 业务进程。
- 不安装代理服务。
- 不自动切换线路。
- 不接管全局 nftables。
- 接入码包含组网密钥，泄露后应刷新或重建线路。

### Compatibility

- 历史配置尽量保持兼容。
- 新部署只推荐 NAT IX listener 正式流程。

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
