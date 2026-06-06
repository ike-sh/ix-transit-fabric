# NAT-IX Transit Runbook

This runbook uses placeholder values only.

## Ingress VPS

```bash
bash install.sh add-nat-ingress-profile
bash install.sh show-code nat-ingress-example
bash install.sh show-port-map --compact nat-ingress-example
bash install.sh health nat-ingress-example
```

Expected placeholder map:

```text
client -> ingress.example:30000
ingress nftables -> 10.88.0.2:20000
```

## NAT IX Machine

```bash
bash install.sh add-nat-transit-profile-from-code
bash install.sh show-port-map --compact nat-transit-example
bash install.sh health nat-transit-example
```

Expected placeholder map:

```text
10.88.0.2:20000 -> landing.example:50000
```

The NAT IX machine only forwards with nftables. It does not install or configure proxy services. The landing service is `landing.example:50000`.
