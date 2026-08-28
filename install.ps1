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

# Held open by the editor - but only by the editor being installed INTO. A
# Notepad++ running from somewhere else holds nothing here, and refusing for it
# is a rule wider than its own reason: a portable copy open in another folder
# blocked the install for no cause. Where a process runs from cannot always be
# read; when it cannot, it counts as blocking, because guessing the other way
# installs over a library in use.
$Running = @(Get-Process notepad++ -ErrorAction SilentlyContinue | Where-Object {
    (-not $_.Path) -or $_.Path.StartsWith($Npp, [StringComparison]::OrdinalIgnoreCase)
})
if ($Running.Count) {
    $ids = ($Running | ForEach-Object { $_.Id }) -join " "
    throw "Notepad++ from $Npp is running (PID $ids) and holds the library. Close it and try again."
}

$Folder = Split-Path $Target

# Rights are checked by DOING, not by asking who you are. A Notepad++ that lives
# under your own profile needs no elevation at all, and a question about the
# Administrators group would refuse that case for nothing. What the copy needs is
# one thing - a folder it can write into - so that is what is tried here, before
# anything is changed.
try {
    if (-not (Test-Path $Folder)) { New-Item -ItemType Directory -Force $Folder | Out-Null }
    $Probe = Join-Path $Folder ([IO.Path]::GetRandomFileName())
    [IO.File]::WriteAllText($Probe, '')
    Remove-Item $Probe -Force
} catch {
    throw ("cannot write into $Folder. Installing into Program Files needs a " +
           "prompt started as administrator; for a Notepad++ somewhere else " +
           "point NPP_DIR at it.")
}

Copy-Item $Source $Target -Force

# The WebView2 loader. Missing it is not a detail to pass over in silence: the
# panel then fails to start and the plugin shows whatever is underneath, which
# looks like a working - and different - program. Measured 27.08.2026 on a clean
# stand: the install reported success, the panel opened, and it was the old
# interface, because this file was not there.
$Loader = Join-Path (Split-Path $Source) 'WebView2Loader.dll'
if (-not (Test-Path $Loader)) {
    throw ("WebView2Loader.dll is missing next to $Source. The build script " +
           'copies it from WEBVIEW4DELPHI; set that variable and build again, ' +
           'or put the file there by hand. Without it the panel cannot start.')
}
Copy-Item $Loader (Join-Path $Folder 'WebView2Loader.dll') -Force

# And, for the Delphi build, next to the EDITOR as well. Windows resolves a
# library asked for by plain name against the folder of the process executable,
# not against the folder of the dll that asks. TEdgeBrowser asks by name, so for
# it the copy beside the plugin is invisible; the Lazarus build computes the path
# from its own module and needs only the one beside itself.
if ($Delphi) {
    Copy-Item $Loader (Join-Path $Npp 'WebView2Loader.dll') -Force
}

# The interface page goes next to the library, into a ui folder: that is where
# the plugin looks for it.
$UiTarget = Join-Path $Folder 'ui'
if (-not (Test-Path $UiTarget)) { New-Item -ItemType Directory -Force $UiTarget | Out-Null }
Copy-Item (Join-Path $Here 'web\index.html') (Join-Path $UiTarget 'index.html') -Force

# The reference of signs and functions goes BESIDE the library, not into ui.
# Inside the plugin the page does not read it itself: it asks the host, and the
# host looks for syntax.xml next to its own dll. Left out here until 1.3.4, and
# every install made by this script answered "The reference cannot be read" -
# the archive carried the file, this script did not.
Copy-Item (Join-Path $Here 'web\syntax.xml') (Join-Path $Folder 'syntax.xml') -Force

$A = (Get-FileHash $Source -Algorithm SHA256).Hash
$B = (Get-FileHash $Target -Algorithm SHA256).Hash
if ($A -ne $B) { throw "the wrong file was installed: $A against $B" }

Write-Host "Installed: $Target"
Write-Host "Hash check: $A"
Write-Host "Interface page: $(Join-Path $UiTarget 'index.html')"
Write-Host "Reference: $(Join-Path $Folder 'syntax.xml')"
Write-Host "WebView2 loader: $(Join-Path $Folder 'WebView2Loader.dll')"
if ($Delphi) { Write-Host "WebView2 loader for the editor: $(Join-Path $Npp 'WebView2Loader.dll')" }
Write-Host 'Open Notepad++ and press Alt+G.'
