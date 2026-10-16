#requires -Version 7.4
# Fictional NAME fixtures, not real photos/videos. New folder only.
param([string]$Root=(Join-Path $PSScriptRoot 'takeout-sample'))
$ErrorActionPreference='Stop'
try {
 if (($Root -split '[\\/]') -contains '..') { throw 'Parent-traversal setup paths are unsupported.' }
 $Root=[IO.Path]::GetFullPath($Root)
 if ($null -ne (Get-Item -LiteralPath $Root -Force -ErrorAction SilentlyContinue)) { throw 'Sample path exists. Nothing replaced.' }
 $p=[IO.Path]::GetDirectoryName($Root)
 while ($p) {
  $i=Get-Item -LiteralPath $p -Force
  if (($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $i.LinkType) { throw 'Linked/reparse parents are unsupported.' }
  $p=[IO.Path]::GetDirectoryName($p)
 }
 $null=[IO.Directory]::CreateDirectory($Root)
 foreach ($dir in 'album-a','album-b') { $null=[IO.Directory]::CreateDirectory((Join-Path $Root $dir)) }
 $data=[ordered]@{
  'album-a/one.jpg'='FICTIONAL NAME FIXTURE, NOT A PHOTO'
  'album-a/one.jpg.supplemental-metadata.json'='{"title":"one.jpg","photoTakenTime":{"timestamp":"1686920400"}}'
  'album-a/two(1).jpg'='FICTIONAL NAME FIXTURE, NOT A PHOTO'
  'album-a/two.jpg.supplemental-metadata(1).json'='{"title":"two(1).jpg"}'
  'album-a/missing.jpg'='FICTIONAL NAME FIXTURE, NOT A PHOTO'
  'album-a/metadata.json'='{"title":"fictional album"}'
  'album-b/one.jpg'='FICTIONAL NAME FIXTURE, NOT A PHOTO'
 }
 $utf8=[Text.UTF8Encoding]::new($false,$true)
 foreach ($rel in $data.Keys) {
  $stream=[IO.File]::Open((Join-Path $Root $rel),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
  try { $b=$utf8.GetBytes($data[$rel]);$stream.Write($b,0,$b.Length) } finally { $stream.Dispose() }
 }
 'Created seven fictional name-fixture files in two folders. No real media.'
 exit 0
} catch { 'Stopped: '+$_.Exception.Message;exit 1 }
