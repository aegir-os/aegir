--  The emulation driver: bytes in, grid state out.
--
--  This is the seam between the two units and the rest of the terminal.  It is
--  deliberately the ONLY thing a guest-side caller needs: Feed each byte from the
--  console, then render the cells.  Platform-free, so it is exercised on the host
--  with the real byte stream the Oberon Term library emits.
--  The spec names Terminal_Screen.Cell and Terminal_CSI's counters, so both are
--  with-ed here - a rename whose type or renamed entity is not visible does not
--  resolve, and the resulting errors point at the CALLERS, not at the spec.
with Terminal_CSI;
with Terminal_Screen;

package Terminal_Emul is

   procedure Init (Cols, Rows : Natural);
   procedure Feed (Ch : Character);

   --  The screen, re-exported so a renderer needs one with-clause.
   function Cols return Natural renames Terminal_Screen.Cols;
   function Rows return Natural renames Terminal_Screen.Rows;
   function Cursor_Row return Natural renames Terminal_Screen.Cursor_Row;
   function Cursor_Col return Natural renames Terminal_Screen.Cursor_Col;
   function Cell_At (Row, Col : Natural) return Terminal_Screen.Cell
     renames Terminal_Screen.Cell_At;

   --  Sequences recognised as sequences and not supported.  The design note makes
   --  "ignored" a defined outcome; this is what makes it assertable.
   function Unsupported return Natural renames Terminal_CSI.Unsupported;

end Terminal_Emul;
