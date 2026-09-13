--  CSI (escape sequence) parser for the terminal: docs/terminal-emulation.md.
--
--  DELIBERATELY PLATFORM-FREE.  It uses nothing but Ada itself - no aegir
--  runtime, no VAs, no screen, no clock - for two reasons.  It compiles into the
--  guest terminal like any other unit, AND it can be exercised on the host with
--  a plain gprbuild, which is what the design note asks for: the parser's tests
--  need no boot, no GUI and no timing.  The emulator has been bitten before by
--  state (a cached screen size scaling every pointer coordinate, M92), and a
--  parser that can be driven by hand is worth more than one that cannot.
--
--  The shape is a STREAM: Feed one byte, get at most one action.  Intermediate
--  bytes of a sequence return Kind => None, so a caller that only acts on
--  non-None needs no state of its own.  Anything outside the documented set is
--  counted as Unknown rather than guessed at, and a malformed sequence can never
--  swallow a byte it did not claim.
package Terminal_CSI is

   --  The most parameters a single sequence may carry.  A WIRE FORMAT limit, not
   --  a policy one: a CSI parameter list this long does not occur in the set the
   --  terminal promises, and the excess is reported as Unknown rather than
   --  silently truncated into a different action.
   Max_Params : constant := 8;

   type Kind is (None,          --  an intermediate byte of a sequence
                 Print,         --  an ordinary printable character
                 Control,       --  BS / HT / LF / CR / BEL, passed through
                 SGR,           --  select graphic rendition
                 Cursor_Up, Cursor_Down, Cursor_Right, Cursor_Left,
                 Cursor_Pos,    --  CUP, 0-based here
                 Erase_Display, Erase_Line,
                 Unknown);      --  recognised as a sequence, not supported

   type Action is record
      K      : Kind    := None;
      Ch     : Character := ' ';    --  Print, Control
      Attr   : Natural := 0;        --  SGR: an attribute (0 reset, 7 reverse)
      Fg, Bg : Integer := -1;       --  SGR: 256-colour index, -1 = unchanged
      N      : Natural := 0;        --  Cursor_*: count; Erase_*: mode
      Row    : Natural := 0;        --  Cursor_Pos, 0-based
      Col    : Natural := 0;
   end record;

   --  Back to the ground state.  Not called between records; the parser holds
   --  only the sequence it is in the middle of.
   procedure Reset;

   procedure Feed (B : Character; A : out Action);

   --  How many sequences have been recognised as sequences but not supported.
   --  The design note makes "ignored" a DEFINED outcome, and this is what makes
   --  it assertable: a test can say a sequence was refused rather than misread.
   function Unsupported return Natural;

end Terminal_CSI;
