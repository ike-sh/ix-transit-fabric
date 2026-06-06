# NAT-IX Transit Runbook

This runbook uses placeholder values only.

## NAT IX Machine

```bash
bash install.sh add-nat-listener-profile
bash install.sh show-code nat-transit-example
bash install.sh show-port-map --compact nat-transit-example
bash install.sh health nat-transit-example
```

Expected placeholder map:

```text
merchant entry -> nat-ix.example:20000
virtual transit -> 10.88.0.2:31000 -> landing.example:50000
```

## Public Ingress VPS

```bash
bash install.sh add-nat-ingress-from-listener-code
bash install.sh show-port-map --compact nat-ingress-example
bash install.sh health nat-ingress-example
```

Expected placeholder map:

```text
client -> ingress.example:30000
ingress nftables -> 10.88.0.2:31000
```

The NAT IX machine only forwards with nftables. It does not install or configure proxy services. The landing service is `landing.example:50000`.
