# Traffic Notes

This note uses placeholders only. Do not include real IP addresses, real ports, real secrets, real access codes, Telegram tokens, or real client names.

## Commands

```bash
bash install.sh traffic-status
bash install.sh traffic-status example-profile
bash install.sh traffic-report
bash install.sh traffic-report --group example-group
```

Traffic counters come from nftables:

```bash
nft list table ip ix_transit_fabric
```

The project rules include `counter` on DNAT and masquerade rules after `apply-nft-all` has rendered the ix-transit-fabric 1.0.0 table.

## Reset

```bash
bash install.sh traffic-reset-all
```

The current release resets all project counters by reapplying the project nftables table. Single Profile reset is not precise yet.

## Limits

The traffic report counts forwarding rule hits on the ingress host. It is not cloud billing traffic, not global NIC traffic, and not a replacement for provider-side accounting. Cloud providers may count both directions or use billing rules that differ from nftables counters.
