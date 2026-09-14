# Aegir terminal: escape-code emulation (design decision)

**Status: decided, not yet implemented.**  This records what the Aegir terminal targets and what it
therefore owes programs that write escape sequences.  It exists because the Oberon `Term` library speaks
ANSI while `userspace/terminal/terminal.adb` handles no escape sequences at all - so today a program
calling `Term.SetColor` prints raw escapes.

## Decision

**The terminal targets VT100/xterm compatibility**, with a documented core it must always honour.  A
narrower subset was considered and rejected: it would need extending anyway the first time real TUI code
runs, and the extra sequences are cheap once a CSI parser and a cursor model exist.

`TERM` is advertised as `xterm` (or `xterm-256color`, given the colour model below) so programs can
feature-detect instead of guessing.

## The core that must be guaranteed

Everything the Oberon `Term` library emits - it is the first real client, and the corpus depends on it:

| `Term` call | sequence | meaning |
|---|---|---|
| `Reset` / `Invert` | `ESC[0m` / `ESC[7m` | SGR reset / reverse video |
| `SetColor(fg, bg)` | `ESC[38;5;<fg>mESC[48;5;<bg>m` | 256-colour fg / bg |
| `Clear` / `ClearLine` | `ESC[2J` / `ESC[2K` | erase display / erase line |
| `SetCursor(x, y)` | `ESC[<y+1>;<x+1>H` | CUP, 1-based |
| `CursorUp/Down/Right/Left(n)` | `ESC[<n>A` `B` `C` `D` | CUU / CUD / CUF / CUB |

Plus the controls every terminal has: `BS` (0x08), `HT` (0x09), `LF` (0x0A), `CR` (0x0D), and `BEL` if a
bell exists.

Beyond that core, the VT100/xterm surface this decision commits to: DEC private modes (`ESC[?nh/l` - at
least cursor visibility and alternate screen), scroll regions (`DECSTBM`), save/restore cursor (`ESC[s` /
`ESC[u`), and the `ESC[<n>m` SGR attributes that go with them (bold, underline, reverse).

**Anything outside the documented set is DEFINED, not undefined**: ignored as an unknown CSI, and counted
so a test can assert that an unsupported sequence was *recognised as unsupported* rather than misparsed.
An escape swallow must never be able to eat a following character it did not claim.

## Colour model

256-colour: 0-15 basic/bright, 16-231 the 6x6x6 cube, 232-255 greys.  `Term.SetColor (fg, bg: integer)`
takes `0 .. 255`; values outside are **clamped**, because the parameters are runtime integers and a
malformed sequence (`ESC[310m`) is worse than a wrong colour.

The previous single-digit form (`ESC[3<fg>m`) is gone rather than kept alongside: no terminal exists yet
to be compatible with, and `ESC[38;5;nm` covers it.

## Term <-> Terminal integration (later)

Two pieces, deliberately separable, and the reason this is a unit of work rather than a patch:

1. **A CSI parser**, ideally a pure function over a byte stream - so the tests need no GUI, no screen, and
   no timing.  Given the emulator's history here (pointer coords scaled by a stale screen size, M92), a
   parser that is testable in isolation is worth more than one that is fast to write.
2. **The screen model it drives** - cursor, attributes, the grid, and scrolling.

The `Term` side is done first (this decision): it emits exactly the table above, and
`tests/bc/termuse.ob2` in the o2c tree pins the bytes.

## The renderer unit, and why it is not just swapping the source

