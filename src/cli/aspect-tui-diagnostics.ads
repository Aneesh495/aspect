-- EN 50128 SIL 4 vital supervisor and 2oo3 voter diagnostic panel.
-- Displays triplicated channel states, Byzantine fault mitigation counters,
-- safety barrier invariant status, and interactive operator keybindings.

with Aspect.TUI.Canvas; use Aspect.TUI.Canvas;
with Aspect.Telemetry; use Aspect.Telemetry;

package Aspect.TUI.Diagnostics is

   -- Renders the 2oo3 vital executive diagnostic panel onto the TUI canvas
   procedure Render_Diagnostics
     (C        : in out Terminal_Canvas;
      Snapshot : Telemetry_Snapshot;
      Top_Row  : Positive := 25;
      Left_Col : Positive := 61);

end Aspect.TUI.Diagnostics;
