param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$encoding = [Text.UTF8Encoding]::new($false)
$source = [IO.File]::ReadAllText((Join-Path $repo 'src\scripts\knives\efk_knife_fire.sma'), $encoding)
$fixture = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'fixture.inc'), $encoding)
$pattern = 'public plugin_init\(\)\r?\n\{'
if ([regex]::Matches($source, $pattern).Count -ne 1) { throw 'Fire plugin_init not found uniquely' }
$source = [regex]::Replace($source, $pattern, "public plugin_init()`r`n{`r`n`tset_task(2.0, `"test_create_bots`", 49000)")
$directory = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($directory) | Out-Null
$target = Join-Path $directory 'efk_knife_fire_test.sma'
[IO.File]::WriteAllText($target, $source + "`r`n" + $fixture, $encoding)
Write-Output $target