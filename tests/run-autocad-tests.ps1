param([int]$TimeoutSeconds=240, [switch]$FullAutoCAD, [switch]$StylesOnly, [switch]$TrimOnly, [switch]$HardeningOnly, [string]$InputDrawing, [switch]$PublicDoorOnly, [switch]$PublicDoorReopen, [switch]$AssignEnterUI, [switch]$StatFindReopen, [switch]$StatMaskOnly, [switch]$StandardWallOnly, [switch]$MatchDoorOnly, [switch]$ElevationOnly)
$ErrorActionPreference='Stop'
if (([int]$StylesOnly.IsPresent+[int]$TrimOnly.IsPresent+[int]$HardeningOnly.IsPresent) -gt 1) { throw 'Choose one suite mode.' }
if ($PublicDoorOnly -and ($StylesOnly -or $TrimOnly -or $HardeningOnly)) { throw 'PublicDoorOnly cannot be combined with another suite mode.' }
if ($PublicDoorReopen -and (!$PublicDoorOnly -or !$InputDrawing)) { throw 'PublicDoorReopen requires PublicDoorOnly and an existing InputDrawing.' }
if ($StatFindReopen -and !$InputDrawing) { throw 'StatFindReopen requires a saved InputDrawing.' }
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
if ($AssignEnterUI) { $taskDwg=Join-Path $taskRun ($taskLabel+'.dwg') }
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
$taskCommands+="`n"+@'
(alc-test--suite "layer-test" "layer-test.lsp" 'alc-test-run-layer T)
ALCLAYER
CodexLayerA
(alc-test--step 'alc-test-layer-check-a "layer-test")
_.UNDO
1
(alc-test--step 'alc-test-layer-check-undo "layer-test")
(setq *alc-layer-test-color* 5)
VVLAYER
ALC_wall_CodexLayerB
(alc-test--step 'alc-test-layer-check-b "layer-test")
(setq *alc-layer-test-color* nil)
ALCLAYER
CodexCancelled
(alc-test--step 'alc-test-layer-check-cancel "layer-test")
ALCLAYER

(alc-test--step 'alc-test-layer-check-blank "layer-test")
(setq *alc-layer-test-color* 1)
ALCLAYER
CodexLayerB
CodexLayerC
(alc-test--step 'alc-test-layer-check-duplicate "layer-test")
(alc-test--finish "layer-test")
'@
$taskSuites['layer-test']=15
$taskCommands+="`n(alc-test--suite `"assign-test`" `"assign-test.lsp`" 'alc-test-run-assign nil)`n"
$taskSuites['assign-test']=12
$taskUiTest=Join-Path $taskRun 'assign-ui-test.dll'
& (Join-Path $taskRoot 'tools/build-assign-ui.ps1') -TestOutput $taskUiTest
$taskCommands+="`n(command-s `"_.NETLOAD`" (strcat (getenv `"ALCWALL_TEST_ROOT`") `"/src/alc-assign-ui.dll`"))`n"
$taskCommands+="(command-s `"_.NETLOAD`" (strcat (getenv `"ALCWALL_TEST_RUN`") `"/assign-ui-test.dll`"))`n"
$taskCommands+="(alc-test--write-lines `"assign-ui-test.log`" (ALC-ASSIGN-UI-TEST))`n(alc-test--finish `"assign-ui-test`")`n"
$taskSuites['assign-ui-test']=15

$taskCommands+="`n(alc-test--suite `"stat-layer-test`" `"stat-layer-test.lsp`" 'alc-test-run-stat-layer nil)`n"
$taskSuites['stat-layer-test']=27
$taskCommands+="`n(alc-test--suite `"stat-detail-test`" `"stat-detail-test.lsp`" 'alc-test-run-stat-detail nil)`n"
$taskSuites['stat-detail-test']=47
$taskCommands+="`n(alc-test--suite `"stat-label-test`" `"stat-label-test.lsp`" 'alc-test-run-stat-label nil)`n"
$taskSuites['stat-label-test']=18
$taskCommands+="`n(alc-test--suite `"revcloud-test`" `"revcloud-test.lsp`" 'alc-test-run-revcloud nil)`n"
$taskSuites['revcloud-test']=13
$taskCommands+="`n(alc-test--suite `"filter-test`" `"filter-test.lsp`" 'alc-test-run-filter nil)`n"
$taskSuites['filter-test']=12
$taskCommands+="`n"+@'
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/generate-fixtures.lsp"))
(alc-test--suite "sumtable-test" "sumtable-test.lsp" 'alc-test-run-sumtable T)
(alc-test--step 'alc-test-sumtable-prepare "sumtable-test")
VVSUMTABLE
100
_All

40000,0
(alc-test--step 'alc-test-sumtable-public-check "sumtable-test")
_.UNDO
1
(alc-test--step 'alc-test-sumtable-undo-check "sumtable-test")
(setvar "PICKFIRST" 1)
(sssetfirst nil (ssget "_X" '((0 . "ACAD_TABLE"))))
VVSUMTABLE

40000,0
(alc-test--step 'alc-test-sumtable-public-check "sumtable-test")
_.UNDO
1
(alc-test--step 'alc-test-sumtable-undo-check "sumtable-test")
VVSUMTABLE


(alc-test--step 'alc-test-sumtable-undo-check "sumtable-test")
VVSUMTABLE

_All


(alc-test--step 'alc-test-sumtable-undo-check "sumtable-test")
(alc-test--finish "sumtable-test")
'@
$taskSuites['sumtable-test']=31
$taskCommands+="`n"+@'
(alc-test--suite "stat-find-test" "stat-find-test.lsp" 'alc-test-run-stat-find T)
(alc-test--step 'alc-test-stat-find-prepare "stat-find-test")
VVTK
M
N
Yes
E

A
_All

12000,0
(alc-test--step 'alc-test-stat-find-created "stat-find-test")
_.UNDO
1
(alc-test--step 'alc-test-stat-find-create-undo "stat-find-test")
VVTK
M
N
No
E

A
_All

12000,0
(alc-test--step 'alc-test-stat-find-created-no "stat-find-test")
_.UNDO
1
(alc-test--step 'alc-test-stat-find-create-undo "stat-find-test")
(setq *alc-stat-number-sources* T)
(alc--save-settings)
VVTK

A
_All

12000,0
(setq alc-test-label-selection (ssget "_X" '((0 . "TEXT") (8 . "ALC_VVTK_STT"))) *alc-find-test-old-labels* (list (ssname alc-test-label-selection 0) (ssname alc-test-label-selection 1)))
VVTK

A
_All

16000,0
(alc-test--step 'alc-test-stat-find-renumbered "stat-find-test")
_.UNDO
1
(alc-test--step 'alc-test-stat-find-renumber-undo "stat-find-test")
(alc-test--step 'alc-test-stat-find-prepare "stat-find-test")
(setvar "OSMODE" 3)
VVTK
Find
8450,-510

(alc-test-stat-find-selected *alc-find-test-b*)
ALCTK
F
5250,-690

(alc-test-stat-find-selected *alc-find-test-a*)
(setq *alc-find-test-effect* (getvar "SELECTIONEFFECT") *alc-find-test-effect-color* (getvar "SELECTIONEFFECTCOLOR"))
(defun alc--stat-find-pick-color () 2)
VVTK
F
Color
8450,-510

(alc-test-stat-find-selected *alc-find-test-b*)
(alc-test--step 'alc-test-stat-find-native-color "stat-find-test")
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/src/alc-schedule.lsp"))
(alc-test--finish "stat-find-test")
'@
$taskSuites['stat-find-test']=45
if (!$StylesOnly -and !$PublicDoorOnly) {
    $taskCommands+="`n(load (strcat (getenv `"ALCWALL_TEST_ROOT`") `"/tests/generate-fixtures.lsp`"))`n"
    $taskCommands+=@'
(alc-test--suite "match-test" "match-test.lsp" 'alc-test-run-match T)
(alc-test--step 'alc-test-match-prepare "match-test")
VV
0,0
6000,0

0,100
ALCDOOR
900
500,0
0,50
1000,50
VVMATCH
500,0

(alc-test--step 'alc-test-match-public-check "match-test")
VVMATCH
500,50

(alc-test--step 'alc-test-match-public-check "match-test")
_.UNDO
1
(alc-test--step 'alc-test-match-undo-check "match-test")
VVMATCH
500,50

(alc-test--step 'alc-test-match-public-check "match-test")
_.UNDO
1
(alc-test--step 'alc-test-match-add-invalid "match-test")
VVMATCH
500,0
6500,2000
500,50
2500,0

(alc-test--step 'alc-test-match-multi-check "match-test")
_.UNDO
1
(alc-test--step 'alc-test-match-undo-check "match-test")
VVMATCH
_W
-100,-100
7100,2100

(alc-test--step 'alc-test-match-multi-check "match-test")
VVMATCH
_W
-100,-100
7100,2100

(alc-test--step 'alc-test-match-multi-check "match-test")
_.UNDO
1
(alc-test--step 'alc-test-match-undo-check "match-test")
VVMATCH
_C
6100,150
-100,-50

(alc-test--step 'alc-test-match-multi-check "match-test")
_.UNDO
1
(alc-test--step 'alc-test-match-undo-check "match-test")
(setvar "PICKFIRST" 1)
(sssetfirst nil (ssget "_W" '(-100.0 -100.0 0.0) '(7100.0 2100.0 0.0) '((0 . "LWPOLYLINE,HATCH"))))
VVMATCH
(alc-test--step 'alc-test-match-multi-check "match-test")
_.UNDO
1
(alc-test--step 'alc-test-match-undo-check "match-test")
VVMATCH

(alc-test--step 'alc-test-match-undo-check "match-test")
(alc-test--finish "match-test")
'@
    $taskSuites['match-test']=46
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
    $taskCommands=$taskCommands.TrimEnd("`r","`n")+@'

(alc-test--suite "wall-schedule-test" "wall-schedule-test.lsp" 'alc-test-run-wall-schedule T)
(alc-test--step 'alc-test-wall-schedule-prepare "wall-schedule-test")
ALCTKT
_W
-10,-10
4500,5000

BANG TUONG TANG 1
6000,0
(alc-test--step 'alc-test-wall-schedule-check-command "wall-schedule-test")
_.UNDO
1
(alc-test--step 'alc-test-wall-schedule-check-undo "wall-schedule-test")
(alc-test--finish "wall-schedule-test")
'@
    $taskSuites['wall-schedule-test']=48
}
if (!$StylesOnly) {
    $taskCommands=$taskCommands.TrimEnd("`r","`n")+@'

(load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/generate-fixtures.lsp"))
(alc-test--suite "public-door-test" "public-door-test.lsp" 'alc-test-run-public-door T)
'@
    if (!$PublicDoorReopen) {
        $taskCommands+="`n"+@'
(alc-test--step 'alc-test-public-door-prepare "public-door-test")
VV
0,0
6000,0

0,100
VVC
0,2000
5000,2000

ALCDOOR
900
500,0
0,50
1500,50
VVDOOR
1200
500,1950
0,2000
1000,2000
ALCTKT
_W
-10,-100
6010,2200

PUBLIC WALL DOORS
7000,0
'@
    }
    $taskCommands+="`n"+@'
(alc-test--step 'alc-test-public-door-check "public-door-test")
(alc-test--step 'alc-test-public-door-save "public-door-test")
(alc-test--finish "public-door-test")
'@
    $taskSuites['public-door-test']=5
}
if ($StatFindReopen) {
    $taskCommands=@'
(setq alc-test-saved-secureload (getvar "SECURELOAD") alc-test-saved-acad (getenv "ACAD"))
(setvar "SECURELOAD" 0)
(setvar "CMDECHO" 0)
(setvar "FILEDIA" 0)
(setvar "LOGFILEPATH" (strcat (getenv "ALCWALL_TEST_RUN") "/"))
(setvar "LOGFILEMODE" 1)
(setq *alc-install-root* (getenv "ALCWALL_TEST_ROOT"))
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/ALCWALL.lsp"))
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/test-harness.lsp"))
(alc-test--suite "stat-find-reopen-test" "stat-find-test.lsp" 'alc-test-run-stat-find-reopen nil)
'@
    $taskSuites=[ordered]@{'stat-find-reopen-test'=2}
}
if ($StatMaskOnly) {
    $taskCommands=@'
(setq alc-test-saved-secureload (getvar "SECURELOAD") alc-test-saved-acad (getenv "ACAD"))
(setvar "SECURELOAD" 0)
(setvar "CMDECHO" 0)
(setvar "FILEDIA" 0)
(setvar "LOGFILEPATH" (strcat (getenv "ALCWALL_TEST_RUN") "/"))
(setvar "LOGFILEMODE" 1)
(setq *alc-install-root* (getenv "ALCWALL_TEST_ROOT"))
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/ALCWALL.lsp"))
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/test-harness.lsp"))
(alc-test--suite "stat-mask-test" "stat-mask-test.lsp" 'alc-test-run-stat-mask nil)
(alc-test--suite "stat-detail-test" "stat-detail-test.lsp" 'alc-test-run-stat-detail nil)
(alc-test--suite "stat-label-test" "stat-label-test.lsp" 'alc-test-run-stat-label nil)
'@
    $taskSuites=[ordered]@{'stat-mask-test'=8; 'stat-detail-test'=47; 'stat-label-test'=18}
}
if ($StandardWallOnly) {
    $taskCommands=@'
(setq alc-test-saved-secureload (getvar "SECURELOAD") alc-test-saved-acad (getenv "ACAD"))
(setvar "SECURELOAD" 0)
(setvar "CMDECHO" 0)
(setvar "FILEDIA" 0)
(setvar "LOGFILEPATH" (strcat (getenv "ALCWALL_TEST_RUN") "/"))
(setvar "LOGFILEMODE" 1)
(setq *alc-install-root* (getenv "ALCWALL_TEST_ROOT"))
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/ALCWALL.lsp"))
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/test-harness.lsp"))
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/generate-fixtures.lsp"))
(alc-test--suite "match-test" "match-test.lsp" 'alc-test-run-match nil)
(alc-test--suite "standard-wall-test" "standard-wall-test.lsp" 'alc-test-run-standard-wall T)
(alc-test--step 'alc-test-standard-prepare "standard-wall-test")
VV
0,0
1000,0
1500,500
1000,1000
2000,1000
0,1000
0,500

500,50
(alc-test--step 'alc-test-standard-draw-check "standard-wall-test")
_.UNDO
1
(alc-test--step 'alc-test-standard-empty-check "standard-wall-test")
VVC
0,0
1000,0
1500,500
1000,1000
2000,1000
0,1000
0,500

(alc-test--step 'alc-test-standard-draw-check "standard-wall-test")
_.UNDO
1
(alc-test--step 'alc-test-standard-empty-check "standard-wall-test")
(alc-test--step 'alc-test-standard-match-prepare "standard-wall-test")
VVM
(alc-test--step 'alc-test-standard-match-check "standard-wall-test")
(sssetfirst nil (ssadd *alc-standard-a* (ssadd *alc-standard-b*)))
VVMATCH
(alc-test--step 'alc-test-standard-match-check "standard-wall-test")
_.UNDO
1
(alc-test--step 'alc-test-standard-match-undo-check "standard-wall-test")
(alc-test--finish "standard-wall-test")
'@
    $taskSuites=[ordered]@{'match-test'=27; 'standard-wall-test'=36}
}
if ($MatchDoorOnly) {
    $taskCommands=@'
(setq alc-test-saved-secureload (getvar "SECURELOAD") alc-test-saved-acad (getenv "ACAD"))
(setvar "SECURELOAD" 0)
(setvar "CMDECHO" 0)
(setvar "FILEDIA" 0)
(setvar "LOGFILEPATH" (strcat (getenv "ALCWALL_TEST_RUN") "/"))
(setvar "LOGFILEMODE" 1)
(setq *alc-install-root* (getenv "ALCWALL_TEST_ROOT"))
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/ALCWALL.lsp"))
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/test-harness.lsp"))
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/generate-fixtures.lsp"))
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/match-test.lsp"))
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/standard-wall-test.lsp"))
(alc-test--suite "match-door-test" "match-door-test.lsp" 'alc-test-run-match-door T)
(alc-test--step 'alc-test-door-public-prepare "match-door-test")
VVM
(alc-test--step 'alc-test-door-public-check "match-door-test")
(sssetfirst nil (ssadd *alc-door-a* (ssadd *alc-door-b*)))
VVMATCH
(alc-test--step 'alc-test-door-public-check "match-door-test")
_.UNDO
1
(alc-test--step 'alc-test-door-public-undo-check "match-door-test")
(alc-test--finish "match-door-test")
'@
    $taskSuites=[ordered]@{'match-door-test'=25}
}
if ($ElevationOnly) {
    $taskCommands=@'
(setq alc-test-saved-secureload (getvar "SECURELOAD") alc-test-saved-acad (getenv "ACAD"))
(setvar "SECURELOAD" 0)
(setvar "CMDECHO" 0)
(setvar "FILEDIA" 0)
(setvar "LOGFILEPATH" (strcat (getenv "ALCWALL_TEST_RUN") "/"))
(setvar "LOGFILEMODE" 1)
(setq *alc-install-root* (getenv "ALCWALL_TEST_ROOT"))
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/ALCWALL.lsp"))
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/test-harness.lsp"))
(load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/generate-fixtures.lsp"))
(alc-test--suite "elevation-test" "elevation-test.lsp" 'alc-test-run-elevation T)
(alc-test--step 'alc-test-mc-prepare "elevation-test")
VVMC
6000
0
150
1500
3300
3000
300
150
200
150
0,0
(alc-test--step 'alc-test-mc-public-check "elevation-test")
_.UNDO
1
(alc-test--step 'alc-test-mc-undo-check "elevation-test")
(alc-test--step 'alc-test-mc-sample "elevation-test")
(alc-test--finish "elevation-test")
'@
    $taskSuites=[ordered]@{'elevation-test'=31}
}
$taskCommands=$taskCommands.TrimEnd("`r","`n")+"`n(setenv `"ACAD`" alc-test-saved-acad)`n(setvar `"SECURELOAD`" alc-test-saved-secureload)`n(setq alc-test-end-file (open (alc-test--result-path `"run.complete`") `"w`"))`n(write-line (getenv `"ALCWALL_TEST_LABEL`") alc-test-end-file)`n(close alc-test-end-file)`n(command-s `"_.QSAVE`")`n_.QUIT`n_Y`n"
if ($AssignEnterUI) {
    $taskCommands=$taskCommands.Substring(0,$taskCommands.IndexOf('(setenv "ACAD" alc-test-saved-acad)'))+@'
(alc-test-enter-prepare)
ALCASSIGN
(alc-test-enter-check "Enter-from-number" "ALC_Enter_150" 150.0)
ALCASSIGN
(alc-test-enter-check "Enter-from-width" "ALC_Enter_150" 125.0)
VVASSIGN
(alc-test-enter-check "Enter-from-list" "ALC_Enter_100" 100.0)
(alc-test--finish "assign-enter-test")
'@+"`n"+$taskCommands.Substring($taskCommands.IndexOf('(setenv "ACAD" alc-test-saved-acad)'))
    $taskSuites['assign-enter-test']=3
}
$taskExplicitEnv=@"
(setq alc-test-env-before (mapcar 'getenv '("ALCWALL_TEST_ROOT" "ALCWALL_TEST_RUN" "ALCWALL_TEST_LABEL")))
(setenv "ALCWALL_TEST_ROOT" "$($taskRoot.Replace('\','/'))")
(setenv "ALCWALL_TEST_RUN" "$($taskRun.Replace('\','/'))")
(setenv "ALCWALL_TEST_LABEL" "$taskLabel")
"@
$taskCommands=$taskExplicitEnv+"`n"+$taskCommands
$taskCommands=$taskCommands.Replace('(close alc-test-end-file)', '(close alc-test-end-file)'+"`n"+'(mapcar ''(lambda (key value) (setenv key (if value value ""))) ''("ALCWALL_TEST_ROOT" "ALCWALL_TEST_RUN" "ALCWALL_TEST_LABEL") alc-test-env-before)')
# A blank command after a Lisp expression repeats the last native CAD command.
# Keep deliberate blanks after native commands/coordinates, remove Lisp separators.
$taskCommands=[regex]::Replace($taskCommands, '(?m)^(\([^\r\n]*\))\r?\n(?:[ \t]*\r?\n)+', "`$1`n")
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
    $taskWindowStyle=if ($AssignEnterUI) { 'Normal' } else { 'Hidden' }
    $taskProcess=Start-Process -FilePath $taskExe -ArgumentList $taskArgs -WindowStyle $taskWindowStyle -PassThru -RedirectStandardOutput (Join-Path $taskRun 'stdout.log') -RedirectStandardError (Join-Path $taskRun 'stderr.log')
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
