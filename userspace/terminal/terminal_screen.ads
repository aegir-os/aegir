--  The terminal's SCREEN: a random-access grid with a cursor, attributes, erase
--  and scrolling - what the CSI parser's actions drive.
--
--  Why this is not Terminal_Buffer: that is a SCROLLBACK, and its cursor only
--  ever sits at the end of the last line (Current_Line is Count - 1).  CUP, CUU
--  and CUD need a cursor that can be anywhere, so a terminal needs both, which is
--  what real ones have - a grid you move in, and a history behind it.  Keeping
--  them separate also keeps the scrollback's existing semantics untouched.
--
--  Platform-free like Terminal_CSI, and for the same reason: it is exercised on
--  the host, with no boot, no screen and no timing.
package Terminal_Screen is

   --  A screen is a bounded thing, so these are a SIZING argument rather than a
   --  policy: 200x64 is larger than any terminal this runs on, and the storage is
   --  a package-level array - never on the stack, which the guest has 256 KiB of.
   Max_Cols : constant := 200;
   Max_Rows : constant := 64;

   type Cell is record
      Ch  : Character := ' ';
      --  A 256-colour index as a raw byte, or a space for "default".  Keeping
      --  the default distinct from any index is what lets a renderer inherit.
      Fg  : Character := ' ';
      Bg  : Character := ' ';
      Rev : Boolean := False;
   end record;

   procedure Init (Cols, Rows : Natural);
   procedure Clear;

   --  Text, at the cursor, advancing.  A printable that runs past the last column
   --  wraps; running past the last row scrolls.
   procedure Put (Ch : Character);
   procedure New_Line;             --  LF
   procedure Carriage_Return;      --  CR
   procedure Backspace;            --  BS
   procedure Tab;                  --  HT

   --  0-based, and CLAMPED: a sequence naming a cell off the screen is bounded by
   --  it rather than wrapping into a different one.
   procedure Set_Cursor (Row, Col : Natural);
   procedure Move (D_Col, D_Row : Integer);

   --  Mode 0 = cursor to end, 1 = start to cursor, 2 = all.
   procedure Erase_Line (Mode : Natural);
   procedure Erase_Display (Mode : Natural);

   procedure Set_Attr (Attr : Natural);        --  SGR: 0 reset, 7 reverse
   procedure Set_Fg (Index : Natural);         --  SGR 38;5;n
   procedure Set_Bg (Index : Natural);         --  SGR 48;5;n

   function Cols return Natural;
   function Rows return Natural;
   function Cursor_Row return Natural;
   function Cursor_Col return Natural;
   function Cell_At (Row, Col : Natural) return Cell;

end Terminal_Screen;
