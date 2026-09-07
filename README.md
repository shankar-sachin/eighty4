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
- MATH: `▶Frac ▶Dec ³ ³√( ˣ√ fMin( fMax( nDeriv( fnInt( Σ( logBASE(` and the numeric **Solver** (eqn:0=, variable list, alpha+ENTER solves), NUM, CMPLX (real-valued), PROB (`rand nPr nCr ! randInt( randNorm( randBin( randIntNoRep(`), FRAC with `Un/d` mixed numbers (`3_1/2`).
- TEST and LOGIC operators, ANGLE (`° ' ʳ ▶DMS R▶Pr( R▶Pθ( P▶Rx( P▶Ry(`), radian/degree modes.
- LIST OPS and MATH (`SortA( SortD( dim( Fill( seq( cumSum( ΔList( augment( min( max( mean( median( sum( prod( stdDev( variance(`).
- MATRIX MATH (`det( ᵀ dim( Fill( identity( randM( augment( Matr▶list( List▶matr( cumSum( ref( rref( rowSwap( row+( *row( *row+(`), inverse, powers, and a spreadsheet-style matrix editor.
- DISTR: `normalpdf normalcdf invNorm invT tpdf tcdf χ²pdf χ²cdf Fpdf Fcdf binompdf binomcdf poissonpdf poissoncdf geometpdf geometcdf`, and DRAW `ShadeNorm( Shade_t( Shadeχ²( ShadeF(` shade the density on the graph screen.
- STAT: list editor for L₁–L₆, CALC with 1-Var Stats, 2-Var Stats, Med-Med, LinReg (both forms), QuadReg, CubicReg, QuartReg, LnReg, ExpReg, PwrReg, Logistic, SinReg. Results land in the VARS Statistics variables and `RegEQ`.
- STAT TESTS: all 17 editors (Z-Test, T-Test, 2-Samp Z/T, 1-Prop/2-Prop Z, the Z/T/prop intervals, χ²-Test, χ²GOF-Test, 2-SampFTest, LinRegTTest, LinRegTInt) with Data/Stats input, Calculate or Draw (shaded p-value), plus `ANOVA(`. Results go to VARS Statistics TEST.
- Strings: `"…"→Str1`, concatenation with `+`, `length( sub( inString( expr(`.
- Commands: `ClrHome ClrDraw ClrAllLists ClrList PlotsOn/Off Degree Radian Float Fix Normal Sci Eng Func Param Polar Seq FnOn FnOff AxesOn/Off Grid… Coord… Label… Expr… ZStandard … ZFrac1/2 StorePic RecallPic StoreGDB RecallGDB BackgroundOn/Off`, and the DRAW commands `Line( Circle( Tangent( Shade( DrawF DrawInv Pt-On( Pt-Off( Pt-Change( Pxl-On( Pxl-Off( Pxl-Change( pxl-Test( Text( Horizontal Vertical`. Pen draws free-hand on the graph.

**Graphing**
- All four MODE graph types: FUNCTION (Y₁–Y₀), PARAM (X₁T/Y₁T…), POLAR (r₁–r₆) and SEQ (u, v, w with nMin and u(nMin), recursive definitions like `u(n−1)+u(n−2)`). The Y= and WINDOW editors change with the mode (Tmin/Tmax/Tstep, θmin…, nMin/nMax/PlotStart/PlotStep).
- Y= editor with function on/off (← onto the `=`), WINDOW editor, FORMAT (grid, axes, labels, coordinates, expression), ZOOM (ZBox, Zoom In/Out, ZDecimal, ZSquare, ZStandard, ZTrig, ZInteger, ZoomStat, ZoomFit, ZQuadrant1, ZFrac1/2 1/3 1/4, ZPrevious, ZoomSto/Rcl, SetFactors).
- GRAPH plots every enabled function in its TI color, plus STAT PLOT scatter / xyLine plots, DRAW objects, pictures and BackgroundOn colors.
- TRACE with ←/→ (steps of Tstep/θstep/PlotStep in the other modes), ↑/↓ to switch functions, or type a value.
- CALC: value, zero, minimum, maximum, intersect, dy/dx, ∫f(x)dx with the real bound / guess prompts.
- TABLE with TBLSET (TblStart, ΔTbl), scrolling in both directions, columns per graph mode.
- VARS: Window (X/Y, T/θ, U/V/W), Zoom, GDB, Picture, Statistics (incl. TEST), Table, String; Y-VARS Function / Parametric / Polar / Sequence / On-Off.

