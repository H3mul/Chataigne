[CmdletBinding()]
param(
  [string]$ProjectName = "Chataigne",
  [string]$Solution = "Builds/VisualStudio2022_CI/Chataigne.sln",
  [ValidateSet("Debug", "Release")]
  [string]$Configuration = "Release",
  [string]$Platform = "x64",
  [string]$OutFile = "compile_commands.json"
)

$ErrorActionPreference = "Stop"

# Make paths deterministic regardless of where this script is invoked from.
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

$ModuleDir = Join-Path $RepoRoot "Tools\MsBuildCompileCommandsJson"
$Csproj = Join-Path $ModuleDir "CompileCommandsJson.csproj"
if (-not (Test-Path $Csproj)) {
  throw "MsBuildCompileCommandsJson submodule not found at $Csproj. Run 'task setup' first."
}

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
  throw "dotnet SDK not found. Install .NET SDK to build the MSBuild logger."
}

Write-Host "Building MSBuild compile_commands.json logger..."
dotnet build $Csproj -c Release

$LoggerDll = Join-Path $ModuleDir "bin\Release\netstandard2.0\CompileCommandsJson.dll"
if (-not (Test-Path $LoggerDll)) {
  throw "Logger DLL not found after build: $LoggerDll"
}

$SlnPath = (Resolve-Path (Join-Path $RepoRoot $Solution)).Path
if (-not (Test-Path $SlnPath)) {
  throw "Solution not found: $SlnPath"
}

$OutPath = (Join-Path $RepoRoot $OutFile)
$TmpPath = "$OutPath.tmp"
Remove-Item $TmpPath -ErrorAction SilentlyContinue

Write-Host "Running MSBuild with logger to capture compiler invocations (clean rebuild)..."
$LoggerArg = "-logger:$LoggerDll;$TmpPath"

& msbuild $SlnPath /t:Rebuild /p:PreferredToolArchitecture=x64 /p:Configuration=$Configuration /p:Platform=$Platform /verbosity:minimal $LoggerArg
if ($LASTEXITCODE -ne 0) {
  throw "msbuild failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path $TmpPath)) {
  throw "MSBuild completed but did not produce $TmpPath (check msbuild output for logger errors)"
}

Move-Item $TmpPath $OutPath -Force
Write-Host "Wrote $OutPath"
