# Eighty4

A TI-84 Plus CE replica for iPhone, built in SwiftUI. No ROM, no emulation: the body, keypad, 320×240 display, home-screen math engine, menus, graphing, and a couple of built-in games are all reimplemented from scratch so the app can ship on its own.

> Eighty4 is an independent project and is not affiliated with or endorsed by Texas Instruments. "TI-84 Plus CE" is a trademark of Texas Instruments.

## Features

**Hardware look**
- Body drawn at real proportions (86.9 × 190.5 mm design grid) with the glossy bezel, side USB-C port and charge LED.
- Full 10×5 keypad with the blue 2nd and green alpha overlays on every key, white digit keys, charcoal function keys, and a round D-pad with wedge-shaped hit regions.
- Six official shell colorways: Black, Radical Red, Rose Gold, Galaxy Gray, Trinomial Teal, Bionic Blue. Tap the palette button above the calculator, or long-press the wordmark.
- Haptic key presses.

**Home screen**
- 26-column × 10-line display with the status bar, battery, blinking cursor, 2nd (↑) and alpha (A) indicators, INS underline cursor.
- TI-style results: 10 significant digits, `.5` without a leading zero, `⁻` negation glyph, `ᴇ` exponent notation, NORMAL / SCI / ENG and FLOAT / FIX 0–9 from the MODE screen.
- ↑ / ↓ scroll through previous entries, 2nd+ENTRY recalls the last one, 2nd+RCL pastes a variable's value.
- Errors show the real `ERR:` screen with 1:Quit / 2:Goto.

**Math engine**
- Reals, fractions (`▶Frac`), lists (`{1,2,3}`, L₁–L₆), and matrices (`[[1,2][3,4]]`, [A]–[J]) with TI precedence, implicit multiplication, and `→` store into A–Z, θ, lists, matrices, and Y-vars.
- MATH: `▶Frac ▶Dec ³ ³√( ˣ√ fMin( fMax( nDeriv( fnInt( Σ( logBASE(`, NUM, CMPLX (real-valued), PROB (`rand nPr nCr ! randInt( randNorm( randBin( randIntNoRep(`), FRAC.
- TEST and LOGIC operators, ANGLE (`° ' ʳ ▶DMS R▶Pr( R▶Pθ( P▶Rx( P▶Ry(`), radian/degree modes.
- LIST OPS and MATH (`SortA( SortD( dim( seq( cumSum( ΔList( augment( min( max( mean( median( sum( prod( stdDev( variance(`).
- MATRIX MATH (`det( ᵀ dim( identity( randM( augment( cumSum( ref( rref(`), inverse, powers, and a spreadsheet-style matrix editor.
- DISTR: `normalpdf normalcdf invNorm invT tpdf tcdf χ²pdf χ²cdf Fpdf Fcdf binompdf binomcdf poissonpdf poissoncdf geometpdf geometcdf`.
- STAT: list editor for L₁–L₆, and CALC with 1-Var Stats, 2-Var Stats, LinReg (both forms), QuadReg, CubicReg, QuartReg, LnReg, ExpReg, PwrReg. Results land in the VARS Statistics variables and `RegEQ`.
- Commands: `ClrHome ClrDraw ClrAllLists ClrList PlotsOn/Off Degree Radian Float Fix Normal Sci Eng FnOn FnOff AxesOn/Off Grid… Coord… Label… Expr… ZStandard …` and the DRAW commands `Line( Circle( Pt-On( Text( Horizontal Vertical DrawF`.

**Graphing**
- Y= editor for Y₁–Y₀ with function on/off, WINDOW editor, FORMAT (grid, axes, labels, coordinates, expression), ZOOM (Zoom In/Out, ZDecimal, ZSquare, ZStandard, ZTrig, ZInteger, ZoomStat, ZoomFit, ZQuadrant1, ZPrevious, ZoomSto/Rcl).
- GRAPH plots every enabled function in its TI color, plus STAT PLOT scatter / xyLine plots and DRAW objects.
- TRACE with ←/→, ↑/↓ to switch functions, or type an X value.
- CALC: value, zero, minimum, maximum, intersect, dy/dx, ∫f(x)dx with the real bound / guess prompts.
- TABLE with TBLSET (TblStart, ΔTbl), scrolling in both directions.

**Everything else on the keypad**
- MODE, FORMAT, TBLSET, STAT PLOT editors that look and navigate like the originals.
- APPS: **GeoDash** (one level, ↑/enter to jump), **Tetris** (←→ move, ↑ rotate, ↓ soft drop, enter hard drop), and **Finance** (a working TVM Solver; alpha+ENTER solves the highlighted row).
- PRGM EXEC runs the two games. MEM has About, memory management, Clear Entries, and Reset. LINK shows the send/receive flow. CATALOG lists every token, alphabetically, with letter jumps.
- 2nd+OFF turns the screen off; ON turns it back on.

## Building

Requirements: Xcode 26, [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate          # creates Eighty4.xcodeproj from project.yml (the xcodeproj is gitignored)
open Eighty4.xcodeproj     # pick an iPhone simulator and run
```

From the command line:

```sh
xcodebuild -project Eighty4.xcodeproj -scheme Eighty4 \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
xcodebuild -project Eighty4.xcodeproj -scheme Eighty4 \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test
```

### Demo launch arguments

Useful for screenshots. `-demo` wipes saved memory first.

| Argument | What it shows |
|---|---|
| `-demo home` | Home screen with worked history |
| `-demo math`, `mode`, `window`, `catalog` | Menus and editors |
| `-demo yeq`, `graph`, `trace`, `calc`, `table` | Graphing flow for Y₁=X²−4, Y₂=2X+1 |
| `-demo matrix`, `matrixcalc`, `stat`, `statcalc` | Matrix and list editors, LinReg |
| `-demo geodash`, `tetris`, `tvm` | Apps |
| `-shell radicalRed` | Force a shell colorway (any `ShellColor` raw value) |

Example:

```sh
xcrun simctl launch booted com.sachi.eighty4 -demo graph -shell bionicBlue
```

## Project layout

```
project.yml            xcodegen spec (targets, version, Info.plist keys)
Eighty4/
  Eighty4App.swift     entry point + demo scripts
  Models/              KeySpec, Keymap (all 50 keys with 2nd/alpha labels), Shell colors
  Engine/              Tokenizer → Parser → Functions / Stats / Value / Formatter, VariableStore
  State/               Screens, Menus, Editors, Graphing, CalculatorState, KeyHandler
  Apps/                Game protocol, GeoDash, Tetris
  Views/               Layout (0.1 mm design units), body, keypad, LCD and screen views
Eighty4Tests/          engine + key-flow unit tests
assets/logo.png        source logo (app icon + wordmark badge)
```

## Version history

- **0.2.0** — Every 2nd function and menu key works: menus, MODE/FORMAT/WINDOW/TBLSET/STAT PLOT editors, Y= and graphing with TRACE / CALC / TABLE / ZOOM, lists, matrices and their editors, stats and regressions, distributions, TVM solver, CATALOG, MEM, LINK, GeoDash and Tetris apps, shell color button, LCD fills the bezel, ENTER works under 2nd/alpha, history recall on ↑/↓.
- **0.1.0** — Faithful body and keypad, home-screen arithmetic, shell colorways.