`Render` is already cell-oriented - it draws `Draw_Glyph` per cell, deliberately ("draw cell by cell so
the band and the cursor can recolor individual glyphs with one code path"), so reading the grid instead of
a scrollback line is small.  But it is NOT a one-line swap, and the reason is worth writing down before
anyone starts.

* **`Render` draws the SCROLLBACK**, and the terminal's prompt and typed line are there.  The prompt is not
  program output: it arrives through the terminal's own ECHO path - `Input_Put` and `Terminal_Buffer.Put_Char`
  from the line editor - while `Op_Write` (program output) is the only thing feeding the grid.  Draw the
  grid alone and the prompt and the typed line disappear.
* **The block cursor is the EDITOR's**, drawn at `Terminal_Buffer.Current_Line/Current_Col` with a correction
  from `Edit_Caret`/`Edit_Len`.  The grid has its own cursor.  A live terminal wants one cursor, and the
  two are not the same thing: the grid's is where the emulation is writing, the editor's is where the user
  is typing - which are the same place only when the shell owns the line.
* **It is only verifiable visually.**  "The grid is drawn" is not a log line, so this unit needs a
  screendump over QMP, and the pointer/scale lesson from M92 applies to any interaction after it.

So the unit is: route the echo through `Terminal_Emul.Feed` as well, decide the cursor question honestly
(one cursor, or two modes), draw `Cell_At` when the view is live and the scrollback when it is scrolled -
and check it with a screendump.  It is a unit with a plan, not a patch, which is why it has not been done
at the tail of a long run.

## Status

Landed, in order: the parser (`terminal_csi`), the screen model (`terminal_screen`), the driver
(`terminal_emul`), the seam measurement, and the wiring at `Op_Write`.  Colour is 256 (`Term.SetColor`
emits `ESC[38;5;nm` / `ESC[48;5;nm`), which is the side of this that lives in the o2c tree.

**Verified:** 55 host checks across the three platform-free units (one project, `run.sh`, no boot, no GUI,
no timing) - and, since they now compile into the terminal, a clean guest build of all four units with no
warnings, plus a boot: `PASS terminal surface ok`, `terminal online`, `terminal spawned shell`,
`shell online`, and no FAIL, panic or trap in the log.

**One visible fix has landed already**: the scrollback no longer receives raw bytes.  Every byte of program
output used to go to it, so `Term.SetColor` printed its own escape as literal text - the garbage this note
opened with.  `Feed` now reports what a TEXT consumer should get (a printable, a control the history keeps,
or NUL for anything that is part of a sequence) and `Op_Write` appends only that.  Re-booted: `PASS terminal
surface ok`, `terminal online`, `shell online`, no FAIL.

**The renderer draws the grid.**  `Render` takes the source of a cell from `Cell_At` when the view is at
the bottom and from the scrollback when it is scrolled back - one drawing loop, one place where the two
views differ, so the band, the cursor and the font fallback do not fork.  The cursor needed no change at
all: it already maps to a screen row (`Cur_Line - Top`).  Verified with a screendump: the Terminal window
shows the shell's banner, the prompt and the block cursor.

**COLOUR is in.**  `Terminal_Palette` holds the 256 entries as DATA - pure, host-tested, the xterm values:
16 basic and bright, a 6x6x6 cube, then greys - and the guest folds three bytes into a Pixel.  The renderer
now fills a cell's background from its index, draws its glyph in its foreground, and swaps the two when the
cell is reverse.  A space means "no index", which is what keeps a default distinct from colour 0 - the same
distinction `Attr = -1` makes in the parser.

Verified to the boot: prompt, banner and block cursor unchanged, so defaults still render as defaults.
NOT yet verified positively: nothing on the boot emits SGR, so no screenshot shows a colour yet.  That
needs a program that writes escapes running on the guest - the o2c tree's `tests/bc/termuse.ob2` is exactly
such a program, and running the bytecode VM on Aegir with it is the follow-up.  That is deliberate - it made the image
change landable on a boot that could only show a regression - and it is the next unit: draw `Cell_At`
instead of `Get_Line`, with the band flush staying where it is, at the top of the loop after the reply.
Attributes reach the cells already, so colour follows from the same change.

## Where the wiring goes (measured, not assumed)

Worth writing down because the obvious answer is wrong.  `Terminal_Buffer.Put_Char` is NOT the output path:
its four callers in `terminal.adb` are the EDIT and ECHO paths - `Caret_Insert`, the line editor's
newline, and two backspaces.  Program output does not go through it at all.

The terminal is a STREAM SINK DEVICE (milestone 31).  It creates a sink endpoint, attaches it at the
console server, and its service loop handles:

* **`Op_Write` - renders text.  THIS is the seam**: each byte of program output becomes
  `Terminal_Emul.Feed` (the grid) and `Terminal_Buffer.Put_Char` (the scrollback).  Both, because a
  terminal keeps both - the grid is what is on screen, the scrollback is the history behind it.
* `Op_Input` - queues focused keys and echoes them into the scrollback.
* `Op_Read` - drains the input FIFO.

Two constraints that fall out of it, both from rules this project already has:

1. **`Feed` must stay synchronous and cheap.**  It is called while serving a caller, and the service loop's
   own comment states the rule: never call your caller while serving them (docs/IPC.md).  The emulation
   does no IPC, allocates nothing and touches no other endpoint - which is exactly why the seam is safe.
2. **The renderer draws the grid, and the band flush stays where it is** - at the TOP of the loop, after
   the reply.  Nothing about the emulation changes that ordering; it only changes what is drawn.

## Consequence today

`Term.GetSize` is a stub returning 80x25, so **no bidirectional protocol is required yet** - the terminal
never has to answer.  If that changes, a cursor-position report is `ESC[<row>;<col>R` and the terminal
must not interpret its own reply as input.  Until then the emulation is strictly output-only, which is a
much smaller thing to get right.
