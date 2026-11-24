# Technical report: Windows Work recovery

Originally submitted as [OpenAI Codex issue #63610](https://github.com/openai/codex/issues/63610), 24 November 2026, by Maciej Straus (@maciekstraus).

[Full English guide](README.md) | [Polska instrukcja](README.PL.md)

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
| **26.1117.3838.0** | **Worked** | **Worked in fresh Work chats, including inside an existing project** |

## Recovery and reproduction notes

Repair, reset after backup, restart and updating did not resolve the original problem. I backed up local data, obtained vendor-hosted MSIX files, verified Authenticode signatures and package identity, and switched the main package in place using PowerShell's `Add-AppxPackage -ForceUpdateFromAnyVersion -ForceTargetApplicationShutdown`. The initial attempt returned `0x80073D02` because the package was in use. Runtime and the Chrome extension were not rolled back. No sessions were intentionally deleted.

With 26.1117.3838.0:
- A fresh desktop Work chat listed all 13 open Chrome tabs and read an authenticated CMS page.
- A fresh Work chat inside the affected project also accessed Chrome, local files and recovered task materials.
- Large attachments worked again.
- The existing problematic Work chat still could not connect to Chrome, and some very large historical chats remained inaccessible.

A useful comparison is to test the same authorized browser operation in an affected existing Work chat and in a fresh Work chat, then test a representative non-sensitive attachment batch. This is a field report, not a deterministic minimal reproduction. The root cause (version regression, session context, protocol compatibility or another factor) is not established. Rollback is a temporary workaround with security and compatibility risks, not a universal fix.

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

