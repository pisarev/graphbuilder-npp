<#
  Building the Notepad++ plugin.

  Written in English at the source: unlike the monorepo scripts this file exists
  only for the published repository, so there is nothing to translate later.

  The plugin target is x64 only - that is what this plugin supports, not a
  property of the editor: Notepad++ itself also ships 32-bit and ARM64 builds,
  and neither of them will load this one. The repository is not
  self-contained - it expects pascal-mathparser and pascal-crossgraph beside it.
  Override with PARSER_SRC, PARSER_JIT, and GRAPH_SRC; the Delphi folder with
  BDS_BIN.

  Run: powershell -ExecutionPolicy Bypass -File build.ps1
#>

$ErrorActionPreference = 'Stop'

# The bin folder of the studio. Order: the builder's own variable, the one RAD
# Studio sets for its command prompt, then the registry. The registry replaced a
# path written here by hand. That path named a single version - 13 - and on a
# machine with Delphi 12 the build stopped at "dcc64.exe is not recognized",
# which says nothing about the real cause: the studio is installed, just not
# that one.
function Find-BdsBin($Keys = @('HKLM:\SOFTWARE\WOW6432Node\Embarcadero\BDS',
                               'HKLM:\SOFTWARE\Embarcadero\BDS')) {
    $found = @()
    foreach ($key in $Keys) {
        if (-not (Test-Path $key)) { continue }
        foreach ($item in Get-ChildItem $key) {
            $root = (Get-ItemProperty -Path $item.PSPath -Name RootDir -ErrorAction SilentlyContinue).RootDir
            if (-not $root) { continue }
            $bin = Join-Path $root 'bin'
            if (-not (Test-Path (Join-Path $bin 'dcc64.exe'))) { continue }
            # The key is named after the version: 19.0, 23.0, 37.0. Only the major
            # part is read, and as an integer: [double] would parse 23.0 through the
            # current culture and give nothing on a comma-decimal one.
            $number = 0
            [void][int]::TryParse((($item.PSChildName -split '\.')[0]), [ref]$number)
            $found += [pscustomobject]@{ Version = $number; Bin = $bin }
        }
    }
    if (-not $found) { return '' }
    ($found | Sort-Object Version -Descending)[0].Bin
}

$Bin = if ($env:BDS_BIN) { $env:BDS_BIN }
       elseif ($env:BDS) { Join-Path $env:BDS 'bin' }
       else { Find-BdsBin }
if (-not $Bin -or -not (Test-Path (Join-Path $Bin 'dcc64.exe'))) {
    throw 'Delphi was not found. Set BDS_BIN to the bin folder of the installation, or run this from the RAD Studio command prompt.'
}

$Here = $PSScriptRoot
$Src = Join-Path $Here 'src'
$Out = Join-Path $Here 'out'

$Parser = if ($env:PARSER_SRC) { $env:PARSER_SRC }
          else { (Resolve-Path (Join-Path $Here '..\pascal-mathparser\src')).Path }
$Jit = if ($env:PARSER_JIT) { $env:PARSER_JIT }
       else { (Resolve-Path (Join-Path $Here '..\pascal-mathparser\jit')).Path }
$Graph = if ($env:GRAPH_SRC) { $env:GRAPH_SRC }
         else { (Resolve-Path (Join-Path $Here '..\pascal-crossgraph\src')).Path }

$Units = @(
    $Src
    (Join-Path $Here 'bindings')
    $Parser
    $Graph
    $Jit
    (Join-Path (Split-Path $Bin) 'lib\win64\release')
) -join ';'

New-Item -ItemType Directory -Force (Join-Path $Out 'dcu') | Out-Null
Write-Host '=== BUILD GraphBuilder.dll (win64) ==='
& (Join-Path $Bin 'dcc64.exe') -B -Q ('-U' + $Units) ('-I' + $Parser) ('-E' + $Out) `
    ('-N0' + (Join-Path $Out 'dcu')) '-NSSystem;System.Win;WinApi;Vcl;Vcl.Imaging;Web;Data' `
    (Join-Path $Src 'GraphBuilder.dpr')
if ($LASTEXITCODE -ne 0) { throw 'build failed' }

<#
  The page is part of the plugin rather than a separate resource: the panel
  loads it from the ui folder next to the library. Without this step an edit to
  the page never reaches the plugin, and it quietly runs the old copy. The same
  page is used by the Lazarus build.
#>
<#
  The WebView2 loader travels beside the library, the same way the Lazarus build
  does it: install.ps1 takes the loader from next to $Source, and for this build
  that is the out folder. Without this step the switch -Delphi installs a plugin
  without the loader, while the archive and the Lazarus recipe both carry it.
#>
# A warning here is not enough. The build would report success, install.ps1 would
# then refuse, and the reader would meet the wall one step away from its cause -
# which is exactly what happened on a clean stand on 27.08.2026. The build stops
# where the thing is missing.
if (-not $env:WEBVIEW4DELPHI) {
    throw ('WEBVIEW4DELPHI is not set. The panel is drawn by WebView2, and its loader comes from a WebView4Delphi checkout: point the variable at one and build again.')
}
$Loader = Join-Path $env:WEBVIEW4DELPHI 'bin64\WebView2Loader.dll'
if (-not (Test-Path $Loader)) {
    throw "WebView2Loader.dll is not at $Loader. Check the checkout named by WEBVIEW4DELPHI."
}
Copy-Item $Loader $Out -Force

$Ui = Join-Path $Out 'ui'
New-Item -ItemType Directory -Force $Ui | Out-Null
Copy-Item (Join-Path $Here 'web\index.html') $Ui -Force

Get-ChildItem $Out -Filter *.dll | Select-Object Name, Length

Write-Host @'

To install this build (needs administrator rights):
  powershell -ExecutionPolicy Bypass -File install.ps1 -Delphi

The switch is not optional here: this script builds the Delphi library, and
install.ps1 without it looks for the Lazarus one.
'@
