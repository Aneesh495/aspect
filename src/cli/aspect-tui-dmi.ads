-- ETCS Level 2 Driver Machine Interface (DMI) terminal speedometer and supervision dial.
-- Renders the ERA-ERTMS-015560 circular speed arc, dynamic brake intervention thresholds,
-- throttle and pneumatic brake demand bargraphs.

with Aspect.TUI.Canvas; use Aspect.TUI.Canvas;
with Aspect.Telemetry; use Aspect.Telemetry;

package Aspect.TUI.DMI is

   -- Renders the ETCS DMI speedometer and driver panel onto the TUI canvas
   procedure Render_DMI
     (C        : in out Terminal_Canvas;
      Snapshot : Telemetry_Snapshot;
      Train_Idx: Positive := 1;
      Top_Row  : Positive := 25;
      Left_Col : Positive := 2);

end Aspect.TUI.DMI;
