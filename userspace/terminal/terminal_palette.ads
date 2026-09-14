--  The 256-colour palette, as data: a pure function from an index to three bytes.
--
--  Pure on purpose.  The guest's colour type is a 32-bit ARGB Pixel that comes
--  from the theme package, so folding three bytes into a Pixel is the guest's
--  job - and this stays host-testable, like the rest of the emulation.  Values
--  are the xterm ones: 16 basic and bright, a 6x6x6 cube, then greys.
package Terminal_Palette is

   procedure Rgb (Index : Natural; R, G, B : out Natural);
   --  Index is clamped to 0 .. 255: an out-of-range value takes the nearest
   --  defined colour rather than reading nothing, which is the same choice the
   --  SGR parser makes when it refuses an index above 255.

end Terminal_Palette;
