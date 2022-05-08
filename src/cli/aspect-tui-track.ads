-- Terminal track schematic and point blade alignment renderer.
-- Visualizes track circuit block states, point turnout positions,
-- and diverging routes with ANSI color-coding.

with Aspect.TUI.Canvas; use Aspect.TUI.Canvas;
with Aspect.Telemetry; use Aspect.Telemetry;

package Aspect.TUI.Track is

   -- Renders the railway schematic track diagram onto the TUI canvas
   procedure Render_Track_Layout
     (C        : in out Terminal_Canvas;
      Snapshot : Telemetry_Snapshot;
      Top_Row  : Positive := 2;
      Left_Col : Positive := 2);

end Aspect.TUI.Track;
