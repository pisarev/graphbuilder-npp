# Installing the plugin, with a check. Putting the wrong build in place silently
# is far too easy here: Notepad++ holds the library open, the copy fails, and the
# editor goes on running the previous version.
#
# By default this installs the build that ships - the Lazarus one, the same
# library the release archive contains. Pass -Delphi to install the Delphi build
# instead; it is the development build and goes into a folder of its own, so the
# two never overwrite each other.
#
# NPP_DIR points at the Notepad++ folder if it is not the standard one.
param([switch]$Build, [switch]$Delphi)

$ErrorActionPreference = 'Stop'
$Here = $PSScriptRoot

if ($Delphi) {
    $Name = 'GraphBuilder'
    $Source = Join-Path $Here 'out\GraphBuilder.dll'
    $Builder = 'build.ps1'
} else {
    $Name = 'GraphBuilderLaz'
    $Source = Join-Path $Here 'lazarus\bin\GraphBuilderLaz.dll'
    $Builder = 'build-lazarus.ps1'
}

$Npp = if ($env:NPP_DIR) { $env:NPP_DIR } else { 'C:\Program Files\Notepad++' }
$Target = Join-Path $Npp "plugins\$Name\$Name.dll"

if ($Build) { & (Join-Path $Here $Builder) }

if (-not (Test-Path $Source)) { throw "no built library: $Source. Build it: $Builder" }

$Running = Get-Process notepad++ -ErrorAction SilentlyContinue
if ($Running) {
    throw "Notepad++ is running (PID $($Running.Id)) and holds the library. Close it and try again."
}

$Folder = Split-Path $Target
if (-not (Test-Path $Folder)) { New-Item -ItemType Directory -Force $Folder | Out-Null }

Copy-Item $Source $Target -Force

# The WebView2 loader travels with the library when the build brings its own.
$Loader = Join-Path (Split-Path $Source) 'WebView2Loader.dll'
if (Test-Path $Loader) { Copy-Item $Loader (Join-Path $Folder 'WebView2Loader.dll') -Force }

# The interface page goes next to the library, into a ui folder: that is where
# the plugin looks for it.
$UiTarget = Join-Path $Folder 'ui'
if (-not (Test-Path $UiTarget)) { New-Item -ItemType Directory -Force $UiTarget | Out-Null }
Copy-Item (Join-Path $Here 'web\index.html') (Join-Path $UiTarget 'index.html') -Force

$A = (Get-FileHash $Source -Algorithm MD5).Hash
$B = (Get-FileHash $Target -Algorithm MD5).Hash
if ($A -ne $B) { throw "the wrong file was installed: $A against $B" }

Write-Host "Installed: $Target"
Write-Host "Hash check: $A"
Write-Host "Interface page: $(Join-Path $UiTarget 'index.html')"
Write-Host 'Open Notepad++ and press Alt+G.'
