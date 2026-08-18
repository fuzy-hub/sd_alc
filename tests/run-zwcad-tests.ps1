param(
    [string]$ZwcadPath = 'C:\Program Files\ZWSOFT\ZWCAD 2027\ZWCAD.exe'
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$resultsPath = Join-Path $PSScriptRoot 'results'
$fixturesPath = Join-Path $PSScriptRoot 'fixtures'

if (-not (Test-Path -LiteralPath $ZwcadPath -PathType Leaf)) {
    throw "ZWCAD executable not found: $ZwcadPath"
}

New-Item -ItemType Directory -Path $resultsPath -Force | Out-Null
New-Item -ItemType Directory -Path $fixturesPath -Force | Out-Null

$resolvedResults = (Resolve-Path -LiteralPath $resultsPath).Path
$resolvedFixtures = (Resolve-Path -LiteralPath $fixturesPath).Path
if (-not $resolvedResults.StartsWith($projectRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
    -not $resolvedFixtures.StartsWith($projectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to clean test artifacts outside the project root.'
}

Get-ChildItem -LiteralPath $resolvedResults -File -Filter '*.log' -ErrorAction SilentlyContinue |
    Remove-Item -Force
Get-ChildItem -LiteralPath $resolvedFixtures -File -Filter '*.dwg' -ErrorAction SilentlyContinue |
    Remove-Item -Force

$env:ALCWALL_TEST_ROOT = $projectRoot.Replace('\', '/')

if (Get-Process -Name ZWCAD -ErrorAction SilentlyContinue) {
    throw 'Close existing ZWCAD sessions before running the automated tests.'
}

function Invoke-ZwcadScript {
    param([string]$ScriptName)

    $scriptPath = Join-Path $PSScriptRoot $ScriptName
    $argumentList = @('/b', ('"{0}"' -f $scriptPath))
    foreach ($attempt in 1..2) {
        Remove-Item -LiteralPath (Join-Path $resolvedResults 'smoke-test.log') `
            -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $resolvedResults 'fixture-test.log') `
            -Force -ErrorAction SilentlyContinue
        Get-ChildItem -LiteralPath $resolvedFixtures -File -Filter '*.dwg' `
            -ErrorAction SilentlyContinue | Remove-Item -Force

        $process = Start-Process -FilePath $ZwcadPath `
            -ArgumentList $argumentList `
            -WorkingDirectory $projectRoot `
            -WindowStyle Hidden `
            -PassThru
        if ($process.WaitForExit(120000)) {
            return
        }

        $process.Kill()
        $process.WaitForExit()
        if ($attempt -eq 2) {
            throw "ZWCAD timed out twice while running $ScriptName"
        }
        Start-Sleep -Seconds 5
    }
}

Invoke-ZwcadScript -ScriptName 'run-all.scr'

$smokeLog = Join-Path $resolvedResults 'smoke-test.log'
$fixtureLog = Join-Path $resolvedResults 'fixture-test.log'
if (-not (Test-Path -LiteralPath $smokeLog) -or
    -not (Test-Path -LiteralPath $fixtureLog)) {
    throw 'ZWCAD did not produce the expected test logs.'
}

$smoke = Get-Content -LiteralPath $smokeLog
$fixtures = Get-Content -LiteralPath $fixtureLog
$dwgs = Get-ChildItem -LiteralPath $resolvedFixtures -File -Filter '*.dwg'

if ($smoke[0] -ne 'PASS' -or $fixtures[0] -ne 'PASS' -or $dwgs.Count -ne 5) {
    $smoke
    $fixtures
    throw "ALCWALL ZWCAD tests failed; generated DWG count: $($dwgs.Count)"
}

$smoke
$fixtures
"DWG_COUNT=$($dwgs.Count)"
