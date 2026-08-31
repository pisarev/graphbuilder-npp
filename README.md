# GraphBuilder - plotting inside Notepad++

A docked panel that plots the formula under your mouse. Press Alt+B to open it,
then point at a line of your file: if what is there parses as a formula, the
curve appears - with its roots, its intersections and its extrema found for you.
Select an expression and the selection wins over the line.

The panel keeps one slot for what comes from the editor, so pointing around does
not fill the list: your own formulas stay where you put them.

The report goes back the other way. One button sends it to a new tab as
Markdown - a table of roots, discontinuities, monotonic intervals, area and mean,
with the curve itself embedded as SVG, which is text and therefore survives in a
text editor while still drawing a real curve wherever Markdown is rendered.
Another button drops the same report at the caret, for when you are writing a
document rather than reading one.

Markdown in Notepad++ is a user-defined language rather than a built-in one, so
the new tab is switched to it by name; if your editor does not carry that
language, the tab stays plain text and the report reads just as well.

The panel is a web page hosted in WebView2; the computing is Object Pascal. The
page asks and draws, Pascal answers. That split is why the same page also runs
as the [live demo](https://pisarev.github.io/mathparser-live/demo/) in a browser
- but only the parser is the same code there, compiled to WebAssembly, and it
answers the values behind the curves. The segments, the intersections and the
extrema are written again in JavaScript, because the plotting engine is native
code and does not run in a browser. Treat the demo as a look at the formulas,
not as proof that the two agree point for point.

## What is in here

| | |
|---|---|
| `src/` | the plugin: the panel, the bridge to the page, the report, the theme, the icons |
| `bindings/` | our own Notepad++ bindings - written from the published ABI, no third-party code |
| `web/index.html` | the panel itself. The same file is published as the site demo |
| `web/syntax.xml` | the reference the panel shows on a button: every sign and function the parser knows |
| `lazarus/` | the second build of the same plugin, made with Lazarus/FPC |

## It needs two repositories next to it

```
somewhere/
  pascal-mathparser/
  pascal-crossgraph/
  graphbuilder-npp/
```

Override with `PARSER_SRC`, `PARSER_JIT`, and `GRAPH_SRC` if they live elsewhere,
and `BDS_BIN` if Delphi is not in the standard place. Those four are read by the
Delphi build. The Lazarus project takes its paths from the `.lpi` and wants the
three repositories side by side, as above.

## Two builds of one plugin

The same plugin is built twice, by two different compilers. Both export the six
entry points Notepad++ looks for, both drive the same `web/index.html`, and both
compute with the same Pascal underneath.

| | Delphi | Lazarus / FPC |
|---|---|---|
| built by | `build.ps1` | `build-lazarus.ps1` |
| sources | `src/` | `lazarus/` |
| result | `out/GraphBuilder.dll` | `lazarus/bin/GraphBuilderLaz.dll` |
| browser host | WebView2, through our own binding | WebView2, through WebView4Delphi |
| needs | Delphi 11 Alexandria or newer | Lazarus, FPC, and a WebView4Delphi checkout |

**The binary attached to a release is the Lazarus one.** Both builds work; the
FPC build is what ships because it is made with a free toolchain, so anyone can
reproduce it without a Delphi licence.

The Delphi build wants **11 Alexandria or newer**, and that floor is not ours to
move: it reaches WebView2 through `Winapi.WebView2`, which Embarcadero began
shipping in the RTL with 11. On 10.2, 10.3 and 10.4 the unit is simply absent.
Nothing else here stands in the way - before a release all fourteen units are
compiled one at a time on six installations, and from 11 upwards every one of
them builds. The two libraries this plugin sits on, the parser and the plotting
engine, go back further, to 10.2 Tokyo; the plugin does not, and the difference
is that one missing unit.

WebView4Delphi is not vendored here - it is a third-party library under its own
licence. Its source is not part of this repository; one binary out of it is:
`WebView2Loader.dll`, which is Microsoft's and travels inside the release
archive under the terms of the WebView2 SDK. `INSTALL.txt` in the archive says
the same, so whoever unpacks it is told without coming here first.

Point `WEBVIEW4DELPHI` at a checkout of it before building EITHER version - the
Lazarus one needs its Lazarus package, the Delphi one needs that loader.
`build-lazarus.ps1` registers the package for you rather than expecting it to be
installed already.

## Installation

### From the release

The releases page carries a built plugin - the Lazarus one - as
`GraphBuilder-npp-<version>-win64.zip`. Five files come out of it:

```
GraphBuilderLaz.dll
WebView2Loader.dll
ui/index.html
syntax.xml
INSTALL.txt
```

Close Notepad++, unpack them into `plugins\GraphBuilderLaz\` under your editor,
start it again, and press Alt+B.

Three conditions, and each of them fails quietly when it is not met:

- **the folder is named after the library** - `GraphBuilderLaz` for this build,
  `GraphBuilder` for the Delphi one. Notepad++ does not look inside a folder
  whose name does not match;
- **the editor is closed while you copy.** It holds a loaded plugin open, and a
  copy over a running editor fails without a word, leaving the previous version
  in place;
- **the editor is x64.** Only x64 is built here; the 32-bit and ARM64 editions of
  Notepad++ will not load it.

Installing into `Program Files` needs administrator rights. The panel is a web
page in WebView2, so the WebView2 runtime has to be present - Windows 11 ships
it - and it has to be 150.0.4078.44 or newer. That number is not a preference:
the build declares it to WebView2 as the version it is compatible with, and an
older runtime is refused by Microsoft's loader before the panel is ever drawn.
Two registry queries read the installed one - the first is the machine-wide
install, the second the per-user one, and whichever answers is the one in force:

    reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" /v pv
    reg query "HKCU\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" /v pv

### Building it, from nothing

Both compilers start the same way: an empty folder with the checkouts side by
side. The three commands below clone them with git, and a Windows without git
answers that `git` is not recognized. Git is the shortest way here, not the only
one: every repository named in this section can be taken as a zip instead - the
green `Code` button on its page, `Download ZIP` - and unpacked side by side under
the same folder names. The commands are for `cmd`; where PowerShell needs
something else it is said on the spot.

```
mkdir %USERPROFILE%\Desktop\PascalPlot
cd /d %USERPROFILE%\Desktop\PascalPlot
git clone https://github.com/pisarev/pascal-mathparser.git
git clone https://github.com/pisarev/pascal-crossgraph.git
git clone https://github.com/pisarev/graphbuilder-npp.git
```

`Parser`, `ParseTypes` and `Thread` - the units a compiler asks for first - are
files in the parser repository, not missing pieces of this one:
`pascal-mathparser/src/Parser.pas` and its two neighbours.

#### Lazarus, by script

This is the build a release ships. No Delphi licence, no WebView4Delphi package
installed in your IDE, and no Lazarus configuration of your own: the script
builds in a throwaway one, registers the package there, and leaves yours as it
was. Nor does it expect you to have one. A Lazarus whose IDE has never been
started carries no configuration at all, and `lazbuild` fills the throwaway one
in from the installation itself.

```
git clone --branch 1.0.4078.44 https://github.com/salvadordf/WebView4Delphi.git

set WEBVIEW4DELPHI=%CD%\WebView4Delphi
set LAZARUS_DIR=C:\lazarus

cd graphbuilder-npp
powershell -ExecutionPolicy Bypass -File build-lazarus.ps1
powershell -ExecutionPolicy Bypass -File install.ps1
```

These lines are typed in `cmd`, as everywhere in this section; the scripts
themselves run under the PowerShell that ships with Windows, and nothing here
needs PowerShell 7. `-ExecutionPolicy Bypass` is what lets a downloaded script
run under the default policy, and it holds for that one run only. Typing the
script name on its own does not run it: `cmd` hands a `.ps1` to whatever program
is associated with the extension - usually an editor - and nothing happens, with
no error to explain it. The second line copies into `Program Files`, so that
prompt has to be started as administrator.

The tag is worth keeping. WebView4Delphi carries its own `WebView2Loader.dll`,
and the one beside a release comes from `1.0.4078.44`; the tip of the branch
moves and brings a different loader with it. `LAZARUS_DIR` is only needed when
Lazarus is somewhere other than `C:\lazarus`.

This build compiles the library, so the whole of it has to be there: `lazbuild`
registers `packages\webview4delphi.lpk`, and the project reads its units from
`source\`. The single `WebView2Loader.dll` that is enough for the Delphi build
is not enough here. Without git, take the same tag as a zip -
https://github.com/salvadordf/WebView4Delphi/archive/refs/tags/1.0.4078.44.zip -
and unpack it; the folder comes out with the version in its name, so either
rename it to `WebView4Delphi` or point `WEBVIEW4DELPHI` at it as it is.

Out comes `lazarus\bin\GraphBuilderLaz.dll` with `WebView2Loader.dll` and
`ui\index.html` beside it. `install.ps1` puts those three where they belong,
refuses to run while the editor is open, and compares hashes afterwards.
`NPP_DIR` points it at a Notepad++ that is not in the standard place.

#### Lazarus, by hand

The same checkouts, no scripts. Lazarus wants the WebView4Delphi package
registered before it will open the project - without it `lazbuild` stops with
`Broken dependency: WebView4Delphi`. Registering it in a configuration of its own
leaves your installed Lazarus untouched:

```
mkdir lazpcp
"C:\lazarus\lazbuild.exe" --pcp=%CD%\lazpcp --add-package-link "%CD%\WebView4Delphi\packages\webview4delphi.lpk"

set WEBVIEW4DELPHI=%CD%\WebView4Delphi
"C:\lazarus\lazbuild.exe" --pcp=%CD%\lazpcp graphbuilder-npp\lazarus\GraphBuilderLaz.lpi
```

The `.lpk` goes as an argument of its own after `--add-package-link`; the built-in
help reads as though it belongs to the switch, and that form does not work.

The project links an executable, so the result is renamed and the two files the
panel needs are put beside it:

```
cd graphbuilder-npp\lazarus\bin
ren GraphBuilderLaz.exe GraphBuilderLaz.dll
mkdir ui
copy ..\..\..\WebView4Delphi\bin64\WebView2Loader.dll .
copy ..\..\web\index.html ui\
```

Then copy those three into `plugins\GraphBuilderLaz\`.

#### Delphi, by script

Delphi 11 Alexandria or newer. The floor is one missing unit: this build reaches
WebView2 through `Winapi.WebView2`, which Embarcadero began shipping in the RTL
with 11 - on 10.2, 10.3 and 10.4 it is simply absent, and no search path brings
it back.

The compiler needs nothing else; the panel does. It is drawn by WebView2, and
the loader for it - `WebView2Loader.dll` - is Microsoft's, shipped in the
WebView2 SDK; WebView4Delphi carries a copy in its `bin64`. Point
`WEBVIEW4DELPHI` at a checkout of that library and the build puts the loader
where the installer will look for it. The first line below fetches it: that
library is not part of this release, so having the sources by any other means -
a copy, an archive, a colleague - does not bring it with them.

Without the variable the build stops and says so, rather than producing a plugin
that starts and shows the wrong window.

```
git clone --branch 1.0.4078.44 https://github.com/salvadordf/WebView4Delphi.git
set WEBVIEW4DELPHI=%CD%\WebView4Delphi
cd graphbuilder-npp
powershell -ExecutionPolicy Bypass -File build.ps1
powershell -ExecutionPolicy Bypass -File install.ps1 -Delphi
```

No git on this machine? The build wants one file out of that checkout, not the
checkout itself. Make the folders by hand and put `WebView2Loader.dll` from the
release archive into them:

    WebView4Delphi\bin64\WebView2Loader.dll

Then point `WEBVIEW4DELPHI` at that `WebView4Delphi` folder as above. It is the
same file either way: the archive takes its copy from there. The shortcut is for
this build alone - the Lazarus one compiles the library and needs all of it.

The switch is not optional on the second step: without it `install.ps1` looks for
the Lazarus library and does not find it. That step copies into `Program Files`,
so the prompt has to be started as administrator.

`build.ps1` finds the studio itself: `BDS_BIN` if you set it, then the variable
RAD Studio sets for its own command prompt, then the registry - the newest
installed version whose `bin` holds `dcc64.exe`. Point `BDS_BIN` at a `bin`
folder to pin one particular version.

#### Delphi, by hand

`dcc64` is not on the path by default. It sits in the `bin` folder of the
installation - `C:\Program Files (x86)\Embarcadero\Studio\37.0\bin` for 13
Florence, `23.0` for 12 Athens, `22.0` for 11 Alexandria - and `rsvars.bat`
there puts it on the path of the current prompt.

```
cd graphbuilder-npp
mkdir out
dcc64 -B -Q -U"src;bindings;..\pascal-mathparser\src;..\pascal-mathparser\jit;..\pascal-crossgraph\src" -I"src;bindings;..\pascal-mathparser\src;..\pascal-crossgraph\src" -Eout -NS"System;System.Win;WinApi;Vcl;Vcl.Imaging;Web;Data" src\GraphBuilder.dpr
```

Keep the quotes in PowerShell: `-NS` carries semicolons, and unquoted they are
read as command separators before the compiler ever sees them.

Four things then go into place, not two. Where each comes from, and where it
goes:

    take this file                              put it here
    ------------------------------------------  ---------------------------
    out\GraphBuilder.dll                        plugins\GraphBuilder\
    web\index.html                              plugins\GraphBuilder\ui\
    web\syntax.xml                              plugins\GraphBuilder\
    %WEBVIEW4DELPHI%\bin64\WebView2Loader.dll   next to notepad++.exe

The last row is the odd one, and it is worth knowing why. The panel is drawn by
WebView2, and `TEdgeBrowser` asks for its loader by plain name. Windows looks
for such a name in the folder of the running program - the editor - and never in
the folder of the library that asks. A copy inside the plugin folder is
therefore invisible to it. The file belongs in the same folder as the editor
itself, which on a normal installation means:

    C:\Program Files\Notepad++\WebView2Loader.dll

Two places give you that file. The release archive carries it, so unpacking the
archive anywhere and taking the one file out of it is the shortest way. The
other is the WebView4Delphi checkout named by `WEBVIEW4DELPHI`, subfolder
`bin64` - the same copy, since the archive takes it from there.

`install.ps1 -Delphi` puts all four where they belong, and refuses if the loader
is not there - better a refusal than a plugin that starts and shows the wrong
window.

There is no `.dproj` here, so a project made from the `.dpr` starts with an empty
search path, and that `-U` list is what goes into it. The same paths have to be
on the include path as well: the IDE hands its search path to the compiler as
both, while `dcc64` given only `-U` stops at
`CrossGraph.pas(12) F1026 File not found: 'Directives.inc'`.

#### What a build of your own is, and is not

It is a working plugin. It is not a copy of the shipped file: a release is built
from the monorepo these three repositories are exported from, with a project file
of its own, and the library comes out a different size. A hash that does not
match the archive means the build was yours, not that the download was broken.

## The library is not signed

Windows Application Control blocks unsigned libraries: Smart App Control on a
fresh Windows 11, or a WDAC policy inside a managed organisation. Where such a
policy is on, the plugin does not load - the loader fails with error 4551, "an
Application Control policy has blocked this file", and nothing is missing from
the archive.

This was measured inside Windows Sandbox, where the policy is on by default. The
import table of the library was read at the same time: ten modules, all of them
stock Windows, all present. Nothing from Delphi, Lazarus, Free Pascal or the
Visual C++ runtime is needed.

In practice few machines are affected. Smart App Control turns itself off for
good the first time unsigned software is installed, which on a machine used for
programming happens on day one.

## The bindings are ours

The usual way to write a Notepad++ plugin in Pascal is to start from a template
that carries the editor's own headers with it. Those are GPL. Everything here is
written from the published interface (`PluginInterface.h`,
`Notepad_plus_msgs.h`, `Docking.h`), so this repository can be MIT.

Two details cost real time and are worth knowing if you write your own:

- **Word size matters.** `idFrom` in a notification header and Scintilla
  positions are pointer-sized. Older descriptions declare them as `Cardinal` and
  `Integer`, and on x64 that shifts every field after them.
- **Record layout has to match the C compiler.** Delphi gets there with
  `ALIGN ON`; FPC needs `PACKRECORDS C`. Without it `TToolbarData` shifted, and
  Notepad++ read a neighbouring field as a pointer to a name and died without a
  message the first time the panel was shown.

## The reference is generated, not written

The panel has a button that lists the signs and functions of the parser, each
with a description and an example. The content is `web/syntax.xml`, and the
build puts it NEXT TO the library rather than into `ui`: the panel asks the
host for it, because a page opened from a file is not allowed to fetch its
neighbour.

The file is generated from the registry of the parser itself. That is the
point of it: a hand-written list drifts from what the parser accepts, and
the drift is invisible until somebody writes a formula against the list
and gets a refusal. A generated one cannot drift.

It is also where the one real trap is spelled out. `^` is exclusive-or in
this parser, not a power: `x ^ 2` returns a number, just never the one you
meant. Write `x ** 2` for the square.

## The page is shared

`web/index.html` is one file with two hosts: this plugin, and the WebAssembly
build on the site. It is never copied by hand between them - a hand-made copy
fell three edits behind once, and the self test then checked code that was not
published anywhere.

## Licence

MIT. See [LICENSE](LICENSE).
