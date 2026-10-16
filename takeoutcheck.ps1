#requires -Version 7.4
# Read-only candidate-name coverage, NOT Takeout/media/metadata validation.
# Same-directory, case-sensitive, one-to-one candidates only. No JSON parsing.
# Supports limited observed naming patterns; unsupported exports need review.
# Stop editors/sync. No concurrent/hostile-race protection. Ubuntu needs /usr/bin/test.
param(
 [Parameter(Mandatory,Position=0)][ValidateSet('report')][string]$Mode,
 [Parameter(Mandatory,Position=1)][string]$Folder
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function No-Link([string]$p) {
 $i=Get-Item -LiteralPath $p -Force
 if (-not $IsWindows) {
  & /usr/bin/test -f $p; $file=($LASTEXITCODE -eq 0)
  & /usr/bin/test -d $p; $dir=($LASTEXITCODE -eq 0)
  if (-not ($file -or $dir)) { throw 'Special filesystem entries are unsupported.' }
 }
 if (($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $i.LinkType) { throw 'Links, hardlinks and reparse points are unsupported.' }
 return $i
}
function Candidates([string]$name) {
 $list=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
 $bases=@($name)
 $suffix=''
 if ($name -cmatch '^(.*)\((\d+)\)(\.[^.]+)$') { $bases+=($Matches[1]+$Matches[3]);$suffix='('+$Matches[2]+')' }
 foreach ($base in $bases) {
  $dup=if ($base -ceq $name) { '' } else { $suffix }
  foreach ($extra in @('','.supplemental-metadata')) {
   $stem=$base+$extra
   $null=$list.Add($stem+$dup+'.json')
   if ($stem.Length -gt 46) { $null=$list.Add($stem.Substring(0,46)+$dup+'.json') }
  }
 }
 return @($list | Sort-Object -CaseSensitive)
}
try {
 if (-not $IsWindows -and -not [IO.File]::Exists('/usr/bin/test')) { throw 'Ubuntu workflow requires /usr/bin/test.' }
 if (($Folder -split '[\\/]') -contains '..') { throw 'Parent-traversal folder spellings are unsupported.' }
 $Folder=[IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($Folder))
 $p=$Folder
 while ($p) { $null=No-Link $p;$p=[IO.Path]::GetDirectoryName($p) }
 if (-not (No-Link $Folder).PSIsContainer) { throw 'Expected an existing directory.' }
 $files=[Collections.Generic.List[IO.FileInfo]]::new()
 $stack=[Collections.Generic.Stack[string]]::new();$stack.Push($Folder);$visited=0
 while ($stack.Count) {
  foreach ($i in Get-ChildItem -LiteralPath $stack.Pop() -Force) {
   $visited++;if ($visited -gt 5000) { throw 'Tree exceeds 5000 entries.' }
   $null=No-Link $i.FullName
   if ($i.PSIsContainer) { $stack.Push($i.FullName) } else { $files.Add($i) }
  }
 }
 $media=@($files | Where-Object { $_.Extension.ToLowerInvariant() -in '.jpg','.jpeg','.png','.gif','.mp4','.mov','.heic' } | Sort-Object FullName -CaseSensitive)
 $jsons=@($files | Where-Object { $_.Extension -ieq '.json' } | Sort-Object FullName -CaseSensitive)
 $byPath=[Collections.Generic.Dictionary[string,IO.FileInfo]]::new([StringComparer]::Ordinal)
 foreach ($j in $jsons) { $byPath.Add($j.FullName,$j) }
 $edges=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
 $claims=[Collections.Generic.Dictionary[string,int]]::new([StringComparer]::Ordinal)
 foreach ($m in $media) {
  $hits=[Collections.Generic.List[string]]::new()
  foreach ($candidate in Candidates $m.Name) {
   $path=Join-Path $m.DirectoryName $candidate
   if ($byPath.ContainsKey($path)) {
    $hits.Add($path)
    if (-not $claims.ContainsKey($path)) { $claims[$path]=0 };$claims[$path]++
   }
  }
  $edges.Add($m.FullName,@($hits))
 }
 $matched=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
 $pairs=0;$missing=0;$ambiguous=0
 foreach ($m in $media) {
  $rel=[IO.Path]::GetRelativePath($Folder,$m.FullName).Replace('\','/')
  $hits=@($edges[$m.FullName])
  if ($hits.Count -eq 0) { $missing++;"No candidate: $rel" }
  elseif ($hits.Count -ne 1 -or $claims[$hits[0]] -ne 1) { $ambiguous++;"Ambiguous candidate(s): $rel" }
  else {
   $pairs++;$null=$matched.Add($hits[0])
   $side=[IO.Path]::GetRelativePath($Folder,$hits[0]).Replace('\','/')
   "Candidate: $rel -> $side"
  }
 }
 $unpaired=0
 foreach ($j in $jsons) {
  if (-not $matched.Contains($j.FullName)) { $unpaired++;'Unpaired JSON: '+[IO.Path]::GetRelativePath($Folder,$j.FullName).Replace('\','/') }
 }
 "Media names selected: $($media.Count)"
 "JSON names found: $($jsons.Count)"
 "Unambiguous candidate pairs: $pairs"
 "Media with no recognized candidate: $missing"
 "Media with ambiguous candidates: $ambiguous"
 "JSON not in an unambiguous pair: $unpaired"
 'Names only: no JSON parsed, no media decoded, no dates or completeness verified.'
 'Unpaired JSON may be album metadata or an unsupported name, not missing media.'
 'No write code is used by this checker. Keep private paths and names private.'
 if (-not $media.Count -or $missing -or $ambiguous -or $unpaired) { exit 1 }
 exit 0
} catch { 'Stopped: '+$_.Exception.Message;exit 2 }
