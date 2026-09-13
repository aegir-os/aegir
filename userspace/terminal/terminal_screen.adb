package body Terminal_Screen is

   --  A named ROW type, so a nested aggregate is a Row and not an ambiguity: a
   --  two-dimensional aggregate of anonymous inner arrays does not resolve.
   type Row  is array (0 .. Max_Cols - 1) of Cell;
   type Grid is array (0 .. Max_Rows - 1) of Row;

   Buf    : Grid;
   C      : Natural := 80;
   R      : Natural := 25;
   Cur_R  : Natural := 0;
   Cur_C  : Natural := 0;
   Fg     : Character := ' ';
   Bg     : Character := ' ';
   Rev    : Boolean := False;

   function Cols return Natural is (C);
   function Rows return Natural is (R);
   function Cursor_Row return Natural is (Cur_R);
   function Cursor_Col return Natural is (Cur_C);
   function Cell_At (Row, Col : Natural) return Cell is (Buf (Row) (Col));

   procedure Clear is
   begin
      Buf := (others => (others => (Ch => ' ', Fg => ' ', Bg => ' ',
                                    Rev => False)));
      Cur_R := 0;
      Cur_C := 0;
   end Clear;

   procedure Init (Cols, Rows : Natural) is
   begin
      C := Natural'Min (Natural'Max (Cols, 1), Max_Cols);
      R := Natural'Min (Natural'Max (Rows, 1), Max_Rows);
      Clear;
   end Init;

   procedure Scroll_Up is
   begin
      for I in 1 .. R - 1 loop
         Buf (I - 1) (0 .. C - 1) := Buf (I) (0 .. C - 1);
      end loop;
      Buf (R - 1) (0 .. C - 1) := (others => (Ch => ' ', Fg => Fg, Bg => Bg,
                                              Rev => Rev));
   end Scroll_Up;

   procedure New_Line is
   begin
      Cur_C := 0;
      if Cur_R + 1 >= R then
         Scroll_Up;
      else
         Cur_R := Cur_R + 1;
      end if;
   end New_Line;

   procedure Carriage_Return is
   begin
      Cur_C := 0;
   end Carriage_Return;

   procedure Backspace is
   begin
      if Cur_C > 0 then
         Cur_C := Cur_C - 1;
      end if;
   end Backspace;

   procedure Tab is
   begin
      if (Cur_C / 8) * 8 + 8 < C then
         Cur_C := (Cur_C / 8) * 8 + 8;
      else
         Cur_C := C - 1;
      end if;
   end Tab;

   procedure Put (Ch : Character) is
   begin
      Buf (Cur_R) (Cur_C) := (Ch => Ch, Fg => Fg, Bg => Bg, Rev => Rev);
      if Cur_C + 1 >= C then
         New_Line;
      else
         Cur_C := Cur_C + 1;
      end if;
   end Put;

   procedure Set_Cursor (Row, Col : Natural) is
   begin
      Cur_R := Natural'Min (Row, R - 1);
      Cur_C := Natural'Min (Col, C - 1);
   end Set_Cursor;

   procedure Move (D_Col, D_Row : Integer) is
      function Clamp (V : Integer; Hi : Natural) return Natural is
        (if V < 0 then 0
         elsif V > Integer (Hi) then Hi
         else Natural (V));
   begin
      --  Bounded, not wrapping: a count can name a cell off the screen, and
      --  clamping keeps it on this one rather than on a different one.
      Cur_C := Clamp (Integer (Cur_C) + D_Col, C - 1);
      Cur_R := Clamp (Integer (Cur_R) + D_Row, R - 1);
   end Move;

   procedure Blank (Row : Natural; First, Last : Natural) is
   begin
      for K in First .. Last loop
         Buf (Row) (K) := (Ch => ' ', Fg => Fg, Bg => Bg, Rev => Rev);
      end loop;
   end Blank;

   procedure Erase_Line (Mode : Natural) is
   begin
      if Mode = 1 then
         Blank (Cur_R, 0, Cur_C);
      elsif Mode = 2 then
         Blank (Cur_R, 0, C - 1);
      else
         Blank (Cur_R, Cur_C, C - 1);
      end if;
   end Erase_Line;

   procedure Erase_Display (Mode : Natural) is
   begin
      if Mode = 1 then
         if Cur_R > 0 then
            for I in 0 .. Cur_R - 1 loop
               Blank (I, 0, C - 1);
            end loop;
         end if;
         Blank (Cur_R, 0, Cur_C);
      elsif Mode = 2 then
         for I in 0 .. R - 1 loop
            Blank (I, 0, C - 1);
         end loop;
      else
         Blank (Cur_R, Cur_C, C - 1);
         if Cur_R + 1 < R then
            for I in Cur_R + 1 .. R - 1 loop
               Blank (I, 0, C - 1);
            end loop;
         end if;
      end if;
   end Erase_Display;

   procedure Set_Attr (Attr : Natural) is
   begin
      if Attr = 0 then
         Fg := ' ';
         Bg := ' ';
         Rev := False;
      elsif Attr = 7 then
         Rev := True;
      end if;
      --  Any other attribute is acknowledged and has no effect here: the
      --  documented set is what the terminal promises, and the rest is not
      --  guessed at.
   end Set_Attr;

   procedure Set_Fg (Index : Natural) is
   begin
      if Index <= 255 then
         Fg := Character'Val (Index);
      end if;
   end Set_Fg;

   procedure Set_Bg (Index : Natural) is
   begin
      if Index <= 255 then
         Bg := Character'Val (Index);
      end if;
   end Set_Bg;

end Terminal_Screen;
