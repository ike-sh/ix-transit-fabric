# Multi-line notes

Example layout:

```text
example-main
  LOCAL_PORT=20000
  CNIX_ENTRY_HOST=cnix-entry.example
  CNIX_ENTRY_PORT=30000
  LISTENER_PORT=40000
  REMOTE_PORT=20000

example-backup
  LOCAL_PORT=20000
  CNIX_ENTRY_HOST=cnix-entry.example
  CNIX_ENTRY_PORT=30000
  LISTENER_PORT=40000
  REMOTE_PORT=20000
```

Rules:

- Keep every `PROFILE_ID` unique.
- Keep every `LOCAL_PORT` unique on the same ingress VPS.
- Keep every `LISTENER_PORT` unique on the same landing VPS.
- Keep every `ET_SUBNET` unique unless you are intentionally sharing one EasyTier network.
- CNIX panel outlet always uses `LISTENER_PORT`.
- `REMOTE_PORT` is the landing business service port.
