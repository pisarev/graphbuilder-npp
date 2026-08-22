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

  Run: powershell -ExecutionPolicy Bypass -File build-lazarus.ps1
#>

param([switch]$Keep)

$ErrorActionPreference = 'Stop'
$Here = $PSScriptRoot

$LazDir = if ($env:LAZARUS_DIR) { $env:LAZARUS_DIR } else { 'C:\lazarus' }
$Laz = Join-Path $LazDir 'lazbuild.exe'
$Proj = Join-Path $Here 'lazarus\GraphBuilderLaz.lpi'

if (-not (Test-Path $Laz)) { throw "no lazbuild: $Laz (set LAZARUS_DIR)" }
if (-not (Test-Path $Proj)) { throw "no project: $Proj" }

<#
  The project names WebView4Delphi as a required package, and lazbuild looks for
  packages in the list its configuration knows - not along the source paths. The
  environment variable resolves the paths inside the project file but does not
  make the package known, so on a Lazarus configuration where it was never
  installed the build stopped with "Broken dependency: WebView4Delphi". On this
  machine it was installed years ago, which is exactly why the fault stayed
  invisible here.

  The link therefore has to be registered - but NOT in your configuration.
  Registering a package link writes into the Lazarus config and REPLACES any
  entry that already names the same package: measured by putting a different
  checkout in the list and running the registration, after which the entry
  pointed at the new path. A build script that silently repoints your IDE at
  another copy of a third-party library is worse than a build that stops.

  So the whole build runs in a throwaway copy of your configuration:

    * the copy lives in a temp folder unique to this run;
    * the source configuration is only ever read;
    * the package link is registered in the copy;
    * every lazbuild call of this run uses the copy;
    * the copy is removed at the end, whatever happens;
    * a failed copy stops the build - it does not fall back to the real one.

  LAZARUS_PCP is the SOURCE of that copy, not a place this script writes to.

  The .lpk goes to lazbuild as a SEPARATE argument. `lazbuild --help` prints the
  option as --add-package-link=<.lpk file>, and written that way lazbuild refuses
  it: "Option at position 2 does not allow an argument". Its own help is wrong.
#>
if (-not $env:WEBVIEW4DELPHI) {
    throw 'WEBVIEW4DELPHI is not set: point it at a checkout of WebView4Delphi'
}
$Lpk = Join-Path $env:WEBVIEW4DELPHI 'packages\webview4delphi.lpk'
if (-not (Test-Path $Lpk)) {
    throw "no package file: $Lpk (is WEBVIEW4DELPHI a checkout of the library?)"
}

<#
  Where the configuration comes from.

  LAZARUS_PCP, when set, is the ANSWER and not a suggestion. An early version of
  this searched a list - the variable, then LOCALAPPDATA, then APPDATA - and took
  the first entry that happened to hold an environmentoptions.xml. So a variable
  pointing at a typo, or at a configuration that has not been created yet, was
  silently replaced by your ordinary one: the build then used settings you never
  named. An explicit override that is quietly ignored is worse than none.

  With it unset there is nothing to inherit and nothing to guess: the throwaway
  configuration starts EMPTY. lazbuild fills it in from the installation itself -
  it copies <LazarusDir>\environmentoptions.xml into a --pcp folder that has
  none, and reports it as "CopySecondaryConfigFile".

  That is a change. The version before this one searched LOCALAPPDATA, APPDATA
  and config_lazarus beside the Lazarus folder, and stopped when it found none of
  the three. Both halves of that were wrong, and both were measured:

    * from nothing it stopped. A machine where Lazarus is installed but its IDE
      has never been started holds a configuration in none of those places - and
      that machine is the one these instructions are written for;
    * where it did find one, that one won. Six stale lines left on the release
      machine named a DIFFERENT Lazarus, and the build obeyed them rather than
      LAZARUS_DIR: the path it really compiled against stands afterwards in
      lazarus\lib\x86_64-win64\GraphBuilderLaz.compiled.

  An empty start carries neither fault. There is nothing to look for, and the
  settings are those of the installation the reader named.
#>
<#
  The path is glued with Combine rather than Join-Path on purpose. Join-Path
  resolves against drives, so a variable naming a drive that does not exist -
  the very typo this check exists to catch - made it throw its own error, and the
  explanatory message below never appeared. Combine is plain string work and
  never touches the filesystem.
#>
function Usable([string] $Path) {
    if (-not $Path) { return $false }
    return Test-Path ([IO.Path]::Combine($Path, 'environmentoptions.xml'))
}

