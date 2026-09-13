package body Terminal_CSI is

   type State_T is (Ground, Escape, Param);

   State   : State_T := Ground;
   NP      : Natural := 0;                    --  parameters collected
   Params  : array (1 .. Max_Params) of Natural := (others => 0);
   Has_P   : array (1 .. Max_Params) of Boolean := (others => False);
   Cur     : Natural := 0;                    --  the digit run in progress
   Cur_Set : Boolean := False;                --  ...and whether there was one
   Unsup   : Natural := 0;

   procedure Reset is
   begin
      State   := Ground;
      NP      := 0;
      Cur     := 0;
      Cur_Set := False;
   end Reset;

   function Unsupported return Natural is (Unsup);

   procedure Feed (B : Character; A : out Action) is
      C : constant Natural := Character'Pos (B);

      --  One more parameter slot.  Excess beyond Max_Params is what makes the
      --  whole sequence Unknown: a list that long is not in the promised set,
      --  and reading its first eight as if they were the whole thing would
      --  invent an action.
      procedure Take_Param is
      begin
         NP := NP + 1;
         if NP <= Max_Params then
            Params (NP) := Cur;
            Has_P (NP) := Cur_Set;
         end if;
      end Take_Param;

      --  The final byte: interpret, or refuse by name.
      procedure Finish (Final : Character; A : out Action) is
         P1 : constant Natural :=
           (if NP >= 1 and then Has_P (1) then Params (1) else 0);
         P2 : constant Natural :=
           (if NP >= 2 and then Has_P (2) then Params (2) else 0);
         N_Of : constant Natural := (if P1 = 0 then 1 else P1);
      begin
         if NP > Max_Params then
            Unsup := Unsup + 1;
            A := (K => Unknown, others => <>);
            return;
         end if;
         case Final is
            when 'm' =>
               --  0 reset, 7 reverse, 38;5;n fg, 48;5;n bg.  Anything else in
               --  the SGR family is acknowledged and left to the screen model.
               if NP = 3 and then P2 = 5
                 and then (P1 = 38 or else P1 = 48)
                 and then Has_P (3)
                 and then Params (3) <= 255
               then
                  if P1 = 38 then
                     A := (K => SGR, Fg => Integer (Params (3)), others => <>);
                  else
                     A := (K => SGR, Bg => Integer (Params (3)), others => <>);
                  end if;
               elsif NP = 1 then
                  A := (K => SGR, Attr => Integer (P1), others => <>);
               else
                  A := (K => SGR, Attr => -1, others => <>);
               end if;
            when 'A' => A := (K => Cursor_Up,    N => N_Of, others => <>);
            when 'B' => A := (K => Cursor_Down,  N => N_Of, others => <>);
            when 'C' => A := (K => Cursor_Right, N => N_Of, others => <>);
            when 'D' => A := (K => Cursor_Left,  N => N_Of, others => <>);
            when 'H' | 'f' =>
               A := (K   => Cursor_Pos,
                     Row => (if P1 = 0 then 0 else P1 - 1),
                     Col => (if P2 = 0 then 0 else P2 - 1),
                     others => <>);
            when 'J' => A := (K => Erase_Display, N => P1, others => <>);
            when 'K' => A := (K => Erase_Line,    N => P1, others => <>);
            when others =>
               Unsup := Unsup + 1;
               A := (K => Unknown, others => <>);
         end case;
      end Finish;

   begin
      A := (K => None, others => <>);
      case State is
         when Ground =>
            if B = ASCII.ESC then
               State := Escape;
            elsif C = 8 or else C = 9 or else C = 10
              or else C = 13 or else C = 7
            then
               A := (K => Control, Ch => B, others => <>);
            elsif C >= 32 then
               A := (K => Print, Ch => B, others => <>);
            else
               null;            --  an unclaimed C0 byte is dropped, not guessed
            end if;
         when Escape =>
            if B = '[' then
               State   := Param;
               NP      := 0;
               Cur     := 0;
               Cur_Set := False;
            else
               --  Not a CSI.  Counted, so "recognised as unsupported" stays a
               --  fact a test can assert.
               State := Ground;
               Unsup := Unsup + 1;
               A := (K => Unknown, others => <>);
            end if;
         when Param =>
            if B in '0' .. '9' then
               Cur     := Cur * 10 + (C - 48);
               Cur_Set := True;
            elsif B = ';' then
               Take_Param;
               Cur     := 0;
               Cur_Set := False;
            elsif C in 16#40# .. 16#7E# then
               Take_Param;
               Finish (B, A);
               State := Ground;
            else
               State := Ground;
               Unsup := Unsup + 1;
               A := (K => Unknown, others => <>);
            end if;
      end case;
   end Feed;

end Terminal_CSI;
