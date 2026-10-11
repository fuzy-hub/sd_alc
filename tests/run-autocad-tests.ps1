param([int]$TimeoutSeconds = 180, [switch]$FullAutoCAD, [switch]$StylesOnly, [switch]$TrimOnly, [string]$InputDrawing)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskExe = 'C:\Program Files\Autodesk\AutoCAD 2027\accoreconsole.exe'
if ($FullAutoCAD) { $taskExe = 'C:\Program Files\Autodesk\AutoCAD 2027\acad.exe' }
if (!(Test-Path -LiteralPath $taskExe)) { throw 'AutoCAD 2027 Core Console not found.' }
$taskLabel = 'alc-' + (Get-Content -LiteralPath (Join-Path $taskRoot 'VERSION')).Trim().Replace('.','') + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8)
$taskRun = Join-Path $PSScriptRoot ('results/' + $taskLabel)
New-Item -ItemType Directory -Path $taskRun | Out-Null
$taskDwg = Join-Path $taskRun 'input.dwg'
if (!$InputDrawing) { $InputDrawing = Join-Path $PSScriptRoot 'fixtures/straight-wall.dwg' }
Copy-Item -LiteralPath $InputDrawing -Destination $taskDwg
$taskScript = Join-Path $taskRun 'run.scr'
$taskCommands = @'
(setq alc-test-saved-secureload (getvar "SECURELOAD") alc-test-saved-acad (getenv "ACAD"))
(setq alc-test-path-prefix (strcat (getenv "ALCWALL_TEST_ROOT") ";"))
(while (= (vl-string-search alc-test-path-prefix alc-test-saved-acad) 0) (setq alc-test-saved-acad (substr alc-test-saved-acad (1+ (strlen alc-test-path-prefix)))))
(setvar "SECURELOAD" 0)
(setvar "CMDECHO" 0)
(setvar "FILEDIA" 0)
(setenv "ACAD" (strcat (getenv "ALCWALL_TEST_ROOT") ";" (getenv "ACAD")))
(setq alc-test-start-var-names '("CLAYER" "TEXTSTYLE" "DIMSTYLE" "DIMBLK" "DIMSCALE" "DIMASZ" "DIMEXO" "DIMEXE" "DIMRND" "DIMFXL" "DIMFXLON" "DIMJOGANG" "DIMGAP" "DIMTIX" "DIMCLRD" "DIMCLRE" "DIMCLRT" "DIMDEC" "DIMTDEC" "DIMTMOVE"))
(setq alc-test-legacy-style (if (not (tblobjname "STYLE" "alc text dim")) (tblobjname "STYLE" "alc text")))
(setq alc-test-start-vars (mapcar 'getvar alc-test-start-var-names))
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/smoke-test.lsp"))
(alc-test-run-smoke)
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/styles-test.lsp"))
(alc-test-run-styles)
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/generate-fixtures.lsp"))
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/settings-test.lsp"))
(alc-test-run-settings)
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/generate-fixtures.lsp"))
(alc-test-run-fixtures)
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/wall-tie-side-test.lsp"))
(alc-test-run-wall-tie-side)
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/trim-test.lsp"))
(alc-test-run-trim)
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/xtend-test.lsp"))
(alc-test-run-xtend)
(setenv "ACAD" alc-test-saved-acad)
(setvar "SECURELOAD" alc-test-saved-secureload)
_.QUIT
_N

'@
if ($StylesOnly) {
    $taskCommands = $taskCommands -replace '(?ms)\(load \(strcat \(getenv "ALCWALL_TEST_ROOT"\) "/tests/generate-fixtures.lsp"\)\).*?(?=\(setenv "ACAD" alc-test-saved-acad\))', ''
}
if ($TrimOnly) {
    $taskCommands = $taskCommands -replace '(?ms)\(load \(strcat \(getenv "ALCWALL_TEST_ROOT"\) "/tests/generate-fixtures.lsp"\)\).*?(?=\(setenv "ACAD" alc-test-saved-acad\))', "(load (strcat (getenv `"ALCWALL_TEST_ROOT`") `"/tests/generate-fixtures.lsp`"))`n(load (strcat (getenv `"ALCWALL_TEST_ROOT`") `"/tests/trim-test.lsp`"))`n(alc-test-run-trim)`n(load (strcat (getenv `"ALCWALL_TEST_ROOT`") `"/tests/xtend-test.lsp`"))`n(alc-test-run-xtend)`n"
}
if (!$StylesOnly) {
    $taskInteractiveTrim = @'
(alc-test-trim-prepare-interactive)
ALCTRIM
M
0,100
2000,100

(alc-test-trim-check-multi)
ALCTRIM
0,100
(alc-test-trim-check-single)
(alc-test-trim-prepare-interactive)
ALCTRIM
L
50
M
0,100
2000,100
L
25
3000,100

(alc-test-trim-check-length)
ALCTRIM
L
12.5
0,100
(alc-test-trim-check-length-single)
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/ALCWALL.lsp"))
ALCTRIM
L

12.5,100
ALCTRIM
M
2000,100

(alc-test-trim-check-session-length)
(alc-test-xtend-prepare)
VVXTEND
L
50
M
0,100
2000,100
L
25
3000,100

(alc-test-xtend-check-multi)
ALCXTEND
L
12.5
0,100
(alc-test-xtend-check-single)
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/ALCWALL.lsp"))
ALCXTEND
L

-12.5,100
VVTRIM
L
7
2000,100
(alc-test-xtend-check-retained)
'@
    $taskCommands = $taskCommands.Replace('(setenv "ACAD" alc-test-saved-acad)', $taskInteractiveTrim + "`n" + '(setenv "ACAD" alc-test-saved-acad)')
}
Set-Content -LiteralPath $taskScript -Value $taskCommands -Encoding ascii
$taskOldRoot = $env:ALCWALL_TEST_ROOT
try {
    $env:ALCWALL_TEST_ROOT = $taskRoot.Replace('\','/')
    $taskArgs = @('/i', ('"' + $taskDwg + '"'), '/s', ('"' + $taskScript + '"'), '/l', 'en-US')
    if ($FullAutoCAD) { $taskArgs = @('/nologo', ('"' + $taskDwg + '"'), '/b', ('"' + $taskScript + '"')) }
    $taskProcess = Start-Process -FilePath $taskExe -ArgumentList $taskArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskRun 'stdout.log') -RedirectStandardError (Join-Path $taskRun 'stderr.log')
    $taskStart = $taskProcess.StartTime
    [pscustomobject]@{ Label=$taskLabel; ProcessId=$taskProcess.Id; StartTime=$taskStart.ToString('o'); Executable=$taskExe } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskRun 'session.json')
    Write-Output "Session $taskLabel PID=$($taskProcess.Id) Start=$($taskStart.ToString('o'))"
    if (!$taskProcess.WaitForExit($TimeoutSeconds * 1000)) {
        $taskOwned = Get-Process -Id $taskProcess.Id -ErrorAction SilentlyContinue
        if ($taskOwned -and $taskOwned.StartTime -eq $taskStart) { Stop-Process -Id $taskProcess.Id }
        throw "Test timed out. Logs: $taskRun"
    }
    Write-Output "Exit=$($taskProcess.ExitCode) Logs=$taskRun"
    if ($taskProcess.ExitCode -ne 0) { throw "AutoCAD test process failed: $($taskProcess.ExitCode)" }
    $taskExpectedLogs = @('smoke-test.log','styles-test.log','settings-test.log','fixture-test.log','wall-tie-side-test.log','trim-test.log','xtend-test.log')
    if ($StylesOnly) { $taskExpectedLogs = @('smoke-test.log','styles-test.log') }
    if ($TrimOnly) { $taskExpectedLogs = @('smoke-test.log','styles-test.log','trim-test.log','xtend-test.log') }
    foreach ($taskLog in $taskExpectedLogs) {
        $taskLogFile = Join-Path $PSScriptRoot "results/$taskLog"
        if (!(Test-Path -LiteralPath $taskLogFile) -or (Get-Item -LiteralPath $taskLogFile).LastWriteTime -lt $taskStart) { throw "Missing fresh result: $taskLog" }
        $taskLines = Get-Content -LiteralPath $taskLogFile
        $taskLines
        Copy-Item -LiteralPath $taskLogFile -Destination $taskRun
        if ($taskLines -match '^FAIL') { throw "Failed test: $taskLog" }
    }
} finally { $env:ALCWALL_TEST_ROOT = $taskOldRoot }
