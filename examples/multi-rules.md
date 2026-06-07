# Multi Forwarding Rules

本示例只使用占位值。

## NAT IX 机器

新增两条落地规则：

```bash
bash install.sh add-rule nat-ix-listener-example
```

示例规则：

```text
rule-main  [默认转发]  10.88.0.2:40000 -> landing-a.example:50000  both
rule-game  [游戏落地]  10.88.0.2:40001 -> landing-b.example:50000  tcp
```

刷新接入码：

```bash
bash install.sh refresh-code nat-ix-listener-example
```

## 公网入口机

重新导入接入码后，为每条规则分配客户端入口端口：

```text
rule-main -> 30000
rule-game -> 30001
```

查看规则和流量：

```bash
bash install.sh list-rules public-ingress-example
bash install.sh traffic-report --sample 10
```

## 占位端口地图

```text
[默认转发] 30000 -> 10.88.0.2:40000 -> landing-a.example:50000
[游戏落地] 30001 -> 10.88.0.2:40001 -> landing-b.example:50000
```
