package body Terminal_Palette is

   --  The 16 basic and bright entries, in order.
   type Triple is record
      R, G, B : Natural;
   end record;
   Basic : constant array (0 .. 15) of Triple :=
     ((0, 0, 0),       (128, 0, 0),     (0, 128, 0),     (128, 128, 0),
      (0, 0, 128),     (128, 0, 128),   (0, 128, 128),   (192, 192, 192),
      (128, 128, 128), (255, 0, 0),     (0, 255, 0),     (255, 255, 0),
      (0, 0, 255),     (255, 0, 255),   (0, 255, 255),   (255, 255, 255));

   --  One channel of the cube: level 0 is 0, then 55, 95, 135, 175, 215, 255.
   function Level (L : Natural) return Natural is
     (if L = 0 then 0 else 55 + 40 * L);

   procedure Rgb (Index : Natural; R, G, B : out Natural) is
      I : constant Natural := (if Index > 255 then 255 else Index);
      N : Natural;
   begin
      if I < 16 then
         R := Basic (I).R;
         G := Basic (I).G;
         B := Basic (I).B;
      elsif I < 232 then
         N := I - 16;
         R := Level (N / 36);
         G := Level ((N / 6) mod 6);
         B := Level (N mod 6);
      else
         N := 8 + 10 * (I - 232);
         R := N;
         G := N;
         B := N;
      end if;
   end Rgb;

end Terminal_Palette;
