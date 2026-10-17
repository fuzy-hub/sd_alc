param([int]$TimeoutSeconds=240, [switch]$FullAutoCAD, [switch]$StylesOnly, [switch]$TrimOnly, [switch]$HardeningOnly, [string]$InputDrawing)
$ErrorActionPreference='Stop'
if (([int]$StylesOnly.IsPresent+[int]$TrimOnly.IsPresent+[int]$HardeningOnly.IsPresent) -gt 1) { throw 'Choose one suite mode.' }
if (!$FullAutoCAD -and !$StylesOnly) { throw 'Hatch suites require -FullAutoCAD (AutoCAD 2027).' }
$taskRoot=Split-Path -Parent $PSScriptRoot
# Even the style suite uses ActiveX SetFont, unavailable in Core Console.
$taskExe='C:\Program Files\Autodesk\AutoCAD 2027\acad.exe'
if (!(Test-Path -LiteralPath $taskExe)) { throw "AutoCAD 2027 executable not found: $taskExe" }
$taskLabel='alc-'+(Get-Content (Join-Path $taskRoot 'VERSION')).Trim().Replace('.','')+'-'+(Get-Date -Format yyyyMMdd-HHmmss)+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)
$taskRun=Join-Path $PSScriptRoot ('results/'+$taskLabel)
New-Item -ItemType Directory -Path (Join-Path $taskRun 'fixtures') -Force | Out-Null
if (!$InputDrawing) { $InputDrawing=Join-Path $PSScriptRoot 'fixtures/straight-wall.dwg' }
$taskDwg=Join-Path $taskRun 'input.dwg'
Copy-Item -LiteralPath $InputDrawing -Destination $taskDwg
$taskCommands=@'
(setq alc-test-saved-secureload (getvar "SECURELOAD") alc-test-saved-acad (getenv "ACAD"))
(setq alc-test-path-prefix (strcat (getenv "ALCWALL_TEST_ROOT") ";"))
(while (= (vl-string-search alc-test-path-prefix alc-test-saved-acad) 0) (setq alc-test-saved-acad (substr alc-test-saved-acad (1+ (strlen alc-test-path-prefix)))))
(setvar "SECURELOAD" 0)
(setvar "CMDECHO" 0)
(setvar "FILEDIA" 0)
(setvar "LOGFILEPATH" (strcat (getenv "ALCWALL_TEST_RUN") "/"))
(setvar "LOGFILEMODE" 1)
(setenv "ACAD" (strcat (getenv "ALCWALL_TEST_ROOT") ";" (getenv "ACAD")))
(setq alc-test-start-var-names '("CLAYER" "TEXTSTYLE" "DIMSTYLE" "DIMBLK" "DIMSCALE" "DIMASZ" "DIMEXO" "DIMEXE" "DIMRND" "DIMFXL" "DIMFXLON" "DIMJOGANG" "DIMGAP" "DIMTIX" "DIMCLRD" "DIMCLRE" "DIMCLRT" "DIMDEC" "DIMTDEC" "DIMTMOVE"))
(setq alc-test-legacy-style (if (not (tblobjname "STYLE" "alc text dim")) (tblobjname "STYLE" "alc text")))
(setq alc-test-start-vars (mapcar 'getvar alc-test-start-var-names))

(load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/test-harness.lsp"))
(setq *alc-install-root* (getenv "ALCWALL_TEST_ROOT"))
(setvar "MEASUREMENT" 0)
(alc-test--suite "smoke-test" "smoke-test.lsp" 'alc-test-run-smoke nil)
(alc-test--suite "styles-test" "styles-test.lsp" 'alc-test-run-styles nil)
'@
$taskSuites=[ordered]@{'smoke-test'=5;'styles-test'=39}
if (!$StylesOnly) {
    $taskCommands+="`n(load (strcat (getenv `"ALCWALL_TEST_ROOT`") `"/tests/generate-fixtures.lsp`"))`n"
    if (!$TrimOnly -and !$HardeningOnly) {
        $taskCommands+=@'
(alc-test--suite "settings-test" "settings-test.lsp" 'alc-test-run-settings nil)
(alc-test--suite "fixture-test" "generate-fixtures.lsp" 'alc-test-run-fixtures nil)
(alc-test--suite "wall-tie-side-test" "wall-tie-side-test.lsp" 'alc-test-run-wall-tie-side nil)
'@
        $taskSuites['settings-test']=14; $taskSuites['fixture-test']=6; $taskSuites['wall-tie-side-test']=6
    }
    if (!$HardeningOnly) {
        $taskCommands+=@'

(alc-test--suite "trim-test" "trim-test.lsp" 'alc-test-run-trim T)
(alc-test--suite "xtend-test" "xtend-test.lsp" 'alc-test-run-xtend T)
(alc-test--step 'alc-test-trim-prepare-interactive "trim-test")
ALCTRIM
M
0,100
2000,100

(alc-test--step 'alc-test-trim-check-multi "trim-test")
ALCTRIM
0,100
(alc-test--step 'alc-test-trim-check-single "trim-test")
(alc-test--step 'alc-test-trim-prepare-interactive "trim-test")
ALCTRIM
L
50
M
0,100
2000,100
L
25
3000,100

(alc-test--step 'alc-test-trim-check-length "trim-test")
ALCTRIM
L
12.5
0,100
(alc-test--step 'alc-test-trim-check-length-single "trim-test")
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/ALCWALL.lsp"))
ALCTRIM
L

12.5,100
ALCTRIM
M
2000,100

(alc-test--step 'alc-test-trim-check-session-length "trim-test")
(alc-test--step 'alc-test-xtend-prepare "xtend-test")
VVXTEND
L
50
M
0,100
2000,100
L
25
3000,100

(alc-test--step 'alc-test-xtend-check-multi "xtend-test")
ALCXTEND
L
12.5
0,100
(alc-test--step 'alc-test-xtend-check-single "xtend-test")
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/ALCWALL.lsp"))
ALCXTEND
L

-12.5,100
VVTRIM
L
7
2000,100
(alc-test--step 'alc-test-xtend-check-retained "xtend-test")
(alc-test--finish "trim-test")
(alc-test--finish "xtend-test")
'@
        $taskSuites['trim-test']=39; $taskSuites['xtend-test']=32
    }
    if (!$TrimOnly) {
        $taskCommands=$taskCommands.TrimEnd("`r","`n")+"`n(alc-test--suite `"hardening-test`" `"hardening-test.lsp`" 'alc-test-run-hardening nil)`n"
        $taskSuites['hardening-test']=24
    }
}
$taskCommands=$taskCommands.TrimEnd("`r","`n")+"`n(setenv `"ACAD`" alc-test-saved-acad)`n(setvar `"SECURELOAD`" alc-test-saved-secureload)`n(setq alc-test-end-file (open (alc-test--result-path `"run.complete`") `"w`"))`n(write-line (getenv `"ALCWALL_TEST_LABEL`") alc-test-end-file)`n(close alc-test-end-file)`n(command-s `"_.QSAVE`")`n_.QUIT`n_Y`n"
$taskScript=Join-Path $taskRun 'run.scr'
Set-Content -LiteralPath $taskScript -Value $taskCommands -Encoding ascii
[pscustomobject]@{session=$taskLabel;suites=$taskSuites} | ConvertTo-Json | Set-Content (Join-Path $taskRun 'expected.json')
$taskEnvNames=@('ALCWALL_TEST_ROOT','ALCWALL_TEST_RUN','ALCWALL_TEST_LABEL')
$taskOld=@{}; foreach ($taskName in $taskEnvNames) { $taskOld[$taskName]=[Environment]::GetEnvironmentVariable($taskName,'Process') }
try {
    $env:ALCWALL_TEST_ROOT=$taskRoot.Replace('\','/')
    $env:ALCWALL_TEST_RUN=$taskRun.Replace('\','/')
    $env:ALCWALL_TEST_LABEL=$taskLabel
    $taskArgs=@('/nologo',('"'+$taskDwg+'"'),'/b',('"'+$taskScript+'"'))
    $taskProcess=Start-Process -FilePath $taskExe -ArgumentList $taskArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskRun 'stdout.log') -RedirectStandardError (Join-Path $taskRun 'stderr.log')
    $taskStart=$taskProcess.StartTime
    [pscustomobject]@{Label=$taskLabel;ProcessId=$taskProcess.Id;StartTime=$taskStart.ToString('o');Executable=$taskExe} | ConvertTo-Json | Set-Content (Join-Path $taskRun 'session.json')
    Write-Output "Session $taskLabel PID=$($taskProcess.Id) Start=$($taskStart.ToString('o'))"
    $taskWatch=[Diagnostics.Stopwatch]::StartNew()
    $taskFinishedAt=$null
    $taskCleaned=$false
    while (!$taskProcess.WaitForExit(1000)) {
        $taskCompletion=Join-Path $taskRun 'run.complete'
        if ((Test-Path -LiteralPath $taskCompletion) -and (Get-Content -LiteralPath $taskCompletion -Raw).Trim() -eq $taskLabel) {
            if ($null -eq $taskFinishedAt) { $taskFinishedAt=$taskWatch.Elapsed.TotalSeconds }
            if (($taskWatch.Elapsed.TotalSeconds-$taskFinishedAt) -ge 15) {
                $taskOwned=Get-Process -Id $taskProcess.Id -ErrorAction SilentlyContinue
                if ($taskOwned -and $taskOwned.StartTime -eq $taskStart) {
                    Stop-Process -Id $taskProcess.Id
                    $taskCleaned=$true
                    Write-Output 'Completed test script; cleaned up its owned CAD process after exit grace period.'
                    break
                }
            }
        }
        if ($taskWatch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
            $taskOwned=Get-Process -Id $taskProcess.Id -ErrorAction SilentlyContinue
            if ($taskOwned -and $taskOwned.StartTime -eq $taskStart) { Stop-Process -Id $taskProcess.Id }
            throw "Test timed out. Logs: $taskRun"
        }
    }
    $taskProcess.Refresh()
    if (!$taskCleaned -and $taskProcess.ExitCode -ne 0) { throw "AutoCAD test process failed: $($taskProcess.ExitCode); $taskRun" }
    $taskCompletion=Join-Path $taskRun 'run.complete'
    if (!(Test-Path -LiteralPath $taskCompletion) -or (Get-Content -LiteralPath $taskCompletion -Raw).Trim() -ne $taskLabel) { throw "Test script did not finish: $taskRun" }
    foreach ($taskSuite in $taskSuites.Keys) {
        $taskMarker=Join-Path $taskRun ($taskSuite+'.done.json')
        $taskLog=Join-Path $taskRun ($taskSuite+'.log')
        if (!(Test-Path $taskMarker) -or !(Test-Path $taskLog)) { throw "Missing completed suite: $taskSuite; $taskRun" }
        $taskDone=Get-Content $taskMarker -Raw | ConvertFrom-Json
        $taskLines=Get-Content $taskLog
        $taskCount=@($taskLines | Where-Object { $_ -eq 'PASS' -or $_ -like 'PASS *' -or $_ -like '*=PASS' }).Count
        if ($taskDone.session -ne $taskLabel -or $taskDone.status -ne 'complete' -or $taskDone.failed -ne 0 -or $taskDone.checks -ne $taskCount -or $taskCount -lt $taskSuites[$taskSuite] -or ($taskLines -match '(^FAIL(\s|$)|=FAIL(\s|$))')) {
            $taskLines | Write-Output
            throw "Failed/incomplete suite: $taskSuite ($taskCount checks); $taskRun"
        }
        Write-Output "PASS $taskSuite checks=$taskCount"
    }
    Write-Output "All selected suites complete. Logs: $taskRun"
} finally { foreach ($taskName in $taskEnvNames) { [Environment]::SetEnvironmentVariable($taskName,$taskOld[$taskName],'Process') } }
