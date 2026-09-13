--  Text_IO is NOT 'use'd: it exports Put and New_Line too, and the screen's
--  are the ones under test here.
with Ada.Text_IO;
with Terminal_Screen;     use Terminal_Screen;

--  Host test for the screen model, beside the parser's.  Same reasoning: it is
--  platform-free, so the checks need no boot, no screen and no timing.
procedure Terminal_Screen_Test is
   Pass : Natural := 0;
   Fail : Natural := 0;

   procedure Check (Cond : Boolean; What : String) is
   begin
      if Cond then
         Pass := Pass + 1;
      else
         Fail := Fail + 1;
         Ada.Text_IO.Put_Line ("FAIL: " & What);
      end if;
   end Check;

   procedure Puts (S : String) is
   begin
      for I in S'Range loop
         Put (S (I));
      end loop;
   end Puts;

begin
   Init (10, 5);
   Check (Cols = 10 and then Rows = 5, "init sizes");
   Check (Cursor_Row = 0 and then Cursor_Col = 0, "init cursor at home");

   Puts ("abc");
   Check (Cell_At (0, 0).Ch = 'a' and then Cell_At (0, 2).Ch = 'c',
          "text lands at the cursor");
   Check (Cursor_Col = 3, "cursor advanced");

   Carriage_Return;
   Check (Cursor_Col = 0, "CR returns to column 0");

   New_Line;
   Check (Cursor_Row = 1, "LF descends");

   --  ---- clamping, in both directions
   Set_Cursor (2, 3);
   Check (Cursor_Row = 2 and then Cursor_Col = 3, "Set_Cursor");

   Set_Cursor (99, 99);
   Check (Cursor_Row = 4 and then Cursor_Col = 9,
          "a cursor off the screen is clamped onto it");

   Move (-9, -9);
   Check (Cursor_Row = 0 and then Cursor_Col = 0, "moves clamp at home");

   Move (99, 99);
   Check (Cursor_Row = 4 and then Cursor_Col = 9, "moves clamp at the end");

   --  ---- erase
   Set_Cursor (1, 0);
   Puts ("hello");
   Erase_Line (2);
   Check (Cell_At (1, 0).Ch = ' ', "EL 2 clears the whole line");
   Check (Cell_At (0, 0).Ch = 'a', "EL leaves other lines alone");

   Erase_Display (2);
   Check (Cell_At (0, 0).Ch = ' ' and then Cell_At (4, 9).Ch = ' ',
          "ED 2 clears the screen");

   --  ---- attributes reach the cells a renderer reads
   Set_Cursor (0, 0);
   Set_Attr (7);
   Put ('R');
   Check (Cell_At (0, 0).Rev, "SGR 7 marks the cell reverse");

   Set_Attr (0);
   Put ('p');
   Check (not Cell_At (0, 1).Rev, "SGR 0 clears it");

   Set_Fg (2);
   Set_Bg (200);
   Put ('c');
   Check (Cell_At (0, 2).Fg = Character'Val (2), "SGR 38;5;2 reaches the cell");
   Check (Cell_At (0, 2).Bg = Character'Val (200), "SGR 48;5;200 reaches it too");
   Set_Attr (0);

   --  ---- wrapping and scrolling
   Init (4, 2);
   Puts ("ab");
   Check (Cursor_Row = 0 and then Cursor_Col = 2, "no wrap yet");
   Puts ("cd");
   Check (Cursor_Row = 1 and then Cell_At (0, 0).Ch = 'a',
          "past the last column wraps to the next row");

   Init (4, 2);
   New_Line;
   Puts ("x");
   Check (Cell_At (1, 0).Ch = 'x', "text on the last row");
   New_Line;
   Check (Cell_At (0, 0).Ch = 'x', "the last row scrolling up moved it to row 0");
   Check (Cursor_Row = 1, "and the cursor stayed on the last row");

   Ada.Text_IO.Put_Line ("screen: " & Natural'Image (Pass) & " passed,"
             & Natural'Image (Fail) & " failed");
   if Fail /= 0 then
      raise Program_Error with "screen model tests failed";
   end if;
end Terminal_Screen_Test;
