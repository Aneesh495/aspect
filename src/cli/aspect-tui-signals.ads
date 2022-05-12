-- Lineside signal aspect lamps, filament monitoring, and route state renderer.
-- Visualizes 4-aspect signal lamp heads, filament currents, and active route locks.

with Aspect.TUI.Canvas; use Aspect.TUI.Canvas;
with Aspect.Telemetry; use Aspect.Telemetry;

package Aspect.TUI.Signals is

   -- Renders the signal lamp heads and route locking table onto the TUI canvas
   procedure Render_Signals_And_Routes
     (C        : in out Terminal_Canvas;
      Snapshot : Telemetry_Snapshot;
      Top_Row  : Positive := 13;
      Left_Col : Positive := 2);

end Aspect.TUI.Signals;