$SrcPcp = ''
if ($env:LAZARUS_PCP) {
    if (-not (Usable $env:LAZARUS_PCP)) {
        throw "LAZARUS_PCP does not hold a Lazarus configuration: $($env:LAZARUS_PCP) (no environmentoptions.xml there)"
    }
    $SrcPcp = $env:LAZARUS_PCP
}

$Pcp = Join-Path ([IO.Path]::GetTempPath()) ('graphbuilder-pcp-' + [Guid]::NewGuid().ToString('N'))
if ($SrcPcp) { Write-Host "=== CONFIG COPY $SrcPcp -> $Pcp ===" }
else { Write-Host "=== CONFIG EMPTY $Pcp - lazbuild takes it from $LazDir ===" }

<#
  The copy is INSIDE the try, and that is the whole point of moving it here.

  It used to sit above with a try/catch of its own, and the promise "the throwaway
  copy goes, whatever happens" was false exactly where it mattered: a copy that
  fails halfway leaves part of the tree behind, and the finally that would have
  removed it had not been entered yet. Remove-Item is safe even if the folder
  never appeared, so nothing is lost by covering the copy too.
#>
try {
    if ($SrcPcp) {
        try { Copy-Item $SrcPcp $Pcp -Recurse -Force -ErrorAction Stop }
        catch { throw "the configuration could not be copied: $_" }
    }
    else {
        New-Item -ItemType Directory -Force $Pcp | Out-Null
    }

    <#
      A copied configuration can carry a RELATIVE path to the Lazarus folder -
      the stock installers write "..\lazarus" - and relative to a temp folder it
      resolves to nothing. Seen live: the copy failed with "Invalid Lazarus
      directory". The path is made absolute in the copy only.
    #>
    $EnvXml = Join-Path $Pcp 'environmentoptions.xml'
    if (Test-Path $EnvXml) {
        $Doc = [xml](Get-Content -Raw $EnvXml)
        $Node = $Doc.SelectSingleNode('//LazarusDirectory')
        if ($Node -and -not [IO.Path]::IsPathRooted($Node.GetAttribute('Value'))) {
            $Node.SetAttribute('Value', $LazDir)
            $Doc.Save($EnvXml)
            Write-Host "    Lazarus folder in the copy set to $LazDir"
        }
    }


    <#
      An empty configuration does not know where Lazarus lives, and lazbuild
      has nowhere else to learn it from: the line above promises it "takes it
      from $LazDir" and nothing carried that promise into the call. On a
      machine with no Lazarus configuration of its own - which is exactly the
      stranger this script is written for - both calls failed with "invalid
      Lazarus directory": directory lcl not found. The folder is therefore
      named on the command line whenever the copy is empty.
    #>
    <#
      The compiler has to be named too. An empty configuration knows no
      compiler either, and lazbuild then walks its built-in list of guesses
      and ends with "no proper compiler found" - a message that says nothing
      about what is missing. FPC_EXE names it; without the variable the
      folder of Lazarus is searched, which is where a bundled FPC lives.
    #>
    $Fpc = $env:FPC_EXE
    if (-not $Fpc) {
        $Fpc = Get-ChildItem (Join-Path $LazDir "fpc") -Filter "fpc.exe" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
    }
    if ($SrcPcp) {
        $Where = @()
    }
    else {
        if (-not $Fpc) {
            throw "no configuration of Lazarus and no compiler found: set FPC_EXE to fpc.exe, or LAZARUS_PCP to your Lazarus configuration"
        }
        $Where = @("--lazarusdir=$LazDir", "--compiler=$Fpc")
        Write-Host "    compiler for the empty copy: $Fpc"
    }
    Write-Host "=== REGISTER $Lpk ==="
    & $Laz --pcp="$Pcp" @Where '--add-package-link' "$Lpk"
    if ($LASTEXITCODE -ne 0) { throw "the package was not registered: $Lpk" }

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
    & $Laz --pcp="$Pcp" @Where $Proj
    if ($LASTEXITCODE -ne 0) { throw 'the build did not pass' }
}
finally {
    # Whatever happened above, the throwaway configuration goes. Your own is
    # untouched by construction: nothing here ever wrote to it.
    Remove-Item $Pcp -Recurse -Force -ErrorAction SilentlyContinue
}

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

<#
  The list of signs and functions travels beside the library, not inside ui.
  The panel shows it on a button and the HOST reads the file: a page opened
  from a file is not allowed to fetch its neighbour. Leave it out and the
  panel shows whatever list the previous install left behind - the very
  thing the list was introduced to prevent.
#>
Copy-Item (Join-Path $Here 'web\syntax.xml') (Join-Path $Here 'lazarus\bin') -Force

Get-ChildItem (Join-Path $Here 'lazarus\bin') | Select-Object Name, Length |
    Format-Table -AutoSize
Write-Host "Done: $Dll"
