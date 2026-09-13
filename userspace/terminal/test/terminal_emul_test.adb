--  Host test for the emulation driver: BYTES IN, GRID STATE OUT.
--
--  The bytes are the ones the Oberon Term library actually emits - the golden
--  stream from the o2c tree's tests/bc/termuse.ob2 is the SetColor case - so this
--  is the whole emulation exercised end to end without a guest, a screen or a
--  clock: Feed, then read the cells a renderer would draw.
with Ada.Text_IO;
with Terminal_Emul;       use Terminal_Emul;
with Terminal_Screen;

procedure Terminal_Emul_Test is
   Pass : Natural := 0;
   Fail : Natural := 0;
   ESC  : constant Character := ASCII.ESC;

   procedure Check (Cond : Boolean; What : String) is
   begin
      if Cond then
         Pass := Pass + 1;
      else
         Fail := Fail + 1;
         Ada.Text_IO.Put_Line ("FAIL: " & What);
      end if;
   end Check;

   procedure Feed (S : String) is
   begin
      for I in S'Range loop
         Terminal_Emul.Feed (S (I));
      end loop;
   end Feed;

begin
   Init (40, 10);

   --  Term.Reset
   Feed (ESC & "[0m");

   --  Term.SetColor (2, 0) - the termuse.ob2 bytes - then two characters.
   Feed (ESC & "[38;5;2m");
   Feed (ESC & "[48;5;0m");
   Feed ("ok");

   Check (Cell_At (0, 0).Ch = 'o' and then Cell_At (0, 1).Ch = 'k',
          "text after SetColor lands at the cursor");
   Check (Cell_At (0, 0).Fg = Character'Val (2),
          "and the cell carries the foreground Term asked for");
   Check (Cell_At (0, 0).Bg = Character'Val (0),
          "and the background");
   Check (Cursor_Col = 2, "the cursor advanced over it");

   --  Term.SetCursor (5, 2) emits ESC[3;6H, 1-based.
   Feed (ESC & "[3;6H");
   Feed ("Z");
   Check (Cell_At (2, 5).Ch = 'Z', "CUP lands where Term means it to");

   --  Term.Reset drops the attributes for what is written NEXT.
   Feed (ESC & "[0m");
   Feed ("n");
   Check (Cell_At (2, 6).Fg = ' ', "Reset returns the writing colour to default");
   Check (Cell_At (2, 5).Fg = Character'Val (2),
          "and leaves the cells already drawn alone");

   --  Term.CursorUp (n) emits ESC[nA.  The cursor is anchored to column 0 first:
   --  a column counted from the previous writes is a column miscounted, and this
   --  test got it wrong twice before the checks were written this way.
   Feed (ESC & "[3;1H");
   Feed (ESC & "[2A");
   Feed ("U");
   Check (Cell_At (0, 0).Ch = 'U', "CUU moves up by the count");

   --  Term.CursorUp (99) is beyond the screen: clamped, not wrapped.
   Feed (ESC & "[2;1H");
   Feed (ESC & "[99A");
   Feed ("H");
   Check (Cell_At (0, 0).Ch = 'H', "a move past the top stays on the top row");

   --  Term.ClearLine emits ESC[2K.
   Feed (ESC & "[2K");
   Check (Cell_At (0, 0).Ch = ' ', "EL 2 clears the cursor's line");

   --  Term.Clear emits ESC[2J.
   Feed (ESC & "[2J");
   Check (Cell_At (0, 0).Ch = ' ' and then Cell_At (2, 5).Ch = ' ',
          "ED 2 clears the screen behind it");

   --  An unsupported sequence is ignored AND counted, and does not eat the next
   --  character - which is the property the design note insists on.
   declare
      Before : constant Natural := Unsupported;
   begin
      Feed (ESC & "[1;2;3;4q");
      Feed ("!");
      Check (Unsupported = Before + 1, "an unsupported sequence is counted");
      Check (Cell_At (Cursor_Row, Cursor_Col - 1).Ch = '!',
             "and never swallows the character after it");
   end;

   Ada.Text_IO.Put_Line ("emul: " & Natural'Image (Pass) & " passed,"
                         & Natural'Image (Fail) & " failed");
   if Fail /= 0 then
      raise Program_Error with "emulation tests failed";
   end if;
end Terminal_Emul_Test;
