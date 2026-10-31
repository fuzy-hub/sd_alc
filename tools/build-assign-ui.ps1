param([string]$CadRoot='C:\Program Files\Autodesk\AutoCAD 2027', [string]$TestOutput)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$taskDesktopRoot=Join-Path $env:ProgramFiles 'dotnet/shared/Microsoft.WindowsDesktop.App'
$taskDesktop=Get-ChildItem -LiteralPath $taskDesktopRoot -Directory | Where-Object { $_.Name -match '^10\.0\.\d+$' } | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1 -ExpandProperty FullName
if (!$taskDesktop) { throw 'Windows Desktop .NET 10 reference assemblies not found.' }
$taskRefs=@(Get-ChildItem -LiteralPath (Join-Path $PSHOME 'ref') -Filter '*.dll' | ForEach-Object FullName)
$taskRefs+=@('System.Windows.Forms.dll','System.Windows.Forms.Primitives.dll','System.Drawing.Common.dll','System.Private.Windows.Core.dll','System.Private.Windows.GdiPlus.dll') | ForEach-Object { Join-Path $taskDesktop $_ }
$taskRefs+=@('AcMgd.dll','AcCoreMgd.dll','AcDbMgd.dll') | ForEach-Object { Join-Path $CadRoot $_ }
$taskSource=Join-Path $taskRoot 'src/alc-assign-ui.cs'
$taskOutput=Join-Path $taskRoot 'src/alc-assign-ui.dll'
if ($TestOutput) {
    $taskSource=Join-Path $taskRoot 'tests/assign-ui-test.cs'
    $taskOutput=$TestOutput
    $taskRefs+=Join-Path $taskRoot 'src/alc-assign-ui.dll'
}
if (Test-Path -LiteralPath $taskOutput) { Remove-Item -LiteralPath $taskOutput }
# Use a deterministic assembly identity so the AutoCAD test adapter can resolve it.
[void][Reflection.Assembly]::LoadFrom((Join-Path $PSHOME 'Microsoft.CodeAnalysis.dll'))
[void][Reflection.Assembly]::LoadFrom((Join-Path $PSHOME 'Microsoft.CodeAnalysis.CSharp.dll'))
$taskTree=[Microsoft.CodeAnalysis.CSharp.CSharpSyntaxTree]::ParseText([IO.File]::ReadAllText($taskSource))
$taskMetadata=[Microsoft.CodeAnalysis.MetadataReference[]]@($taskRefs | ForEach-Object { [Microsoft.CodeAnalysis.MetadataReference]::CreateFromFile($_) })
$taskOptions=[Microsoft.CodeAnalysis.CSharp.CSharpCompilationOptions]::new([Microsoft.CodeAnalysis.OutputKind]::DynamicallyLinkedLibrary)
$taskCompilation=[Microsoft.CodeAnalysis.CSharp.CSharpCompilation]::Create([IO.Path]::GetFileNameWithoutExtension($taskOutput), [Microsoft.CodeAnalysis.SyntaxTree[]]@($taskTree), $taskMetadata, $taskOptions)
$taskStream=[IO.File]::Create($taskOutput)
try { $taskResult=$taskCompilation.Emit($taskStream) } finally { $taskStream.Dispose() }
if (!$taskResult.Success) { throw ($taskResult.Diagnostics -join [Environment]::NewLine) }
