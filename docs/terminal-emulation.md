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
