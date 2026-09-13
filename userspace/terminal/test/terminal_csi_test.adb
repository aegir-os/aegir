with Ada.Text_IO;         use Ada.Text_IO;
with Terminal_CSI;         use Terminal_CSI;

--  Host test for the CSI parser.  No guest, no screen, no clock - the parser is
--  platform-free precisely so this can exist (docs/terminal-emulation.md).
--
--  The list is the GUARANTEED CORE from the design note, which is also exactly
--  what the Oberon Term library emits, plus the two properties the note insists
--  on: an unsupported sequence is COUNTED (not misread), and a sequence can never
--  swallow a byte it did not claim.
procedure Terminal_CSI_Test is
   Pass : Natural := 0;
   Fail : Natural := 0;

   procedure Check (Cond : Boolean; What : String) is
   begin
      if Cond then
         Pass := Pass + 1;
      else
         Fail := Fail + 1;
         Put_Line ("FAIL: " & What);
      end if;
   end Check;

   procedure Feed (S : String) is
      A : Terminal_CSI.Action;
   begin
      for I in S'Range loop
         Terminal_CSI.Feed (S (I), A);
      end loop;
   end Feed;

   --  Feed a sequence and return only the action its FINAL byte produced.
   function Try (S : String) return Terminal_CSI.Action is
      A : Terminal_CSI.Action;
   begin
      Terminal_CSI.Reset;
      for I in S'Range loop
         Terminal_CSI.Feed (S (I), A);
      end loop;
      return A;
   end Try;

   ESC : constant Character := ASCII.ESC;

   A : Terminal_CSI.Action;

begin
   --  ---- SGR: the two attributes Term uses, and 256-colour, which it now does
   A := Try (ESC & "[0m");
   Check (A.K = Terminal_CSI.SGR and then A.Attr = 0, "ESC[0m is SGR reset");

   A := Try (ESC & "[7m");
   Check (A.K = Terminal_CSI.SGR and then A.Attr = 7, "ESC[7m is reverse");

   A := Try (ESC & "[38;5;2m");
   Check (A.K = Terminal_CSI.SGR and then A.Fg = 2 and then A.Bg = -1,
          "ESC[38;5;2m sets fg=2, leaves bg");

   A := Try (ESC & "[48;5;0m");
   Check (A.K = Terminal_CSI.SGR and then A.Bg = 0 and then A.Fg = -1,
          "ESC[48;5;0m sets bg=0, leaves fg");

   A := Try (ESC & "[38;5;200m");
   Check (A.K = Terminal_CSI.SGR and then A.Fg = 200, "ESC[38;5;200m (cube)");

   --  ---- erase
   A := Try (ESC & "[2J");
   Check (A.K = Terminal_CSI.Erase_Display and then A.N = 2, "ESC[2J erase");

   A := Try (ESC & "[2K");
   Check (A.K = Terminal_CSI.Erase_Line and then A.N = 2, "ESC[2K erase line");

   --  ---- cursor moves, including the ANSI default of 1
   A := Try (ESC & "[3A");
   Check (A.K = Terminal_CSI.Cursor_Up and then A.N = 3, "ESC[3A up 3");

   A := Try (ESC & "[B");
   Check (A.K = Terminal_CSI.Cursor_Down and then A.N = 1,
          "ESC[B down 1 (default)");

   A := Try (ESC & "[2C");
   Check (A.K = Terminal_CSI.Cursor_Right and then A.N = 2, "ESC[2C right 2");

   A := Try (ESC & "[4D");
   Check (A.K = Terminal_CSI.Cursor_Left and then A.N = 4, "ESC[4D left 4");

   --  ---- CUP, which Term sends 1-based and the screen wants 0-based
   A := Try (ESC & "[5;10H");
   Check (A.K = Terminal_CSI.Cursor_Pos and then A.Row = 4 and then A.Col = 9,
          "ESC[5;10H is row 4 col 9");

   A := Try (ESC & "[H");
   Check (A.K = Terminal_CSI.Cursor_Pos and then A.Row = 0 and then A.Col = 0,
          "ESC[H is home");

   --  ---- printable and control bytes pass through
   A := Try ("x");
   Check (A.K = Terminal_CSI.Print and then A.Ch = 'x', "printable passes");

   A := Try (ESC & "[1m" & "y");
   Check (A.K = Terminal_CSI.Print and then A.Ch = 'y',
          "a byte after a sequence is still printed");

   A := Try ("" & ASCII.LF);
   Check (A.K = Terminal_CSI.Control and then A.Ch = ASCII.LF, "LF passes");

   --  ---- unsupported is COUNTED, and never swallows the next character
   declare
      Before : constant Natural := Terminal_CSI.Unsupported;
   begin
      A := Try (ESC & "[9999q");
      Check (A.K = Terminal_CSI.Unknown, "an unknown CSI is Unknown");
      Check (Terminal_CSI.Unsupported = Before + 1,
             "an unknown CSI is counted");

      A := Try (ESC & "[9X" & "q");
      Check (A.K = Terminal_CSI.Print and then A.Ch = 'q',
             "a sequence never swallows the byte after its final byte");

      A := Try (ESC & "Z");
      Check (A.K = Terminal_CSI.Unknown,
             "a non-CSI escape is Unknown, not a misread");
   end;

   Put_Line ("csi parser: " & Natural'Image (Pass) & " passed,"
             & Natural'Image (Fail) & " failed");
   if Fail /= 0 then
      raise Program_Error with "CSI parser tests failed";
   end if;
end Terminal_CSI_Test;
