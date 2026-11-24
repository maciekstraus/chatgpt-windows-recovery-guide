# ChatGPT Desktop on Windows: recovery from MessagePort crashes and Chrome access failures

[Polska wersja](README.PL.md) | [Technical report](BUG-REPORT.md) | [OpenAI issue #63610](https://github.com/openai/codex/issues/63610)

**Maciej Straus (@maciekstraus) — 24 November 2026.** Independent field report from one workstation, not an official OpenAI fix.

## Quick answer

On this workstation, switching the main desktop package to **26.1117.3838.0** restored large attachments and Chrome access in fresh Work chats, including a new chat inside an existing project. The primary runtime and Chrome extension were left unchanged. Some old chats still failed. Try a fresh Work chat first; do not downgrade a working installation.

## Symptoms and evidence

During business workflows in ChatGPT Work, large attachments and some long-running conversations began causing `A JavaScript error occurred in the main process` / `Error: Peer closed MessagePort connection`. Repair, reset after backup, restart and updating did not resolve the issue. A fresh conversation also crashed during work with a photo batch totaling approximately 209 MB. Earlier batches of 500 MB–1 GB had worked on the same machine.

One log associated with an existing session contained:
```text
RangeError: Message exceeds the 536870912-byte serialization limit
MessagePortMain.postMessageWithSizeLimit (node:electron/js2c/utility_init:2:964)
```
The corresponding JSONL file was approximately 344 MiB. The error establishes a serialization failure for that session, not a universal attachment-size limit. The cause of the separate fresh-session crash was not independently established.

## Test environment and version comparison

Windows 11 Pro 26H2, build 26300.10075, x64; Windows PowerShell 5.1; Chrome 157.0.8103.79; ChatGPT extension 1.26.1120.11331; runtime 26.1123.915.0 during rollback tests.

| Desktop MSIX version | Large attachments | Chrome in Work |
|---|---|---|
| 26.1120.5083.0 | Crashes observed | Not independently tested |
| 26.1117.4957.0 | Crashes observed | Not independently tested |
| 26.1111.9664.0 | Worked in a new chat (21 photos) | Failed in tested Work session |
| **26.1117.3838.0** | **Worked** | **Worked in fresh Work chats, including within an existing project** |

The intermediate build restored both capabilities in these tests. The old Work conversation still returned `Browser access requires the originating browser context`. The Chrome extension itself could read the active page from its own panel. A fresh desktop Work chat listed 13 tabs; another fresh Work chat inside the affected project accessed the same authenticated CMS, local files and recovered task materials. No claim is made that all historical sessions were restored. These observations suggest a version or session-context issue, but do not establish root cause.

## Recovery procedure

> **Warning:** An older application can introduce security, compatibility and data-loss risks. This is a temporary workaround, not a supported long-term update policy. Use supported recovery options first. On managed computers obtain IT approval. Never disable signature verification, use untrusted packages, or delete sessions to follow this guide.

### 1. Inspect the installed packages
```powershell
Get-AppxPackage *OpenAI* | Select-Object Name, Version, Status
```
To inspect recent deployment events, use an elevated PowerShell if needed:
```powershell
Get-WinEvent -FilterHashtable @{
    LogName = 'Microsoft-Windows-AppXDeploymentServer/Operational'
    StartTime = (Get-Date).AddDays(-14)
} | Where-Object { $_.Message -match 'OpenAI\.Codex' } |
    Select-Object TimeCreated, Id, Message
```
Events can reference packages being removed as well as installed. Do not publish raw logs. Relevant local desktop logs on this machine were under `%LOCALAPPDATA%\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\Codex\Logs`.

### 2. Back up before changing anything

Finish active tasks and close the desktop application. Make separate private copies of `%USERPROFILE%\.codex`, relevant OpenAI package data under `%LOCALAPPDATA%\Packages`, and all external project folders. Verify copy results and important files. A backup may contain locked or protected files; a partial copy is not a complete recovery guarantee. In this case the main `.codex` directory was copied successfully, while some locked package-system files were excluded. Never assume cloud sync covers all local Work chats. Keep the original and backup separate; do not use destructive mirroring or delete the original.

### 3. Obtain and verify the signed package

The versioned vendor-hosted URL below returned HTTP 200 on 24 November 2026. Availability may change. Use the vendor's distribution infrastructure only.
```powershell
$v = '26.1117.3838.0'
$file = Join-Path $env:USERPROFILE "Downloads\ChatGPT-$v.msix"
curl.exe -f -L "https://persistent.oaistatic.com/codex-app-prod/releases/$v/ChatGPT-x64.msix" -o $file
if ($LASTEXITCODE -ne 0) { throw 'Download failed' }
Get-Item $file | Select-Object Name, Length
$sig = Get-AuthenticodeSignature $file
$sig | Format-List Status, StatusMessage, SignerCertificate
if ($sig.Status -ne 'Valid') { throw 'Invalid or untrusted signature' }
Get-AppxPackage OpenAI.Codex | Format-List Name, Publisher, PackageFamilyName, Version
```
Observed length: **811237227 bytes**. Signature: `Valid`. The signing subject and installed package publisher matched `CN=50BDFD77-8903-4850-9FFE-6E8522F64D5B`; issuer Microsoft Marketplace CA G 028. Stop if the signature or package identity does not match. A valid signature is not a guarantee that an old release is secure.

Read the manifest without extracting the full package:
```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($file)
try {
    $reader = New-Object IO.StreamReader($zip.GetEntry('AppxManifest.xml').Open())
    try { [xml]$manifest = $reader.ReadToEnd() } finally { $reader.Dispose() }
    $manifest.Package.Identity | Format-List Name, Version, Publisher, ProcessorArchitecture
    $manifest.Package.Dependencies.OuterXml
} finally { $zip.Dispose() }
```
Expected identity: `OpenAI.Codex`, version `26.1117.3838.0`, x64, matching publisher. No specific runtime package was declared in Dependencies; this does not guarantee runtime compatibility.

### 4. Install in place, only after backup and verification

The first attempt to install an earlier package failed with `0x80073D02` because the application was in use. The following command worked after active work was saved. The shutdown switch can terminate tasks. No uninstall was required in this case.
```powershell
Add-AppxPackage -Path $file -ForceUpdateFromAnyVersion -ForceTargetApplicationShutdown -ErrorAction Stop
Get-AppxPackage *OpenAI* | Select-Object Name, Version, Status
```
See [Microsoft documentation for Add-AppxPackage](https://learn.microsoft.com/en-us/powershell/module/appx/add-appxpackage?view=windows-11). Do not change the runtime, native host registration or browser permissions just to match this case.

### 5. Retest with a fresh Work session

- Open a new desktop Work chat and select the Chrome integration. Ask it to list tabs or read a non-sensitive page, without making changes.
- Repeat in a new chat within the affected project. Test a small attachment and then a representative larger batch of non-sensitive files.
- Verify the installed version again. If only an existing chat fails, preserve it and transfer the task via a local handoff document and prepared files instead of repeated retries.
- A Microsoft Store policy `AutoDownload=2` was temporarily set during this case. It affects Store apps broadly, not just ChatGPT, and is not proof that independent OpenAI updates are blocked. Use approved update controls only; restore the original setting promptly after testing or when a stable supported version is available. Never permanently block security updates.

## Remaining issues and privacy

Some very large historical conversations still failed to load. Text was partially recovered from a private backup of one JSONL session by reading records without modifying the original and skipping oversized records. This is partial text recovery, not restoration of a conversation in the application. Backups can contain prompts, credentials, images, tool responses and business data. Never upload `.codex`, browser profiles or raw logs to GitHub.

## Related reports and next steps

- [Our public OpenAI report #63610](https://github.com/openai/codex/issues/63610)
- [#63011](https://github.com/openai/codex/issues/63011): Windows image attachment failure with the MessagePort error.
- [#62793](https://github.com/openai/codex/issues/62793) and [#62170](https://github.com/openai/codex/issues/62170): 512 MiB serialization failures on macOS.
- [#57491](https://github.com/openai/codex/issues/57491) and [#57523](https://github.com/openai/codex/issues/57523): originating browser context errors.

OpenAI should investigate bounded/paginated history serialization, recoverable error handling and browser context binding in Work. If you encounter similar symptoms, report your versions and sanitized observations; do not assume the same root cause. This is a one-workstation field report, not a recommendation to install an old build on every affected machine.

## Companion project: ChatGPT Session Recovery

[Local JSONL text extractor and tests](session-recovery/README.md) — experimental, offline utility for extracting readable text from a private backup without modifying the source. Includes a Polish guide and synthetic tests.
