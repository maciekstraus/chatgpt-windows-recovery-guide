# Technical report: Windows Work recovery

Originally submitted as [OpenAI Codex issue #63610](https://github.com/openai/codex/issues/63610), 24 November 2026, by Maciej Straus (@maciekstraus).

[Full English guide](README.md) | [Polska instrukcja](README.PL.md)

## Follow-up: recurrence and second targeted recovery (2026-11-25)

Same workstation, desktop 26.1117.3838.0, runtime 26.1123.915.0. After the first recovery, the user resumed normal work, reporting approximately 150 images during the day and a further attempted batch of about 30 when the crash recurred. These counts are estimates; the exact raw batch size and RPC amplification were not measured. No version change during the two repairs.

| Measurement | 24 Nov before / after repair | 25 Nov before / after repair + tests |
|---|---:|---:|
| Global queued-follow-ups bytes | 292,893,447 / 2 | 274,205,978 / 2 |
| Pending entries / messages | 1/1 → 0/0 | 1/1 → 0/0 |
| Inline image marker before | present | present |
| Same full affected thread GUID | yes | yes |
| Physical settings DB | 281.89 MiB unchanged | 281.891 MiB unchanged |
| Reusable settings DB space | not recorded | 18.320 → 280.082 MiB |
| Structural quick_check (all audited DBs) | settings DB ok after | 7/7 ok before and after |
| User-reported functional checks | 9/9 passed | 6/6 performed passed; 3 deferred |

The 22:42 audit (local time) recorded the large queue, 6 serialization and 3 MessagePort matching log lines since 24 Nov 23:35:37; counts are not unique incidents and the cutoff predates the first repair completion. Separate queue DB had 0 items; both global JSON files had zero top-level queue entries. The large queue exceeded the audit's 64 MiB parsing guard, not a product limit. A separate read-only query on a fresh SHA256-verified backup confirmed valid JSON object, one array with one message, inline image marker, and the exact same full thread ID. With the desktop closed, the user authorized a guarded transaction that removed only this entry. COMMIT succeeded; queue {}, 2 bytes; valid JSON; quick_check ok; backup hash unchanged. No VACUUM, no history database edits.

After restart, six user-reported checks passed: startup, projects/history visibility, original affected conversation, first and second text messages, Chrome integration. New Work Local, one small image, and local image-folder access were explicitly deferred (not failures). The 22:54:32 audit after these tests and a clean desktop exit confirmed an empty queue, zero audit warnings, seven database quick_check results ok, five local project folders and 83 PDF candidates unchanged. Session file count 1700 → 1701; history item records 81956 → 81965; turns 5253 → 5255. These aggregate counts do not establish complete history preservation or sync. Four session files exceeded 512 MiB on disk, including a large compressed session; no decompression or deletion was performed. On-disk size is not RPC size.

The second audit inspected three recently modified log files, bounded to 4 MiB tails, and found no matching serialization, MessagePort, Chrome context, OOM or SQLite error lines after 22:48:52 local. This short window and bounded scan do not establish absence of all errors. A first attempted audit correctly refused to start while the desktop was running. The exact [Health Audit V2 script](health-audit/ChatGPT-Health-Audit-v2.ps1) ran twice on the workstation; [English instructions](health-audit/README.md) / [Polish instructions](health-audit/README.PL.md). It does not repair anything and is not a live monitor; the case-specific SQL repair is distinct from the generalized recovery script, which remains independently untested end-to-end.

### Corroborating reports and updated recovery priority

- [#63592](https://github.com/openai/codex/issues/63592): independent Windows report of roughly 356 MB pending image data also persisted in both JSON files; recovery by clearing queued data. Not our exact procedure.
- [#63217 — CHUAN33](https://github.com/openai/codex/issues/63217#issuecomment-7163980390): macOS M4 Pro, queue 317.5 MiB → 34.2 MiB after cancelling unsent images and draft in app UI, two successful text turns without SQLite edits.
- [#62901](https://github.com/openai/codex/issues/62901): further Windows reports on 26.1120.6357.0; profile rename/reset reported to help another user, but original problematic conversation not restored.
- [#63798](https://github.com/openai/codex/issues/63798): newer Windows build browser handoff MessagePort failure; causal relationship unverified.

Use UI cancellation of the identified unsent message first when accessible and authorized; targeted offline recovery is a fallback. The two cycles support a recurring persisted image-queue failure in this workstation, not a universal explanation, safe attachment threshold, or permanent fix. Request pre-persistence attachment validation, bounded queue serialization, graceful rejection and startup recovery, and documented non-destructive queue inspection/cancellation. Proposed next tests: local directory image workflow and alert-only monitoring. No live monitor or workflow validation yet.

## Follow-up: targeted SQLite recovery (2026-11-24, evening)

The earlier rollback to 26.1117.3838.0 did not remain stable: a subsequent text-only follow-up triggered MessagePort again. The queue hypothesis from [#63217](https://github.com/openai/codex/issues/63217#issuecomment-7128925968) was then tested on the Windows workstation, with no further version change during the queue repair.

| Measurement | Before | After |
|---|---:|---:|
| Global queued-follow-ups value | 292,893,447 bytes | 2 bytes |
| Pending entries / messages | 1 / 1 | 0 / 0 |
| Inline data:image/ marker | present | absent (empty object) |
| Physical settings DB | 281.89 MiB | 281.89 MiB |
| SQLite quick_check | not recorded | ok |

The full queue entry GUID matched the session associated with the earlier 536870912-byte serialization error. A private SHA256-verified backup was made. Read-only simulation yielded an empty JSON object. A guarded SQLite transaction using Windows PowerShell 5.1 and winsqlite3.dll removed only the identified pending entry, leaving the row itself and history databases in place. After COMMIT: valid JSON, queue {}, quick_check ok, backup hash unchanged. No VACUUM. The user authorized removal of that unsent message and reported that the needed materials had already been sent.

All nine immediate user-reported smoke tests passed: application launch, projects/history visibility, opening the original affected chat, first text message, second text message, new Work chat, Chrome integration, single image, several images. These are user-reported outcomes, not independently instrumented or long-duration tests. No proof that all historical chats or sync issues were restored.

The 279.325 MiB persisted value and 512 MiB RPC limit are different measurements; the exact serialization pathway/amplification is not established. The queue is a strong candidate in this case, not a universal explanation for every MessagePort/browser error. Recommend bounded queue serialization, graceful handling of oversized queued images, documented non-destructive queue inspection/cancellation, and recovery that preserves local histories. Please keep the issue open for maintainer triage.

[Generalized guarded PowerShell tool and limitations](queue-recovery/README.md) | [Polska wersja](queue-recovery/README.PL.md). The generalized tool is not independently end-to-end tested on Windows; the case-specific predecessor ran successfully on the affected workstation. Private session identifiers, attachments, project names, raw logs and database contents are omitted.

## Environment

- Date: 2026-11-24; Windows 11 Pro 26H2 build 26300.10075, x64
- ChatGPT Desktop MSIX package: `OpenAI.Codex`
- Affected versions: 26.1117.4957.0 and 26.1120.5083.0
- Runtime during rollback tests: 26.1123.915.0 (unchanged)
- Chrome 157.0.8103.79; ChatGPT extension 1.26.1120.11331
- ChatGPT Work with local files, image attachments and browser integration

## Expected behavior

Existing sessions should load without crashing; fresh Work chats should process attachments and access explicitly authorized Chrome tabs. Large session histories should fail gracefully rather than close the main-process MessagePort.

## Actual behavior

1. A main-process JavaScript error appeared: `Error: Peer closed MessagePort connection`. A local log associated with one existing large session contained:
   ```text
   RangeError: Message exceeds the 536870912-byte serialization limit
   MessagePortMain.postMessageWithSizeLimit (node:electron/js2c/utility_init:2:964)
   ```
   The corresponding JSONL file was approximately 344 MiB. The 512 MiB value is the observed serialization limit, not an established attachment-size limit.
2. A fresh Work conversation also failed while working with a photo batch totaling approximately 209 MB. Batches of 500 MB–1 GB had worked a few days earlier. I have not independently established the cause of this separate failure.
3. After rolling back to 26.1111.9664.0, new chats and a batch of 21 photos worked, but the tested Work session could not access Chrome: `Browser access requires the originating browser context`. The Chrome extension itself could read the active page from its panel. The correct Chrome profile, extension, native host path and site permissions were present. Restarting and toggling the extension did not resolve that session's failure.

## Version comparison (same workstation)

| Desktop MSIX version | Large attachments | Chrome in Work |
| --- | --- | --- |
| 26.1120.5083.0 | Crashes observed | Not independently tested |
| 26.1117.4957.0 | Crashes observed | Not independently tested |
| 26.1111.9664.0 | Worked in new chat | Failed in tested Work session |
| **26.1117.3838.0** | Initially worked; later queue-related recurrence | **Worked in fresh Work chats, including inside an existing project** |

## Recovery and reproduction notes

Repair, reset after backup, restart and updating did not resolve the original problem. I backed up local data, obtained vendor-hosted MSIX files, verified Authenticode signatures and package identity, and switched the main package in place using PowerShell's `Add-AppxPackage -ForceUpdateFromAnyVersion -ForceTargetApplicationShutdown`. The initial attempt returned `0x80073D02` because the package was in use. Runtime and the Chrome extension were not rolled back. No sessions were intentionally deleted.

With 26.1117.3838.0:
- A fresh desktop Work chat listed all 13 open Chrome tabs and read an authenticated CMS page.
- A fresh Work chat inside the affected project also accessed Chrome, local files and recovered task materials.
- Large attachments worked again.
- The existing problematic Work chat still could not connect to Chrome, and some very large historical chats remained inaccessible.

A useful comparison is to test the same authorized browser operation in an affected existing Work chat and in a fresh Work chat, then test a small non-sensitive attachment only if needed; do not deliberately reproduce an oversized queue. This is a field report, not a deterministic minimal reproduction. The root cause (version regression, session context, protocol compatibility or another factor) is not established. Rollback is a temporary workaround with security and compatibility risks, not a universal fix.

## Related reports

- #63011 — Windows image attachment failures with the same MessagePort error.
- #62793 and #62170 — 512 MiB serialization failures on macOS.
- #57491 and #57523 — originating browser context errors.

## Suggested investigation

- Bound or paginate session-history serialization and surface recoverable errors rather than losing the MessagePort connection.
- Investigate why Chrome access succeeds in a fresh Work chat but fails in an existing chat.
- Provide a documented Windows recovery procedure preserving local-only histories.

Private project data, session IDs, raw browser URLs and full logs are intentionally omitted.

## Podsumowanie po polsku

24 listopada 2026 r. na Windows 11 przetestowałem cztery wersje aplikacji ChatGPT Desktop. W wersjach 26.1117.4957.0 i 26.1120.5083.0 występowały awarie MessagePort. W logach jednej rozbudowanej sesji potwierdziłem przekroczenie limitu serializacji 512 MiB. Cofnięcie aplikacji do 26.1111.9664.0 przywróciło obsługę zdjęć, lecz testowana sesja Work nie uzyskała dostępu do Chrome. Wersja **26.1117.3838.0** przywróciła obie funkcje w nowych rozmowach Work, również w istniejącym projekcie. Nie zmieniałem Runtime ani rozszerzenia Chrome podczas porównania wersji. Niektóre stare rozmowy nadal nie działają prawidłowo. To udokumentowane obejście na jednym komputerze, nie oficjalna naprawa ani dowód przyczyny źródłowej. Przed zmianą wersji należy zabezpieczyć dane, zweryfikować podpis instalatora i uwzględnić ryzyko starszego oprogramowania.

