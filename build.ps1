<#
  Building the Notepad++ plugin.

  Written in English at the source: unlike the monorepo scripts this file exists
  only for the published repository, so there is nothing to translate later.

  Notepad++ 8.9 is x64, so only x64 is built. The repository is not
  self-contained - it expects pascal-mathparser and pascal-crossgraph beside it.
  Override with PARSER_SRC, PARSER_JIT, and GRAPH_SRC; the Delphi folder with
  BDS_BIN.

  Run: pwsh -File build.ps1
#>

$ErrorActionPreference = 'Stop'

$Bin = if ($env:BDS_BIN) { $env:BDS_BIN }
       elseif ($env:BDS) { Join-Path $env:BDS 'bin' }
       else { 'C:\Program Files (x86)\Embarcadero\Studio\37.0\bin' }

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
$Ui = Join-Path $Out 'ui'
New-Item -ItemType Directory -Force $Ui | Out-Null
Copy-Item (Join-Path $Here 'web\index.html') $Ui -Force

Get-ChildItem $Out -Filter *.dll | Select-Object Name, Length

Write-Host @'

To install (needs administrator rights):
  pwsh -File install.ps1
'@
