with Terminal_CSI;        use Terminal_CSI;
with Terminal_Screen;

package body Terminal_Emul is

   procedure Init (Cols, Rows : Natural) is
   begin
      Terminal_CSI.Reset;
      Terminal_Screen.Init (Cols, Rows);
   end Init;

   procedure Feed (Ch : Character) is
      A : Action;
   begin
      Terminal_CSI.Feed (Ch, A);
      case A.K is
         when None =>
            null;                     --  an intermediate byte of a sequence
         when Print =>
            Terminal_Screen.Put (A.Ch);
         when Control =>
            case A.Ch is
               when ASCII.LF => Terminal_Screen.New_Line;
               when ASCII.CR => Terminal_Screen.Carriage_Return;
               when ASCII.BS => Terminal_Screen.Backspace;
               when ASCII.HT => Terminal_Screen.Tab;
               when others   => null; --  BEL and the rest: nothing to do yet
            end case;
         when SGR =>
            if A.Attr = 0 then
               Terminal_Screen.Set_Attr (0);
            elsif A.Attr = 7 then
               Terminal_Screen.Set_Attr (7);
            end if;
            if A.Fg >= 0 then
               Terminal_Screen.Set_Fg (Natural (A.Fg));
            end if;
            if A.Bg >= 0 then
               Terminal_Screen.Set_Bg (Natural (A.Bg));
            end if;
         when Cursor_Up =>
            Terminal_Screen.Move (0, -Integer (A.N));
         when Cursor_Down =>
            Terminal_Screen.Move (0, Integer (A.N));
         when Cursor_Right =>
            Terminal_Screen.Move (Integer (A.N), 0);
         when Cursor_Left =>
            Terminal_Screen.Move (-Integer (A.N), 0);
         when Cursor_Pos =>
            Terminal_Screen.Set_Cursor (A.Row, A.Col);
         when Erase_Display =>
            Terminal_Screen.Erase_Display (A.N);
         when Erase_Line =>
            Terminal_Screen.Erase_Line (A.N);
         when Unknown =>
            null;                     --  counted by the parser, ignored here
      end case;
   end Feed;

end Terminal_Emul;
