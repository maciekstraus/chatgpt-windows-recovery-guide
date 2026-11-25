# Read-only local ChatGPT/Codex health audit, Windows PowerShell 5.1 x64.
# No network, no app changes, no deletion of original data.
[CmdletBinding()]
param([datetime]$Since = (Get-Date).AddDays(-1))
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:USERPROFILE '.codex'
if ($env:CODEX_HOME) { $root = $env:CODEX_HOME }
if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw 'Codex data folder not found.' }
function Assert-Closed {
    if (Get-Process -Name ChatGPT,codex -ErrorAction SilentlyContinue) {
        throw 'Finish active tasks and fully quit desktop ChatGPT/Codex. Leave Chrome open.'
    }
}
Assert-Closed
$desktop = [Environment]::GetFolderPath('Desktop')
$out = Join-Path $desktop ('AUDYT_CHATGPT_' + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss') + '_' + [guid]::NewGuid().ToString('N').Substring(0,6))
New-Item -ItemType Directory -Path $out | Out-Null
$summary = Join-Path $out '01_PODSUMOWANIE.txt'
$private = Join-Path $out '02_PRYWATNE_METADANE.txt'
$issues = New-Object 'System.Collections.Generic.List[string]'
function Report([string]$s) { Write-Host $s; Add-Content -LiteralPath $summary -Value $s -Encoding UTF8 }
function Private([string]$s) { Add-Content -LiteralPath $private -Value $s -Encoding UTF8 }
function Warn([string]$s) { $issues.Add($s); Report ('UWAGA: ' + $s) }
function QLit([string]$s) { "'" + $s.Replace("'","''") + "'" }
function QId([string]$s) { '"' + $s.Replace('"','""') + '"' }
function MiB([long]$n) { [math]::Round($n / 1MB, 3) }
function Stamp([string]$p) {
    foreach ($f in @($p,"$p-wal")) {
        if (Test-Path -LiteralPath $f) { $i=Get-Item -LiteralPath $f -Force; "$($i.Length)|$($i.LastWriteTimeUtc.Ticks)" }
        else { 'absent' }
    }
}
# Avoid reparse points, inaccessible folders and recursive symlink loops.
$script:walkErrors=0; $script:skippedLinks=0
function Walk([string]$start) {
    if (-not (Test-Path -LiteralPath $start -PathType Container)) { return }
    $stack = New-Object 'System.Collections.Generic.Stack[string]'
    $stack.Push($start)
    while ($stack.Count -gt 0) {
        $d=$stack.Pop()
        try {
            foreach ($i in (Get-ChildItem -LiteralPath $d -Force -ErrorAction Stop)) {
                if ($i.Attributes -band [IO.FileAttributes]::ReparsePoint) { $script:skippedLinks++; continue }
                if ($i.PSIsContainer) { $stack.Push($i.FullName) } else { $i }
            }
        } catch { $script:walkErrors++; Private ('Folder omitted: ' + $d) }
    }
}
function Csv([object[]]$rows,[string]$name,[string]$emptyHeader) {
    $p=Join-Path $out $name
    if ($rows.Count -gt 0) { $rows | Export-Csv -LiteralPath $p -NoTypeInformation -Encoding UTF8 }
    else { Set-Content -LiteralPath $p -Value $emptyHeader -Encoding UTF8 }
}
if (-not ('ChatGPTHealthSqliteAudit' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class ChatGPTHealthSqliteAudit {
 [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
 private delegate int Callback(IntPtr a, int n, IntPtr v, IntPtr k);
 [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
 private static extern int sqlite3_open_v2(byte[] path, out IntPtr db, int flags, IntPtr vfs);
 [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
 private static extern int sqlite3_exec(IntPtr db, byte[] sql, Callback cb, IntPtr a, out IntPtr error);
 [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
 private static extern int sqlite3_close(IntPtr db);
 [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
 private static extern void sqlite3_free(IntPtr p);
 private static string Utf8(IntPtr p) {
   if(p==IntPtr.Zero) return "NULL";
   int len=0; while(Marshal.ReadByte(p,len)!=0) len++;
   byte[] b=new byte[len]; Marshal.Copy(p,b,0,len); return Encoding.UTF8.GetString(b);
 }
 public static string[] Query(string path,string sql,bool raw) {
   IntPtr db; int rc=sqlite3_open_v2(Encoding.UTF8.GetBytes(path+"\0"),out db,1,IntPtr.Zero);
   try {
     if(rc!=0) throw new Exception("SQLite open error: "+rc);
     List<string> output=new List<string>();
     Callback cb=delegate(IntPtr a,int n,IntPtr v,IntPtr k) {
       List<string> r=new List<string>();
       for(int i=0;i<n;i++) {
         string value=Utf8(Marshal.ReadIntPtr(v,i*IntPtr.Size));
         string name=Utf8(Marshal.ReadIntPtr(k,i*IntPtr.Size));
         r.Add(raw ? value : name+": "+value);
       }
       output.Add(String.Join(" | ",r.ToArray())); return 0;
     };
     IntPtr e;
     rc=sqlite3_exec(db,Encoding.UTF8.GetBytes(sql+"\0"),cb,IntPtr.Zero,out e);
     if(rc!=0) {string msg=Utf8(e); if(e!=IntPtr.Zero) sqlite3_free(e); throw new Exception(msg);}
     return output.ToArray();
   } finally {if(db!=IntPtr.Zero) sqlite3_close(db);}
 }
}
'@
}
function Sql([string]$p,[string]$q) { [ChatGPTHealthSqliteAudit]::Query($p,$q,$false) }
function Raw([string]$p,[string]$q) { [ChatGPTHealthSqliteAudit]::Query($p,$q,$true) }
Report '=== CHATGPT HEALTH AUDIT: READ ONLY ==='
Report ('Audit date: '+(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'))
Report ('Log cutoff (local): '+$Since.ToString('yyyy-MM-dd HH:mm:ss'))
Private 'PRIVATE: may contain conversation titles, IDs and paths. Keep locally.'
Private ('Codex root: '+$root)
Report "`n=== 1. APPLICATION AND STORAGE ==="
try { Get-AppxPackage *OpenAI* | ForEach-Object { Report ("{0} | {1} | {2}" -f $_.Name,$_.Version,$_.Status) } } catch { Warn 'Package version check failed.' }
try {
    $drive=Get-Item -LiteralPath $root
    Report ("Data drive free GiB: {0}" -f [math]::Round($drive.PSDrive.Free/1GB,2))
} catch { Warn 'Free-space check unavailable.' }
Report "`n=== 2. SQLITE: QUEUES, INTEGRITY, FREE PAGES ==="
$dbs=@(Get-ChildItem -LiteralPath $root -Force -File | Where-Object {$_.Name -match '\.(sqlite|db)$'} | Sort-Object Name)
$queueSeen=$false
foreach ($f in $dbs) {
    Assert-Closed
    $wal=0L; if(Test-Path -LiteralPath ($f.FullName+'-wal')) {$wal=(Get-Item -LiteralPath ($f.FullName+'-wal')).Length}
    Report ("--- {0} | main MiB={1} | WAL MiB={2}" -f $f.Name,(MiB $f.Length),(MiB $wal))
    $temp=Join-Path $env:TEMP ('OpenAI_Health_'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temp | Out-Null
    try {
        $p=Join-Path $temp $f.Name
        $before=(Stamp $f.FullName)-join ';'
        Copy-Item -LiteralPath $f.FullName -Destination $p
        if(Test-Path -LiteralPath ($f.FullName+'-wal')) {Copy-Item -LiteralPath ($f.FullName+'-wal') -Destination ($p+'-wal')}
        if($before -ne ((Stamp $f.FullName)-join ';')) {throw 'Source changed during copy; snapshot rejected.'}
        Assert-Closed
        $checks=@(Sql $p 'PRAGMA quick_check;')
        if($checks.Count -eq 1 -and $checks[0] -eq 'quick_check: ok') {Report 'quick_check: ok'}
        else {Warn ($f.Name+' quick_check not OK; investigate, do not reset.'); $checks | ForEach-Object {Private $_}}
        $pages=[long](@(Raw $p 'PRAGMA page_count;')[0]); $free=[long](@(Raw $p 'PRAGMA freelist_count;')[0]); $pageSize=[long](@(Raw $p 'PRAGMA page_size;')[0])
        Report ("pages={0}; free_pages={1}; reusable_MiB={2}" -f $pages,$free,(MiB ($free*$pageSize)))
        $tables=@(Raw $p "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;")
        Private ('=== '+$f.Name+' schema ===')
        foreach($t in $tables) {
            $cols=@(Raw $p ('SELECT name FROM pragma_table_info('+ (QLit $t) +');'))
            Private ($t+': '+($cols -join ', '))
            if($f.Name -match '^(queue_|thread_history_|state_|goals_|memories_)') {
                try {
                    $n=@(Raw $p ('SELECT count(*) FROM '+(QId $t)+';'))[0]
                    Report ("table=$t; rows=$n")
                    if($f.Name -match '^(queue_|thread_history_)') {
                        $candidate=@($cols | Where-Object {$_ -match '^(value|payload|data|content|message|body|json|item|event|record|.*_json)$'} | Select-Object -First 3)
                        foreach($c in $candidate) {
                            $q='SELECT coalesce(max(length(CAST('+(QId $c)+' AS BLOB))),0) AS Max_bytes FROM '+(QId $t)+';'
                            $v=@(Raw $p $q)[0]; Report ("table=$t; column=$c; max_value_bytes=$v")
                        }
                    }
                    if($t -eq 'threads' -or $t -eq 'projects') {
                        $safeCols=@($cols | Where-Object {$_ -match '^(id|thread_id|project_id|title|name|cwd|rollout_path|archived|created_at|updated_at)$'})
                        if($safeCols.Count -gt 0) {
                            Private ('=== '+$t+' metadata (up to 10000) ===')
                            $fields=($safeCols | ForEach-Object {'substr(CAST('+(QId $_)+' AS TEXT),1,1024) AS '+(QId $_)}) -join ','
                            Sql $p ('SELECT '+$fields+' FROM '+(QId $t)+' LIMIT 10000;') | ForEach-Object {Private $_}
                        }
                    }
                } catch {Warn ($f.Name+' table '+$t+' statistics incomplete.'); Private $_.Exception.Message}
            }
        }
        if($f.Name -eq '.codex-global-state.sqlite') {
            if($tables -notcontains 'settings') {throw 'Expected settings table missing.'}
            $q="SELECT count(*) AS Rows, coalesce(sum(length(CAST(value AS BLOB))),0) AS Bytes FROM settings WHERE scope='global' AND key='queued-follow-ups';"
            Sql $p $q | ForEach-Object {Report $_}
            $bytes=[long](@(Raw $p "SELECT coalesce(sum(length(CAST(value AS BLOB))),0) FROM settings WHERE scope='global' AND key='queued-follow-ups';")[0])
            $queueSeen=$true
            if($bytes -gt 64MB) {Warn 'Global pending queue exceeds 64 MiB (audit guard, not a product limit). Detailed JSON parsing skipped.'}
            else {
                Sql $p "SELECT typeof(value) AS Storage, json_valid(CAST(value AS TEXT)) AS Valid_JSON, CASE WHEN json_valid(CAST(value AS TEXT)) THEN json_type(CAST(value AS TEXT)) END AS Root_type FROM settings WHERE scope='global' AND key='queued-follow-ups';" | ForEach-Object {Report $_}
                Sql $p "SELECT count(*) AS Entries, coalesce(sum(CASE WHEN j.type='array' THEN json_array_length(j.value) ELSE 0 END),0) AS Array_items, coalesce(sum(CASE WHEN instr(CAST(j.value AS TEXT),'data:image/')>0 THEN 1 ELSE 0 END),0) AS Entries_with_inline_images FROM settings s, json_each(CAST(s.value AS TEXT)) j WHERE s.scope='global' AND s.key='queued-follow-ups';" | ForEach-Object {Report $_}
                Sql $p "SELECT j.key AS Thread_id,j.type AS Entry_type,length(CAST(j.value AS BLOB)) AS Bytes,CASE WHEN j.type='array' THEN json_array_length(j.value) END AS Items FROM settings s,json_each(CAST(s.value AS TEXT)) j WHERE s.scope='global' AND s.key='queued-follow-ups';" | ForEach-Object {Private $_}
            }
            # Only known setting names in shareable report; no user-specific key suffixes.
            Sql $p "SELECT count(*) AS Other_queue_keys,coalesce(sum(length(CAST(value AS BLOB))),0) AS Bytes FROM settings WHERE (lower(key) LIKE '%queue%' OR lower(key) LIKE '%follow-up%') AND key<>'queued-follow-ups';" | ForEach-Object {Report $_}
            Sql $p "SELECT key,length(CAST(value AS BLOB)) AS Bytes FROM settings WHERE key IN ('thread-project-assignments','thread-descriptions-v1','space-personal-recents-cache-v1','chatgpt-sidebar-state-v2');" | ForEach-Object {Report $_}
            $assign=[long](@(Raw $p "SELECT coalesce(sum(length(CAST(value AS BLOB))),0) FROM settings WHERE key='thread-project-assignments';")[0])
            if($assign -gt 0 -and $assign -le 4MB) {
                Private '=== Thread/project assignment metadata ==='
                Sql $p "SELECT j.key AS Assignment_key,j.type AS Type,CASE WHEN j.type='text' THEN substr(j.atom,1,512) ELSE NULL END AS Text_value FROM settings s,json_each(CAST(s.value AS TEXT)) j WHERE s.key='thread-project-assignments' LIMIT 10000;" | ForEach-Object {Private $_}
            }
        }
    } catch { Warn ($f.Name+' audit incomplete; no original changed.'); Private $_.Exception.Message }
    finally {Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
}
if(-not $queueSeen) {Warn 'Global queue database or schema not verified.'}
Report "`n=== 2B. GLOBAL JSON STATE AND BACKUP ==="
foreach ($name in @('.codex-global-state.json','.codex-global-state.json.bak')) {
    $path=Join-Path $root $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {Report "$name | absent"; continue}
    try {
        Assert-Closed
        $file=Get-Item -LiteralPath $path -Force
        $size=$file.Length; $stamp=$file.LastWriteTimeUtc.Ticks
        Report ("{0} | file_bytes={1}; MiB={2}" -f $name,$size,(MiB $size))
        if ($size -gt 64MB) {Warn ($name+' exceeds 64 MiB audit guard; JSON not loaded.'); continue}
        $json=Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        $after=Get-Item -LiteralPath $path -Force
        if ($after.Length -ne $size -or $after.LastWriteTimeUtc.Ticks -ne $stamp) {throw 'JSON changed during read.'}
        $entry=$json.PSObject.Properties['queued-follow-ups']
        if ($null -eq $entry) {Report 'Top-level queued-follow-ups: absent (nested schema not checked)'; continue}
        if ($null -eq $entry.Value) {Report 'Top-level queued-follow-ups: null'; continue}
        if ($entry.Value -isnot [System.Management.Automation.PSCustomObject]) {Warn ($name+' unexpected queue type; no content printed.'); continue}
        $items=@($entry.Value.PSObject.Properties)
        $num=0; $unknown=0
        foreach ($item in $items) {if ($item.Value -is [array]) {$num+=@($item.Value).Count} else {$unknown++}}
        Report ("Top-level queue entries={0}; array_items={1}; non_array_entries={2}" -f $items.Count,$num,$unknown)
    } catch {Warn ($name+' JSON inspection incomplete.'); Private $_.Exception.Message}
}

Report "`n=== 3. SESSION FILES AND PRIVATE INDEX ==="
$names=@{}; $index=Join-Path $root 'session_index.jsonl'
if(Test-Path -LiteralPath $index) {
    if((Get-Item -LiteralPath $index).Length -le 64MB) {
        try {Get-Content -LiteralPath $index -Encoding UTF8 | ForEach-Object {try {$r=$_ | ConvertFrom-Json -ErrorAction Stop; if($r.id){$names[[string]$r.id]=[string]$r.thread_name}}catch{}}} catch {Warn 'Session index read incomplete.'}
    } else {Warn 'Session index exceeds audit guard; skipped.'}
}
$sessionFiles=@(foreach($d in @('sessions','archived_sessions')) {Walk (Join-Path $root $d) | Where-Object {$_.Name -match '\.jsonl(\.zst)?$'}})
$sessions=@(foreach($f in $sessionFiles) {
    $id=''; if($f.Name -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.jsonl'){ $id=$Matches[1] }
    [pscustomobject]@{ThreadId=$id;Title=$names[$id];Bytes=$f.Length;MiB=(MiB $f.Length);Compressed=($f.Name -match '\.zst$');Modified=$f.LastWriteTime.ToString('s');Path=$f.FullName}
})
Csv $sessions '03_PRYWATNE_SESJE.csv' 'ThreadId,Title,Bytes,MiB,Compressed,Modified,Path'
Report ("Session files={0}; indexed titles={1}; total GiB={2}; compressed={3}" -f $sessions.Count,$names.Count,[math]::Round(($sessions|Measure-Object Bytes -Sum).Sum/1GB,3),@($sessions|Where-Object Compressed).Count)
Report ("Files >= 512 MiB={0}; >= 1 GiB={1}" -f @($sessions|Where-Object {$_.Bytes -ge 512MB}).Count,@($sessions|Where-Object {$_.Bytes -ge 1GB}).Count)
Report 'Top 20 session file sizes (on-disk, not RPC sizes):'
$sessions|Sort-Object Bytes -Descending|Select-Object -First 20|ForEach-Object {Report ("MiB={0}; compressed={1}; modified={2}" -f $_.MiB,$_.Compressed,$_.Modified)}
# Bounded first/last sample of largest uncompressed session files. No decompression or message output.
function ReadSample([string]$p,[int]$limit,[bool]$tail) {
    $stream=[IO.File]::Open($p,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    try {
        if($tail -and $stream.Length -gt $limit){[void]$stream.Seek(-$limit,[IO.SeekOrigin]::End)}
        $buf=New-Object byte[] $limit; $read=0
        while($read -lt $limit){$n=$stream.Read($buf,$read,$limit-$read);if($n -eq 0){break};$read+=$n}
        [Text.Encoding]::UTF8.GetString($buf,0,$read)
    }finally{$stream.Dispose()}
}
Report 'Media marker sample (not a duplication measurement):'
$sampled=0;$media=0
foreach($s in @($sessions|Where-Object {-not $_.Compressed}|Sort-Object Bytes -Descending|Select-Object -First 20)){
    try {
        $sample=ReadSample $s.Path 1048576 $false
        if($s.Bytes -gt 2097152){$sample+=' '+(ReadSample $s.Path 1048576 $true)}
        $n=[regex]::Matches($sample,'(?i)data:image/|data:video/|data:audio/|"image_url"').Count
        $sampled++;if($n -gt 0){$media++}
        Private ("Media markers sample: $($s.ThreadId) | count=$n | MiB=$($s.MiB)")
    }catch{Warn 'A session sample could not be read.'}
}
Report ("Uncompressed samples=$sampled; samples with media markers=$media; compressed files not opened")
Report "`n=== 4. DESKTOP LOGS (bounded tails, no raw lines) ==="
$logDirs=@((Join-Path $env:LOCALAPPDATA 'Codex\Logs'),(Join-Path $root 'logs'))
$pkgRoot=Join-Path $env:LOCALAPPDATA 'Packages'
if(Test-Path -LiteralPath $pkgRoot){Get-ChildItem -LiteralPath $pkgRoot -Directory -Filter 'OpenAI.Codex*' -ErrorAction SilentlyContinue|ForEach-Object {$logDirs+=Join-Path $_.FullName 'LocalCache\Local\Codex\Logs'}}
$logs=@(foreach($d in ($logDirs|Sort-Object -Unique)){Walk $d|Where-Object {$_.Name -match '\.(log|txt)$' -and $_.LastWriteTime -ge $Since}})
$logs=@($logs|Sort-Object LastWriteTime -Descending)
$patterns=[ordered]@{Serialization='536870912|serialization (limit|budget)|RPC frame exceeds';MessagePort='Peer closed MessagePort connection';ChromeContext='Browser access requires the originating browser context';OOM='out of memory|heap limit|allocation failed';Sqlite='SQLITE_CORRUPT|database disk image is malformed|SQLITE_FULL|SQLITE_BUSY'}
$counts=@{};foreach($k in $patterns.Keys){$counts[$k]=@(0,0,0)}
$cutoff=[DateTimeOffset]$Since
foreach($f in @($logs|Select-Object -First 30)){
    try{
        $tail=ReadSample $f.FullName (4*1MB) $true
        foreach($line in ($tail -split '\r?\n')){
            $when=[DateTimeOffset]::MinValue;$known=$false
            if($line -match '\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})'){$known=[DateTimeOffset]::TryParse($Matches[0],[ref]$when)}
            foreach($k in $patterns.Keys){if($line -match $patterns[$k]){if(-not $known){$counts[$k][2]++}elseif($when -ge $cutoff){$counts[$k][0]++}else{$counts[$k][1]++}}}
        }
    }catch{Warn 'A log tail could not be read.'}
}
Report ("Recently modified logs found={0}; inspected at most 30, last 4 MiB each" -f $logs.Count)
foreach($k in $patterns.Keys){Report ("$k | dated since cutoff=$($counts[$k][0]) | dated before=$($counts[$k][1]) | timestamp unknown=$($counts[$k][2])")}
Report 'No match is not proof of absence: older or truncated logs and SQLite log contents are not searched.'
Report "`n=== 5. PROJECT FOLDERS AND PDF CANDIDATES ==="
$docRoot=Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'ChatGPT'
$projects=@();if(Test-Path -LiteralPath $docRoot){$projects=@(Get-ChildItem -LiteralPath $docRoot -Directory -Force|Where-Object {-not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)})}
Csv @($projects|ForEach-Object{[pscustomobject]@{Name=$_.Name;Path=$_.FullName;Modified=$_.LastWriteTime.ToString('s')}}) '04_PRYWATNE_PROJEKTY.csv' 'Name,Path,Modified'
$searchRoots=@($root,$docRoot);foreach($d in $logDirs){if($d -match 'LocalCache\\Local\\Codex\\Logs$'){$searchRoots+=Split-Path $d -Parent}}
$pdfs=@(foreach($d in ($searchRoots|Sort-Object -Unique)){Walk $d|Where-Object {$_.Extension -ieq '.pdf'}|ForEach-Object {[pscustomobject]@{Name=$_.Name;Bytes=$_.Length;MiB=(MiB $_.Length);Modified=$_.LastWriteTime.ToString('s');Path=$_.FullName}}})
$pdfs=@($pdfs|Sort-Object Path -Unique)
Csv $pdfs '05_PRYWATNE_PDF.csv' 'Name,Bytes,MiB,Modified,Path'
Report ("Project folders in Documents\ChatGPT={0}; local PDF candidates={1}; total PDF MiB={2}" -f $projects.Count,$pdfs.Count,(MiB (($pdfs|Measure-Object Bytes -Sum).Sum)))
Report 'PDF inventory is filename-only; it cannot identify cloud-only project sources or prove project attachment membership.'
Report ("Inaccessible folders skipped=$script:walkErrors; reparse points skipped=$script:skippedLinks")
Report "`n=== 6. AUDIT LIMITATIONS ==="
Report 'No application database, session or PDF was modified. Only temporary database copies were queried and removed.'
Report 'SQLite snapshots use file size/mtime checks for main and WAL, not an atomic live backup. Desktop must stay closed.'
Report 'quick_check is a structural check, not a full application or sync test. File sizes do not establish RPC limits.'
Report 'History records, media payloads and compressed sessions were not exported or decompressed.'
Report 'Only known local roots were searched; cloud data and external project folders elsewhere are outside scope.'
Report ("Warnings=$($issues.Count)")
Report '=== AUDIT FINISHED ==='
Write-Host "`nREPORT FOLDER: $out" -ForegroundColor Green
Write-Host 'Share only 01_PODSUMOWANIE.txt after reviewing it. Keep PRIVATE files local.' -ForegroundColor Yellow
