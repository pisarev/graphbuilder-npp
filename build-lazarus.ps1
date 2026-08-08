<#
  Building the plugin with Lazarus / FPC.

  Written in English at the source: unlike the monorepo scripts this file exists
  only for the published repository, so there is nothing to translate later.

  The result is GraphBuilderLaz.dll - a second build of the same plugin, made by
  FPC rather than Delphi. Both export the six entry points Notepad++ looks for,
  and both load the same web/index.html.

  The repository is not self-contained - it expects pascal-mathparser and
  pascal-crossgraph as SIBLING folders. Those two paths are written into the
  project file and are not overridable: keep the three repositories side by
  side, the way they are cloned.

  Only three things are read from the environment, and each is read here or in
  the project file: LAZARUS_DIR (the Lazarus folder), LAZARUS_PCP (its config)
  and WEBVIEW4DELPHI.

  An earlier version of this text also named PARSER_SRC, PARSER_JIT and
  GRAPH_SRC. Nothing ever read them. A documented override that does nothing is
  worse than none: it sends the reader looking for a fault in their own setup.

  WebView4Delphi is not part of this repository: it is a third-party library
  under its own licence. Point WEBVIEW4DELPHI at a checkout of it - the project
  file resolves its source paths through $Env(WEBVIEW4DELPHI), and this script
  registers its Lazarus package for you.

  Run: pwsh -File build-lazarus.ps1
#>

param([switch]$Keep)

$ErrorActionPreference = 'Stop'
$Here = $PSScriptRoot

$LazDir = if ($env:LAZARUS_DIR) { $env:LAZARUS_DIR } else { 'C:\lazarus' }
$Laz = Join-Path $LazDir 'lazbuild.exe'
$Pcp = if ($env:LAZARUS_PCP) { $env:LAZARUS_PCP } else { '' }
$Proj = Join-Path $Here 'lazarus\GraphBuilderLaz.lpi'

if (-not (Test-Path $Laz)) { throw "no lazbuild: $Laz (set LAZARUS_DIR)" }
if (-not (Test-Path $Proj)) { throw "no project: $Proj" }

<#
  The project names WebView4Delphi as a required package, and lazbuild looks for
  packages in the list its configuration knows - not along the source paths. The
  environment variable resolves the paths inside the project file but does not
  make the package known, so on a Lazarus configuration where it was never
  installed the build stopped with the package missing. On this machine it was
  installed years ago, which is exactly why the fault stayed invisible here.

  The link is registered here instead. Registering it again is harmless, so the
  step is unconditional rather than guarded by a check for what is already there.

  The file goes as a SEPARATE argument. `lazbuild --help` prints the option as
  --add-package-link=<.lpk file>, and written that way lazbuild refuses it:
  "Option at position 2 does not allow an argument". Its own help is wrong here.
#>
if ($env:WEBVIEW4DELPHI) {
    $Lpk = Join-Path $env:WEBVIEW4DELPHI 'packages\webview4delphi.lpk'
    if (Test-Path $Lpk) {
        Write-Host "=== REGISTER $Lpk ==="
        if ($Pcp) { & $Laz --pcp="$Pcp" '--add-package-link' "$Lpk" }
        else { & $Laz '--add-package-link' "$Lpk" }
        if ($LASTEXITCODE -ne 0) { throw "the package was not registered: $Lpk" }
    } else {
        throw "no package file: $Lpk (is WEBVIEW4DELPHI a checkout of the library?)"
    }
} else {
    Write-Host 'WEBVIEW4DELPHI is not set: the build needs the package already installed'
}

<#
  lazbuild from trunk (seen on Lazarus 4.99 / FPC 3.3.1) fails with an access
  violation in DoCheckIfProjectNeedsCompilation when the output folders are
  already populated and there is no valid .lps session from the IDE. Checked in
  isolation: remove the .lps of the stock WebView4Delphi demo and it fails the
  same way. Hence the clean-up before the build.
#>
if (-not $Keep) {
    foreach ($d in @((Join-Path $Here 'lazarus\lib'), (Join-Path $Here 'lazarus\bin'))) {
        if (Test-Path $d) { Remove-Item $d -Recurse -Force }
    }
}

Write-Host '=== BUILD GraphBuilderLaz.dll (Lazarus/FPC, win64) ==='
if ($Pcp) { & $Laz --pcp="$Pcp" $Proj } else { & $Laz $Proj }
if ($LASTEXITCODE -ne 0) { throw 'the build did not pass' }

<#
  Lazarus appends .exe to the target name even though the .lpr is declared a
  library and the output really is a DLL (the DLL flag is set in the PE header).
  Notepad++ looks for plugins by the .dll extension, so the file is renamed.
#>
$Made = Join-Path $Here 'lazarus\bin\GraphBuilderLaz.exe'
$Dll = Join-Path $Here 'lazarus\bin\GraphBuilderLaz.dll'
if (-not (Test-Path $Made)) { throw "no build result: $Made" }
Move-Item $Made $Dll -Force

if ($env:WEBVIEW4DELPHI) {
    $Loader = Join-Path $env:WEBVIEW4DELPHI 'bin64\WebView2Loader.dll'
    if (Test-Path $Loader) {
        Copy-Item $Loader (Join-Path $Here 'lazarus\bin') -Force
    }
    else {
        Write-Host "WebView2Loader.dll not found at $Loader - copy it by hand"
    }
}
else {
    Write-Host 'WEBVIEW4DELPHI is not set: copy WebView2Loader.dll next to the DLL by hand'
}

<#
  The page is part of the plugin rather than a separate resource: the panel
  loads it from the ui folder next to the library. Without this step an edit to
  the page never reaches the plugin, and it quietly runs the old copy. The same
  page is used by the Delphi build.
#>
$Ui = Join-Path $Here 'lazarus\bin\ui'
New-Item -ItemType Directory -Force $Ui | Out-Null
Copy-Item (Join-Path $Here 'web\index.html') $Ui -Force

Get-ChildItem (Join-Path $Here 'lazarus\bin') | Select-Object Name, Length |
    Format-Table -AutoSize
Write-Host "Done: $Dll"
