with Ada.Text_IO;
with Terminal_Palette;   use Terminal_Palette;

--  Host test for the palette.  Small, but the numbers are the whole interface:
--  an off-by-one in the cube's level table is a colour nobody notices until a
--  screenshot looks wrong, which is a bad way to find it.
procedure Terminal_Palette_Test is
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

   procedure Is_Rgb (I, R, G, B : Natural; What : String) is
      A, C, D : Natural;
   begin
      Rgb (I, A, C, D);
      Check (A = R and then C = G and then D = B, What);
   end Is_Rgb;

begin
   Is_Rgb (0,   0, 0, 0,         "index 0 is black");
   Is_Rgb (7,   192, 192, 192,   "index 7 is the light grey");
   Is_Rgb (15,  255, 255, 255,   "index 15 is white");
   Is_Rgb (9,   255, 0, 0,       "index 9 is bright red");

   --  the cube: 16 is its black corner, and the levels are 0/55/95/135/175/215/255
   Is_Rgb (16,  0, 0, 0,         "cube corner 0");
   Is_Rgb (21,  0, 0, 255,       "cube blue corner");
   Is_Rgb (196, 255, 0, 0,       "cube red corner");
   Is_Rgb (231, 255, 255, 255,   "cube white corner");
   Is_Rgb (52,  95, 0, 0,        "the 95 step, not 90 or 100");

   --  greys
   Is_Rgb (232, 8, 8, 8,         "first grey is 8");
   Is_Rgb (255, 238, 238, 238,   "last grey is 238");

   --  clamping, both directions
   Is_Rgb (999, 238, 238, 238,   "above the range takes the last colour");

   Ada.Text_IO.Put_Line ("palette: " & Natural'Image (Pass) & " passed,"
                         & Natural'Image (Fail) & " failed");
   if Fail /= 0 then
      raise Program_Error with "palette tests failed";
   end if;
end Terminal_Palette_Test;
