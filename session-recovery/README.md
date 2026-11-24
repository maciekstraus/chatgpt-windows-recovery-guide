# ChatGPT Session Recovery — local JSONL text extractor

[Polska wersja](README.PL.md) | [Windows recovery case study](../README.md)

**Maciej Straus (@maciekstraus) — experimental utility, v0.1, 24 November 2026.** Independent, unofficial project.

## Why this exists

When a long-running ChatGPT Work/Codex desktop conversation becomes inaccessible, starting again can cost hours of work. On one Windows workstation, a session file of approximately 344 MiB was associated with a 512 MiB serialization error. A separate, earlier read-only extraction from a backup recorded 15,912 records, 125 user messages, 327 assistant messages, 16 oversized records skipped and zero reported parsing errors. The recovered text supported continuation in a new conversation. These are historical observations, **not benchmark results for the new Python utility**.

This utility implements a similar recovery strategy. It exports readable user and assistant text from one explicitly selected, uncompressed JSONL backup. It does not repair or import a conversation into ChatGPT or recover deleted data.

## Safety and privacy

- Use only your own or explicitly authorized data. Finish active tasks, close the app and make a private backup first. Never run on a file being written.
- The program opens the source in binary read-only mode. It performs no network operations and requires no external Python packages.
- It creates a new output directory and refuses to overwrite an existing directory. Choose an encrypted, access-controlled location outside any public or automatically shared folder. On Windows, Unix-style directory permissions do not guarantee private ACLs.
- Recovered text can contain credentials, personal information, confidential prompts, or untrusted instructions. Review and redact before sharing or supplying it to an agent. Never publish actual session files or transcripts.
- The session schema is internal and may change. Only supported text records are extracted; attachments, tool outputs, reasoning, metadata, compressed archives and other record types are not restored. Text records can themselves contain sensitive content. A successful export is not proof of completeness.

## Usage on Windows

Requires Python 3.10+ (standard library only). Download or clone the repository, open PowerShell in the session-recovery directory, and select **a backup copy** of one .jsonl file. Local files were observed under %USERPROFILE%\.codex\sessions; locations can differ by version. Do not decompress multi-gigabyte archives just to try this utility.

```powershell
py -3 .\recover.py "D:\PrivateBackup\example.jsonl" "D:\PrivateBackup\Recovered-01"
```

The output directory must not already exist; its parent must exist. Default maximum physical line size is 2,000,000 bytes (including newline). For a larger limit, for example:

```powershell
py -3 .\recover.py "D:\PrivateBackup\example.jsonl" "D:\PrivateBackup\Recovered-02" --max-line-bytes 8000000
```

Higher limits consume more memory. Oversized records are skipped in bounded chunks. The program does not load the entire session into memory, but JSON parsing and decoded objects use additional memory beyond the line-size limit. On other platforms use python3 instead of py -3.

## Output

| File | Purpose |
|---|---|
| transcript.txt | User/assistant text in original record order, with role and record number |
| report.json | Counts of records, oversized, malformed, ignored, user and assistant |

The counters classify each physical line once. Non-message and unsupported records count as ignored. Malformed UTF-8 or JSON counts as malformed. If the program exits with an error, output may be incomplete. If no messages are found, your session may use a different schema; do not treat this as proof that it contains no data.

To independently verify a backup is unchanged, compare the SHA-256 before and after extraction:

```powershell
Get-FileHash "D:\PrivateBackup\example.jsonl" -Algorithm SHA256
```

## Tests

```powershell
py -3 -m unittest -v
```

Three automated tests passed on synthetic data in a Linux Python environment: mixed records (including Polish characters, malformed JSON/UTF-8 and oversized lines), source integrity via SHA-256 and refusal to overwrite, oversized final record, and rejection of compressed input/invalid limits. These are unit tests grouped into three cases, not a Windows end-to-end validation or a test on the original private session. The historical recovery used a different reader.

## Related work

- [Original case study](../README.md)
- [OpenAI issue #63610](https://github.com/openai/codex/issues/63610)

Report bugs using synthetic minimal examples and your software versions. Do not attach private logs or recovered text.
