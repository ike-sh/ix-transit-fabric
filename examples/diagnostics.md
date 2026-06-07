# NAT-IX diagnostics

本文件只使用占位值。

健康检查：

```bash
bash install.sh health nat-ix-listener-example
bash install.sh health public-ingress-example
```

延迟诊断：

```bash
bash install.sh latency-report nat-ix-listener-example
bash install.sh latency-report nat-ix-listener-example rule-main
bash install.sh latency-report public-ingress-example --sample 10
```

流量统计：

```bash
bash install.sh traffic-report
bash install.sh traffic-report --sample 10
```

规则列表：

```bash
bash install.sh list-rules nat-ix-listener-example
bash install.sh list-rules public-ingress-example
```

脱敏诊断报告：

```bash
bash install.sh export-diagnostic
```

诊断报告会脱敏网络密钥、NAT IX 接入码和通知 token。
