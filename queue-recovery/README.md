# Windows SQLite queue recovery (unofficial)

**24 November 2026 — one Windows workstation, user-reported 9/9 smoke tests passed after a targeted repair.** Credit: [Shinshin124's macOS investigation](https://github.com/openai/codex/issues/63217#issuecomment-7128925968). See [our technical report](../BUG-REPORT.md) and [OpenAI issue #63610](https://github.com/openai/codex/issues/63610).

## Evidence

Desktop 26.1117.3838.0 (rollback had helped only temporarily). Earlier logs recorded a 536870912-byte serialization rejection in one session. The local settings database was 281.89 MiB; its global queued-follow-ups setting held 292,893,447 bytes (279.325 MiB), exactly one array with one pending message and an inline data:image/ marker. The full session ID matched the earlier logged failure. A read-only simulation returned a two-byte empty object. After a hash-verified backup, a guarded SQLite transaction removed only that session's pending queue entry. JSON valid, quick_check ok, backup unchanged. All nine immediate user-reported tests passed: startup, projects/history, original affected conversation, first and second text messages, new Work chat, Chrome integration, one image, several images. No version change during the repair. Physical database size unchanged; no VACUUM.

This is evidence of recovery in this case, not proof of the exact oversized RPC, universal causation, a safe attachment-size limit, or long-term stability.

## Use the tool cautiously

First use supported recovery options and contact support/IT where appropriate. Finish all tasks and quit desktop ChatGPT/Codex. Keep a full private backup of local histories, settings and project files. The script uses Windows PowerShell 5.1 and winsqlite3.dll; it needs no third-party package. Review the source before running locally. It is a generalized derivative of the procedure used on this workstation, **not independently executed or end-to-end tested on Windows**. It stops on an unexpected database/schema/WAL or queue shape. Never delete WAL/SHM, reset a profile, or restore a whole old database over newer work blindly.

From the directory containing the downloaded script:
```powershell
.\Recover-Queue.ps1
```
Audit mode makes a temporary hash-verified copy, checks integrity and prints queue sizes, entry IDs, counts and an image marker only. Do not publish thread IDs or private backups.

Only if there is one problematic entry containing one unsent message, and you have confirmed that message can be discarded, run:
```powershell
.\Recover-Queue.ps1 -Repair -ThreadId '<your own GUID>' -ExpectedBytes <Total_bytes from audit>
```
Replace both placeholders. The tool retains a private backup, requires explicit confirmation and verifies a single-entry/single-message shape before a guarded transaction. Other queue shapes intentionally require separate diagnosis. The message text and attachments are discarded from the active queue but remain in the backup. This is not secure erasure. No session history database is targeted. The backup may contain confidential data; never upload it. If a failure occurs before COMMIT, closing the SQLite connection rolls back the unfinished transaction; after COMMIT, stop and inspect rather than rerunning. If restoration is needed, quit the application, preserve the current database and any WAL/SHM, and seek help restoring a consistent backup; a full restore can overwrite later settings.

Retest startup, existing and new chats, two successive text messages, read-only browser access and small non-sensitive attachments. Keep the original backup until stability is established. Do not downgrade solely because of this report.

[Polska wersja](README.PL.md)
