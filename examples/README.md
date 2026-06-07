# examples

本目录只保存正式 NAT-IX listener 流程的占位示例。

正式示例：

- `nat-ix-listener.env`：NAT IX 机器侧中转线路。
- `public-ingress.env`：公网入口机侧入口线路。
- `multi-rules.md`：多转发规则和多端口转发示例。
- `operations.md`：创建、导入、查看和清理的常用操作。
- `diagnostics.md`：健康检查、延迟诊断和流量统计。

旧版 CNIX 面板模式、alpha 旧 NAT-IX 方向、主备和通知示例已移动到 `legacy/`，仅用于迁移历史配置，不推荐新线路使用。

占位值只用于文档：

- `ingress.example`
- `nat-ix.example`
- `landing-a.example`
- `landing-b.example`
- `10.88.0.1`
- `10.88.0.2`
- `change-me`
- `20000`
- `30000`
- `40000`
- `50000`

不要提交真实 IP、真实端口、真实 token、真实密钥、完整 IXTF1 接入码或真实客户名称。
