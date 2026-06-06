# Switch Runbook

This runbook uses placeholders only. Do not paste real IP addresses, real ports, real secrets, real access codes, or real client names into examples.

## Prepare Primary And Backup

Use one `LINE_GROUP` for the pair:

```text
primary:
  LINE_GROUP=example-group
  LINE_ROLE=primary
  ENABLED=true
  FORWARD_ENABLED=true

backup:
  LINE_GROUP=example-group
  LINE_ROLE=backup
  ENABLED=true
  FORWARD_ENABLED=false
```

For cold standby, keep the backup disabled until needed:

```text
backup:
  ENABLED=false
  FORWARD_ENABLED=false
```

## Health Check

```bash
bash install.sh health-all
bash install.sh health-report --group example-group
bash install.sh primary-backup-check example-group
bash install.sh validate-primary-backup example-group
bash install.sh show-group example-group
```

Copy `health-report` when asking someone to help troubleshoot. It does not print secrets.

## Dry Run

```bash
bash install.sh switch-dry-run example-group example-backup
```

Dry-run is read-only. It does not write Profile files, does not restart services, and does not apply nftables.

## Formal Switch

```bash
bash install.sh switch-line example-group example-backup
bash install.sh verify-nft-profiles
bash install.sh show-group example-group
bash install.sh switch-history example-group --limit 20
```

If the target health is `down`, `switch-line` asks for the exact word `SWITCH` before continuing.

## Switch Back

```bash
bash install.sh health-all
bash install.sh switch-dry-run example-group example-primary
bash install.sh switch-line example-group example-primary
bash install.sh verify-nft-profiles
```

The helper can also use the latest successful audit record:

```bash
bash install.sh switch-rollback-last
```

It still requires `ROLLBACK`, and may require `SWITCH` if the target health is down.

## Troubleshooting

```bash
bash install.sh verify-nft-profiles
bash install.sh doctor-all
bash install.sh status-all --verbose
bash install.sh show-port-map --all
bash install.sh show-nft
```

If nftables and Profile state differ, run:

```bash
bash install.sh apply-nft-all
bash install.sh verify-nft-profiles
```

ix-transit-fabric 1.0.0 has no automatic failover. Every switch is a local CLI operation and requires operator confirmation.