**Everything else on the keypad**
- MODE, FORMAT, TBLSET, STAT PLOT editors that look and navigate like the originals.
- APPS: **GeoDash** (one level, ↑/enter to jump), **Tetris** (←→ move, ↑ rotate, ↓ soft drop, enter hard drop), **Finance** (a working TVM Solver; alpha+ENTER solves the highlighted row), **CabriJr** (points, segments, lines, circles, triangles, distance), **CelSheet** (spreadsheet with A1-style formulas and ranges), **Conics** (graph + center/vertices/foci/eccentricity), **Inequalz** (Y= relations shaded on the graph), **PlySmlt2** (polynomial roots incl. complex, simultaneous equations), **Prob Sim** (coins, dice, marbles, spinner, cards, random numbers), **SciTools** (sig-fig calculator, unit converter, data wizard, vector calculator), **Transfrm** (Y₁ with live A B C D sliders) and **Vernier EasyData** (sensor front-end; reports no sensor without hardware).
- PRGM: EXEC runs the two games and your TI-BASIC programs, EDIT opens the program editor (PRGM key inside it shows the CTL / I/O / EXEC menus), NEW creates one. The interpreter handles `Disp Input Prompt Output( ClrHome Pause If/Then/Else For( While Repeat End Lbl Goto Menu( IS>( DS<( Return Stop DelVar DispGraph DispTable getKey prgmNAME` and every expression/command the home screen accepts. Errors offer 2:Goto into the editor.
- MEM: About, Mem Management/Delete by category (DEL deletes, ENTER archives), Clear Entries, Archive/UnArchive, Reset (RAM, defaults, ARCHIVE vars/apps/both with the 1:No 2:Reset screens), Group/Ungroup, Garbage Collect. LINK shows the send/receive flow. CATALOG lists every token, alphabetically, with letter jumps.
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
| `-demo solver`, `param`, `polar`, `seq`, `seqyeq`, `zbox`, `shade` | Solver, graph modes, ZBox, ShadeNorm |
| `-demo ztest`, `ztestedit`, `ztestdraw` | STAT TESTS editor, results and DRAW |
| `-demo prgm`, `prgmedit`, `mem` | Program run / editor, MEM management |
| `-demo plysmlt`, `conics`, `probsim`, `celsheet` | The new apps |
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
  Engine/              Tokenizer → Parser → Functions / Stats / StatTests / Sequences / Solver / Programs (TI-BASIC), VariableStore
  State/               Screens, Menus, Editors, Graphing, CalculatorState, KeyHandler
  Apps/                Game protocol + AppKit helpers, GeoDash, Tetris, CabriJr, CelSheet, Conics, Inequalz, PlySmlt2, ProbSim, SciTools, Transfrm, Vernier
  Views/               Layout (0.1 mm design units), body, keypad, LCD, graph renderer and screen views
Eighty4Tests/          engine + key-flow unit tests
assets/logo.png        source logo (app icon + wordmark badge)
```

## Version history

- **0.3.0** — Nothing says "not available" any more: MATH Solver, Un/d, DISTR DRAW shading, Fill/Matr▶list/List▶matr/row ops, GDB/Pic/String variables, PARAM/POLAR/SEQ graphing with matching Y=/WINDOW/TABLE, all STAT TESTS + ANOVA + Logistic/SinReg, DRAW Tangent/Shade/DrawInv/Pen/pixel ops/StorePic/BackgroundOn, ZBox/ZFrac/SetFactors, MEM archive/groups/garbage collect/reset archive with confirm screens, a TI-BASIC program editor + interpreter, and nine more apps (CabriJr, CelSheet, Conics, Inequalz, PlySmlt2, Prob Sim, SciTools, Transfrm, Vernier).
- **0.2.0** — Every 2nd function and menu key works: menus, MODE/FORMAT/WINDOW/TBLSET/STAT PLOT editors, Y= and graphing with TRACE / CALC / TABLE / ZOOM, lists, matrices and their editors, stats and regressions, distributions, TVM solver, CATALOG, MEM, LINK, GeoDash and Tetris apps, shell color button, LCD fills the bezel, ENTER works under 2nd/alpha, history recall on ↑/↓.
- **0.1.0** — Faithful body and keypad, home-screen arithmetic, shell colorways.
