# Windows PowerShell 5.1; unofficial local recovery tool.
# Default: audit a temporary copy. -Repair requires explicit target and size.
[CmdletBinding()]
param(
    [switch]$Repair,
    [guid]$ThreadId,
    [long]$ExpectedBytes = 0
)
$ErrorActionPreference = 'Stop'
$root = "$env:USERPROFILE\.codex"
if ($env:CODEX_HOME) { $root = $env:CODEX_HOME }
$db = Join-Path $root '.codex-global-state.sqlite'
function Assert-Closed {
    if (Get-Process -Name ChatGPT,codex -ErrorAction SilentlyContinue) {
        throw 'Finish active tasks and quit ChatGPT Desktop and Codex first.'
    }
    if (Test-Path -LiteralPath "$db-wal") {
        if ((Get-Item -LiteralPath "$db-wal").Length -gt 0) {
            throw 'Nonempty WAL; stop. Do not delete WAL or SHM files.'
        }
    }
}
Assert-Closed
if (-not (Test-Path -LiteralPath $db -PathType Leaf)) { throw 'Database missing.' }
if ($Repair -and ($ThreadId -eq [guid]::Empty -or $ExpectedBytes -le 2)) {
    throw 'Repair requires -ThreadId and -ExpectedBytes from the audit.'
}
if (-not ('LocalQueueRecovery20261124' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class LocalQueueRecovery20261124 {
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate int Callback(IntPtr arg, int count, IntPtr values, IntPtr names);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    private static extern int sqlite3_open_v2(byte[] path, out IntPtr db, int flags, IntPtr vfs);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    private static extern int sqlite3_exec(IntPtr db, byte[] sql, Callback cb, IntPtr arg, out IntPtr error);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    private static extern int sqlite3_close(IntPtr db);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    private static extern void sqlite3_free(IntPtr ptr);
    public static string[] Run(string path, string sql, bool write) {
        IntPtr db;
        int rc = sqlite3_open_v2(Encoding.UTF8.GetBytes(path + "\0"), out db, write ? 2 : 1, IntPtr.Zero);
        try {
            if (rc != 0) throw new Exception("SQLite open error: " + rc);
            List<string> output = new List<string>();
            Callback cb = delegate(IntPtr arg, int count, IntPtr values, IntPtr names) {
                List<string> row = new List<string>();
                for (int i = 0; i < count; i++) {
                    string name = Marshal.PtrToStringAnsi(Marshal.ReadIntPtr(names, i * IntPtr.Size));
                    string value = Marshal.PtrToStringAnsi(Marshal.ReadIntPtr(values, i * IntPtr.Size));
                    row.Add(name + ": " + (value ?? "NULL"));
                }
                output.Add(String.Join(" | ", row.ToArray()));
                return 0;
            };
            IntPtr error;
            rc = sqlite3_exec(db, Encoding.UTF8.GetBytes(sql + "\0"), cb, IntPtr.Zero, out error);
            if (rc != 0) {
                string msg = Marshal.PtrToStringAnsi(error);
                if (error != IntPtr.Zero) sqlite3_free(error);
                throw new Exception("SQLite error: " + msg);
            }
            return output.ToArray();
        } finally {
            if (db != IntPtr.Zero) sqlite3_close(db);
        }
    }
}
'@
}
# Keep a private persistent backup for repair, temporary copy for audit.
$dir = if ($Repair) {
    Join-Path $env:USERPROFILE ('OPENAI_QUEUE_BACKUP_' + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss') + '_' + [guid]::NewGuid().ToString('N'))
} else {
    Join-Path $env:TEMP ('OPENAI_QUEUE_AUDIT_' + [guid]::NewGuid().ToString('N'))
}
New-Item -ItemType Directory -Path $dir | Out-Null
$copy = Join-Path $dir '.codex-global-state.sqlite'
try {
    $hash = (Get-FileHash -LiteralPath $db -Algorithm SHA256).Hash
    Copy-Item -LiteralPath $db -Destination $copy
    Assert-Closed
    if ($hash -ne (Get-FileHash -LiteralPath $db -Algorithm SHA256).Hash -or
        $hash -ne (Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash) {
        throw 'Database changed or backup hash mismatch.'
    }
    $check = [LocalQueueRecovery20261124]::Run($copy, 'PRAGMA quick_check;', $false)
    if (@($check).Count -ne 1 -or $check[0] -ne 'quick_check: ok') {
        throw 'Backup integrity check failed.'
    }
    [LocalQueueRecovery20261124]::Run($copy, @'
SELECT count(*) AS Rows, coalesce(sum(length(CAST(value AS BLOB))),0) AS Total_bytes
FROM settings WHERE scope='global' AND key='queued-follow-ups';
SELECT typeof(value) AS Storage, json_valid(CAST(value AS TEXT)) AS Valid_JSON,
       CASE WHEN json_valid(CAST(value AS TEXT)) THEN json_type(CAST(value AS TEXT)) END AS Root_type
FROM settings WHERE scope='global' AND key='queued-follow-ups';
'@, $false)
    [LocalQueueRecovery20261124]::Run($copy, @'
SELECT CAST(j.key AS TEXT) AS Thread_id, j.type AS Entry_type,
       length(CAST(j.value AS BLOB)) AS Entry_bytes,
       CASE WHEN j.type='array' THEN json_array_length(j.value) END AS Pending_items,
       CASE WHEN instr(CAST(j.value AS TEXT),'data:image/')>0 THEN 'YES' ELSE 'NO' END AS Inline_images
FROM settings s, json_each(CAST(s.value AS TEXT)) j
WHERE s.scope='global' AND s.key='queued-follow-ups'
ORDER BY length(CAST(j.value AS BLOB)) DESC;
'@, $false)
    if (-not $Repair) { return }
    Write-Host "Verified private backup: $dir"
    # GUID parameter is validated by PowerShell; numeric parameter is typed.
    # Restrict to exactly the observed case: one queue entry, one pending message.
    # Never remove all queues or guess at unknown schemas.
    $id = $ThreadId.ToString()
    $sqlPath = '$."' + $id + '"'
    $pre = @"
SELECT count(*) AS Eligible
FROM settings WHERE scope='global' AND key='queued-follow-ups'
AND typeof(value)='text' AND json_valid(value)=1
AND length(CAST(value AS BLOB))=$ExpectedBytes
AND json_type(value,'$sqlPath')='array'
AND json_array_length(value,'$sqlPath')=1
AND instr(value,'data:image/')>0
AND json_remove(value,'$sqlPath')='{}';
"@
    $eligible = [LocalQueueRecovery20261124]::Run($copy,$pre,$false)
    if (@($eligible).Count -ne 1 -or $eligible[0] -ne 'Eligible: 1') {
        throw 'Case does not match the supported single-entry shape. No repair.'
    }
    Write-Warning 'This discards the one unsent message, its text and attachments, from the active queue. Backup is retained.'
    if ((Read-Host "Type REMOVE ONE PENDING MESSAGE to continue") -cne 'REMOVE ONE PENDING MESSAGE') {
        throw 'Cancelled. No repair.'
    }
    Assert-Closed
    if ($hash -ne (Get-FileHash -LiteralPath $db -Algorithm SHA256).Hash) {
        throw 'Database changed since backup. No repair.'
    }
    $sql = @"
PRAGMA busy_timeout=5000;
PRAGMA synchronous=FULL;
BEGIN IMMEDIATE;
CREATE TEMP TABLE repair_guard(ok INTEGER NOT NULL CHECK(ok=1));
INSERT INTO repair_guard SELECT count(*) FROM settings WHERE scope='global' AND key='queued-follow-ups';
INSERT INTO repair_guard
SELECT count(*) FROM settings WHERE scope='global' AND key='queued-follow-ups'
AND typeof(value)='text' AND json_valid(value)=1
AND length(CAST(value AS BLOB))=$ExpectedBytes
AND json_type(value,'$sqlPath')='array'
AND json_array_length(value,'$sqlPath')=1
AND instr(value,'data:image/')>0
AND json_remove(value,'$sqlPath')='{}';
UPDATE settings SET value=json_remove(value,'$sqlPath')
WHERE scope='global' AND key='queued-follow-ups';
INSERT INTO repair_guard VALUES(changes());
INSERT INTO repair_guard SELECT count(*) FROM settings
WHERE scope='global' AND key='queued-follow-ups' AND typeof(value)='text' AND value='{}';
COMMIT;
"@
    [LocalQueueRecovery20261124]::Run($db,$sql,$true)
    Write-Host 'COMMIT completed. Do not rerun blindly if verification fails.'
    [LocalQueueRecovery20261124]::Run($db,@'
SELECT length(CAST(value AS BLOB)) AS Remaining_bytes,
       json_valid(value) AS Valid_JSON,
       CASE WHEN value='{}' THEN 'EMPTY' ELSE 'NOT_EMPTY' END AS Queue_state
FROM settings WHERE scope='global' AND key='queued-follow-ups';
PRAGMA quick_check;
'@,$false)
    if ($hash -ne (Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash) {
        throw 'Backup hash changed. Stop and investigate.'
    }
    Write-Host 'Backup retained unchanged. Test the desktop app before changing versions.'
} finally {
    if (-not $Repair) { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
    else { Write-Host "Private backup directory: $dir" }
}
