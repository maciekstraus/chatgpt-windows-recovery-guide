# ChatGPT Desktop Health Audit V2 (Windows)

[Polska wersja](README.PL.md) | [PowerShell source](ChatGPT-Health-Audit-v2.ps1) | [Technical report](../BUG-REPORT.md) | [Queue recovery](../queue-recovery/README.md)

**Independent read-only diagnostic utility, field-tested on 25 November 2026 on one Windows workstation.** Not an official OpenAI tool or a guarantee of safety across versions. No automatic repair, no network operations, no original database or history modifications.

## Run locally

Requires Windows PowerShell 5.1 x64, Windows-provided winsqlite3.dll and sufficient temporary disk space for the largest database and its WAL. Finish tasks and fully quit desktop ChatGPT/Codex; keep Chrome open if desired. Download the PowerShell source and review it. On managed systems follow IT policy. Do not disable system-wide execution policy.

```powershell
# Adjust path and optional local log cutoff to your own environment.
$p = Join-Path $env:USERPROFILE 'Downloads\ChatGPT-Health-Audit-v2.ps1'
Get-FileHash -LiteralPath $p -Algorithm SHA256
& $p -Since (Get-Date).AddDays(-1)
```

SHA256 of the exact published, field-tested file (UTF-8 BOM, LF): `6386d40dde2ece314e187618fb7232941d3d0ba37e6f81527977bee84e9d2ef9`.
If scripts are disabled, consult the administrator or use an approved execution method. On the test workstation, a reviewed local script was launched with a one-process execution-policy override, not a permanent policy change. The script intentionally refuses to start when ChatGPT or Codex processes are detected.

## What it measures

- Installed OpenAI packages, free disk space, local SQLite database sizes, WAL sizes, structural quick_check, page and freelist statistics.
- Global queued-follow-ups byte count, bounded JSON details (64 MiB parsing guard), separate queue database, top-level queue in JSON state and its backup.
- Local session file inventory, largest on-disk sizes, bounded media-marker samples (no compressed session decompression), private project and PDF-candidate inventory.
- Bounded desktop log tails: matching lines for serialization, MessagePort, Chrome context, OOM and SQLite errors; not unique incidents.

Reports appear in a new AUDYT_CHATGPT_* folder on the Desktop. **Review even the aggregate 01_PODSUMOWANIE.txt before sharing.** Keep the remaining reports private: they can contain titles, thread identifiers and filesystem paths. Do not publish raw logs, attachments, databases or backups. Temporary database copies also contain sensitive data; normal cleanup is not secure erasure.

## Field validation: 25 November 2026

| Measurement | Before second repair, 22:42 local | After repair and six smoke tests, 22:54 local |
|---|---:|---:|
| Global pending queue bytes | 274,205,978 | 2 |
| Reusable settings DB pages | 4,690 | 71,701 |
| Reusable space (MiB) | 18.320 | 280.082 |
| Structural quick_check | 7/7 ok | 7/7 ok |
| Audit warnings | 1 | 0 |
| Session files | 1,700 | 1,701 |
| History item records | 81,956 | 81,965 |

Both audits completed on desktop 26.1117.3838.0, runtime 26.1123.915.0. Targeted queue repair was performed separately; this script did not perform it. The post-repair run found zero matching lines in three recently modified log files, with cutoff 22:48:52 local; this is a short, bounded observation. A first attempt while the desktop was running correctly aborted. Six user-reported checks passed; new Work chat, small image and local image-folder access were not tested after the second repair. Aggregate counts are not a proof of complete preservation or sync.

## Limitations and next steps

This is an offline, closed-app audit, not a live monitor. It copies main DB and WAL using size/mtime consistency checks, not an atomic SQLite backup; keep the app closed throughout. The 64 MiB guard is a diagnostic choice, **not a product limit**. Large queue details require a separate read-only diagnostic. A missing/invalid schema, interrupted process or locked file may leave incomplete results. A completed script with zero warnings is not a comprehensive health certification. JSON check is top-level only; log search is limited to 30 recent files and 4 MiB per tail, excluding SQLite log contents. Session sizes are not RPC sizes. PDF candidates are not proven project attachments, and cloud-only data is outside scope. No guarantee of complete coverage or safe live snapshots. Do not use this report to justify deleting history, WAL/SHM files or compacting databases. Reusable SQLite pages are not a reason to run VACUUM.

If a problematic draft is accessible in the UI, try cancelling that specific unsent message first, with permission to discard it. See [the documented macOS UI-only recovery](https://github.com/openai/codex/issues/63217#issuecomment-7163980390). Otherwise obtain a verified private backup and assess the [targeted queue procedure](../queue-recovery/README.md). An alert-only monitor and a local-file image workflow are proposed next steps, not delivered or validated by this audit.
