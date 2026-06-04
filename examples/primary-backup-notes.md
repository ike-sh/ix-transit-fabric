# Primary / Backup Notes

This example uses placeholders only. Do not put real IP addresses, real ports, real secrets, real access codes, or real client names in example files.

## Example Group

```text
LINE_GROUP=example-group

example-primary:
  LINE_ROLE=primary
  LINE_PRIORITY=<PRIMARY_PRIORITY>
  ENABLED=true
  FORWARD_ENABLED=true

example-backup:
  LINE_ROLE=backup
  LINE_PRIORITY=<BACKUP_PRIORITY>
  ENABLED=true
  FORWARD_ENABLED=false
```

Hot standby keeps both EasyTier instances running. Only the active ingress Profile has `FORWARD_ENABLED=true`.

Cold standby keeps the backup disabled until it is needed:

```bash
bash install.sh enable-profile example-backup
bash install.sh start-profile example-backup
```

## Real-Machine Check

```bash
bash install.sh health-all
bash install.sh health-report --group example-group
bash install.sh primary-backup-check example-group
bash install.sh primary-backup-runbook example-group
bash install.sh primary-backup-summary
```

## Manual Switch

```bash
bash install.sh switch-dry-run example-group example-backup
bash install.sh switch-line example-group example-backup
bash install.sh verify-nft-profiles
bash install.sh show-group example-group
bash install.sh switch-history example-group
```

0.5.1-alpha still does not do automatic failover. Switches are manual and require operator confirmation.

`switch-dry-run` is read-only. It does not write Profile files, does not restart services, and does not apply nftables. `switch-line` is the command that changes `FORWARD_ENABLED` and runs `apply-nft-all`.
