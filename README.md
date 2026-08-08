# GraphBuilder - plotting inside Notepad++

A docked panel that plots the formula under your mouse. Press Alt+G to open it,
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
as the [live demo](https://pisarev.github.io/mathparser-live/demo/) in a browser,
with the engine compiled to WebAssembly instead of the plugin behind it.

## What is in here

| | |
|---|---|
| `src/` | the plugin: the panel, the bridge to the page, the report, the theme, the icons |
| `bindings/` | our own Notepad++ bindings - written from the published ABI, no third-party code |
| `web/index.html` | the panel itself. The same file is published as the site demo |
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
| needs | Delphi | Lazarus, FPC, and a WebView4Delphi checkout |

**The binary attached to a release is the Lazarus one.** Both builds work; the
FPC build is what ships because it is made with a free toolchain, so anyone can
reproduce it without a Delphi licence.

WebView4Delphi is not vendored here - it is a third-party library under its own
licence. Point `WEBVIEW4DELPHI` at a checkout of it before building the Lazarus
version.

## Building and installing

The build that ships is the Lazarus one:

```
pwsh -File build-lazarus.ps1
pwsh -File install.ps1
```

The Delphi build is kept for comparison and needs a switch on both steps, since
it produces a differently named library:

```
pwsh -File build.ps1
pwsh -File install.ps1 -Delphi
```

Only x64 is built. Notepad++ ships 32-bit and ARM64 editions as well, and
neither is supported here - the plugin needs a 64-bit editor. Installing needs
administrator rights and a closed editor: Notepad++ holds the library open while
it runs, and a copy over a running editor fails silently, leaving the previous
version in place. `install.ps1` refuses to do that and says so.

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

## The page is shared

`web/index.html` is one file with two hosts: this plugin, and the WebAssembly
build on the site. It is never copied by hand between them - a hand-made copy
fell three edits behind once, and the self test then checked code that was not
published anywhere.

## Licence

MIT. See [LICENSE](LICENSE).
