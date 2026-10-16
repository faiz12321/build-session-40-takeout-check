#requires -Version 7.4
# Small fictional filename fixtures. Deletes only its own unique temp folder.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$checker=Join-Path $PSScriptRoot 'takeoutcheck.ps1'
$setup=Join-Path $PSScriptRoot 'make_sample.ps1'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('takeout-tests-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($temp)
$script:n=0;$script:bad=0;$script:skip=0
function Check([string]$name,[bool]$ok) { $script:n++;if ($ok) { "ok $script:n - $name" } else { $script:bad++;"NOT OK $script:n - $name" } }
function Run([string]$dir) {
 $o=& pwsh -NoProfile -File $checker report $dir 2>&1 | ForEach-Object { "$_" }
 return @{Code=$LASTEXITCODE;Text=($o -join "`n")}
}
function Setup([string]$dir) {
 $o=& pwsh -NoProfile -File $setup -Root $dir 2>&1 | ForEach-Object { "$_" }
 return @{Code=$LASTEXITCODE;Text=($o -join "`n")}
}
function New-Dir([string]$name) { $p=Join-Path $temp $name;$null=[IO.Directory]::CreateDirectory($p);return $p }
function Put([string]$dir,[string]$name,[string]$text='fixture') { [IO.File]::WriteAllText((Join-Path $dir $name),$text,[Text.UTF8Encoding]::new($false)) }
function State([string]$dir) {
 $a=@(Get-ChildItem -LiteralPath $dir -File -Recurse -Force | Sort-Object FullName -CaseSensitive | ForEach-Object { [IO.Path]::GetRelativePath($dir,$_.FullName)+'|'+(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash+'|'+$_.LastWriteTimeUtc.Ticks })
 return $a -join "`n"
}
try {
 $r=Join-Path $temp 'sample[1]';$o=Setup $r;Check 'new setup succeeds' ($o.Code -eq 0)
 $before=State $r;$o=Setup $r;Check 'repeat setup refuses and preserves all bytes and mtimes' ($o.Code -eq 1 -and (State $r) -ceq $before)
 $o=Run $r;Check 'fictional export reports review status' ($o.Code -eq 1)
 Check 'counts four media and three JSON names' ($o.Text.Contains('Media names selected: 4') -and $o.Text.Contains('JSON names found: 3'))
 Check 'two sibling supplemental candidates recognized' ($o.Text.Contains('Unambiguous candidate pairs: 2'))
 Check 'same filename in different folder cannot borrow sidecar' ($o.Text.Contains('No candidate: album-b/one.jpg'))
 Check 'missing recognized candidate listed' ($o.Text.Contains('No candidate: album-a/missing.jpg'))
 Check 'album metadata not called orphaned photo' ($o.Text.Contains('Unpaired JSON: album-a/metadata.json') -and $o.Text.Contains('may be album metadata'))
 Check 'all fixture bytes and mtimes unchanged by report' ((State $r) -ceq $before)
 $r=New-Dir 'classic';Put $r 'a.jpg';Put $r 'a.jpg.json' '{}';$o=Run $r;Check 'classic sibling candidate status0' ($o.Code -eq 0 -and $o.Text.Contains('Unambiguous candidate pairs: 1'))
 Check 'status0 explicitly does not validate contents' ($o.Text.Contains('no JSON parsed, no media decoded, no dates or completeness verified'))
 $r=New-Dir 'invalid-json';Put $r 'a.jpg';Put $r 'a.jpg.json' 'NOT JSON';$o=Run $r;Check 'invalid JSON still only name candidate with honest disclaimer' ($o.Code -eq 0 -and $o.Text.Contains('no JSON parsed'))
 $r=New-Dir 'multiple';Put $r 'a.jpg';Put $r 'a.jpg.json';Put $r 'a.jpg.supplemental-metadata.json';$o=Run $r;Check 'multiple names ambiguous, no guessed winner' ($o.Code -eq 1 -and $o.Text.Contains('Media with ambiguous candidates: 1') -and $o.Text.Contains('Unambiguous candidate pairs: 0'))
 $r=New-Dir 'shared';$prefix='a'*46;Put $r ($prefix+'x.jpg');Put $r ($prefix+'y.jpg');Put $r ($prefix+'.json');$o=Run $r;Check 'two media claiming one truncated sidecar both ambiguous' ($o.Code -eq 1 -and $o.Text.Contains('Media with ambiguous candidates: 2') -and $o.Text.Contains('Unambiguous candidate pairs: 0'))
 $r=New-Dir 'truncated';$name=('b'*44)+'.jpg';Put $r $name;Put $r ($name.Substring(0,46)+'.json');$o=Run $r;Check 'limited46character candidate supported' ($o.Code -eq 0)
 $r=New-Dir 'swap';Put $r 'a(1).jpg';Put $r 'a.jpg(1).json';$o=Run $r;Check 'classic duplicate-marker candidate supported' ($o.Code -eq 0)
 $r=New-Dir 'unsupported';Put $r 'a.jpg';Put $r 'a.jpg.weird.json';$o=Run $r;Check 'unknown suffix stays unresolved' ($o.Code -eq 1 -and $o.Text.Contains('Media with no recognized candidate: 1'))
 $r=New-Dir 'empty';$o=Run $r;Check 'empty tree is not successful export proof' ($o.Code -eq 1)
 $r=New-Dir 'jsononly';Put $r 'metadata.json';$o=Run $r;Check 'JSON-only tree review status' ($o.Code -eq 1)
 $r=New-Dir 'case';Put $r 'a.jpg';Put $r 'A.jpg.json';$o=Run $r;Check 'case differences not silently paired' ($o.Code -eq 1 -and $o.Text.Contains('Unambiguous candidate pairs: 0'))
 $r=New-Dir 'hidden';Put $r '.a.jpg';Put $r '.a.jpg.json';$o=Run $r;Check 'hidden filename candidates included' ($o.Code -eq 0)
 $r=New-Dir 'ignored';Put $r 'a.bmp';$o=Run $r;Check 'unsupported extension not counted as selected media' ($o.Code -eq 1 -and $o.Text.Contains('Media names selected: 0'))
 $r=Join-Path $temp 'absent';$o=Run $r;Check 'missing root refuses status2' ($o.Code -eq 2)
 $r=Join-Path $temp 'file';[IO.File]::WriteAllText($r,'KEEP');$o=Run $r;Check 'regular-file root refuses status2' ($o.Code -eq 2)
 $o=Setup $r;Check 'setup existing file preserved' ($o.Code -eq 1 -and [IO.File]::ReadAllText($r) -ceq 'KEEP')
 $r=New-Dir 'traversal';$o=Run (Join-Path $r '../traversal');Check 'parent traversal refuses before normalization' ($o.Code -eq 2)
 $r=New-Dir 'hardlink';$outside=Join-Path $temp 'outside.jpg';[IO.File]::WriteAllText($outside,'KEEP');$null=New-Item -ItemType HardLink -Path (Join-Path $r 'a.jpg') -Target $outside;$o=Run $r;Check 'hardlink refused and outside bytes unchanged' ($o.Code -eq 2 -and [IO.File]::ReadAllText($outside) -ceq 'KEEP')
 $r=New-Dir 'links'
 try { $null=New-Item -ItemType SymbolicLink -Path (Join-Path $r 'link.jpg') -Target $outside;$can=$true } catch { $can=$false }
 if ($can) {
  $o=Run $r;Check 'file symlink refuses' ($o.Code -eq 2)
  $link=Join-Path $temp 'root-link';$null=New-Item -ItemType SymbolicLink -Path $link -Target $r;$o=Run $link;Check 'directory root link refuses' ($o.Code -eq 2)
  $r=New-Dir 'loop';$null=New-Item -ItemType SymbolicLink -Path (Join-Path $r 'loop') -Target $r;$o=Run $r;Check 'recursive directory loop refuses' ($o.Code -eq 2)
  $r=New-Dir 'dangling';$null=New-Item -ItemType SymbolicLink -Path (Join-Path $r 'bad.jpg') -Target (Join-Path $temp 'missing');$o=Run $r;Check 'dangling link refuses' ($o.Code -eq 2)
 } else { $script:skip++;'SKIP: symbolic links unavailable' }
 if (-not $IsWindows) { $r=New-Dir 'pipe';& mkfifo (Join-Path $r 'pipe.jpg');$o=Run $r;Check 'named pipe refuses without blocking' ($o.Code -eq 2) } else { $script:skip++;'SKIP: Unix named pipe not applicable' }
} catch { $script:bad++;'HARNESS ERROR: '+$_.Exception.Message }
finally { Remove-Item -LiteralPath $temp -Recurse -Force }
"Results: $script:n checks, $script:bad failures, $script:skip skipped groups"
if ($script:bad) { exit 1 };exit 0
