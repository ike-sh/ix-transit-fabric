# Monitor Runbook

This runbook uses placeholders only. Do not paste real tokens, real chat ids, real IP addresses, real ports, real secrets, real access codes, or real client names into examples.

## Run Once

```bash
bash install.sh monitor-run-once
```

The monitor is read-only. It runs health checks, writes health history, verifies nftables, and sends notifications when configured. It does not run `switch-line`, does not change `FORWARD_ENABLED`, does not restart services, and does not repair nftables automatically.

## Enable Timer

```bash
bash install.sh monitor-set-interval 5
bash install.sh monitor-enable
bash install.sh monitor-status
```

The timer is disabled by default. Enable it only after the manual health report looks sane.

## Logs

```bash
bash install.sh monitor-logs
```

Monitor logs should not contain tokens, access codes, or network secrets.

## Notification Pairing

```bash
bash install.sh notify-config
bash install.sh notify-enable
bash install.sh notify-test
```

If a primary profile is down and a backup is healthy, the notification should suggest dry-run and manual switch commands. It must not perform the switch.

## Manual Response

```bash
bash install.sh health-report --group example-group
bash install.sh primary-backup-check example-group
bash install.sh switch-dry-run example-group example-backup
bash install.sh switch-line example-group example-backup
bash install.sh verify-nft-profiles
```

0.5.1-alpha still does not do automatic failover.
