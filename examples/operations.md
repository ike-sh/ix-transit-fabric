# NAT-IX operations

本文件只使用占位值。

## NAT IX 机器

```bash
bash install.sh
```

菜单选择：

```text
创建 NAT IX 中转线路
```

完成后复制 NAT IX 接入码到公网入口机。

查看端口地图：

```bash
bash install.sh show-port-map --compact nat-ix-listener-example
```

预期占位链路：

```text
商家入口 -> nat-ix.example:20000
虚拟网中转 -> 10.88.0.2:31000 -> landing.example:50000
```

## 公网入口机

```bash
bash install.sh
```

菜单选择：

```text
公网入口机导入接入码
```

客户端连接：

```text
ingress.example:30000
```

预期占位链路：

```text
客户端入口端口 -> 10.88.0.2:31000 -> landing.example:50000
```

## 完全清理

```bash
bash install.sh purge
```

`purge` 会先列出删除清单，再询问是否删除 `easytier-core` 和当前 `install.sh`。
