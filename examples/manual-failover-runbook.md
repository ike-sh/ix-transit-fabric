# Manual Failover Runbook

This document is intentionally generic. It must not contain real IP addresses, real ports, real secrets, real access codes, or real client names.

## Normal Switch

```bash
bash install.sh health-all
bash install.sh health-report --group example-group
bash install.sh primary-backup-check example-group
bash install.sh switch-dry-run example-group example-backup
bash install.sh switch-line example-group example-backup
bash install.sh verify-nft-profiles
bash install.sh show-group example-group
```

`switch-dry-run` is read-only. `switch-line` changes `FORWARD_ENABLED` for ingress Profiles in the same `LINE_GROUP` and runs `apply-nft-all`.

## Primary Failure To Backup

When the report shows primary down and backup healthy:

```bash
bash install.sh health-report --group example-group
bash install.sh primary-backup-check example-group
bash install.sh switch-dry-run example-group example-backup
bash install.sh switch-line example-group example-backup
```

If the target backup is down, do not switch to it until the reason is understood.

## Backup Switch Back To Primary

After the primary is healthy again:

```bash
bash install.sh health-all
bash install.sh switch-dry-run example-group example-primary
bash install.sh switch-line example-group example-primary
bash install.sh verify-nft-profiles
```

Or use the latest successful audit record:

```bash
bash install.sh switch-rollback-last
```

The rollback helper requires `ROLLBACK` before it calls `switch-line`.

## nftables Verification

```bash
bash install.sh verify-nft-profiles
```

If the output lists missing rules, extra rules, disabled Profile residual rules, standby residual rules, or unknown `LOCAL_PORT` rules, repair with:

```bash
bash install.sh apply-nft-all
bash install.sh verify-nft-profiles
```

## Health Report For Troubleshooting

```bash
bash install.sh health-report
bash install.sh export-health-report --file /tmp/ix-health-report.txt
```

The report is designed to be copied into a troubleshooting conversation. It should show Profile, group, role, forwarding, service, IP presence, nftables state, health and reason, without exposing secrets.

## Reminder

0.5.1-alpha still does not do automatic failover. The operator decides whether to switch after reading health, dry-run and nftables verification output.
