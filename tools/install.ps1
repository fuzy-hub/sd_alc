param([string]$Root=(Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference='Stop'
$Root=(Resolve-Path -LiteralPath $Root).Path.Replace('\','/')
if (!(Test-Path -LiteralPath (Join-Path $Root 'manifest.json'))) { throw 'Incomplete installation.' }
$taskLisp='(setq *alc-install-root* "'+$Root+'")'+[Environment]::NewLine+'(load "'+$Root+'/ALCWALL.lsp")'
$taskLoader=Join-Path $Root 'ALCWALL-LOAD.lsp'
Set-Content -LiteralPath $taskLoader -Value $taskLisp -Encoding utf8
Write-Output "APPLOAD this pinned loader: $taskLoader"
