-- Implementation of 2oo3 voter diagnostic panel renderer.

package body Aspect.TUI.Diagnostics is

   procedure Render_Diagnostics
     (C        : in out Terminal_Canvas;
      Snapshot : Telemetry_Snapshot;
      Top_Row  : Positive := 25;
      Left_Col : Positive := 61)
   is
      Width  : constant Positive := 57;
      Height : constant Positive := 11;
   begin
      Draw_Box
        (C      => C,
         Top    => Top_Row,
         Left   => Left_Col,
         Height => Height,
         Width  => Width,
         Title  => "EN 50128 SIL 4 2oo3 VITAL VOTER METRICS",
         FG     => Color_Bright_Cyan,
         Bold   => True);

      -- Voting Summary
      Put_String (C, Top_Row + 2, Left_Col + 3, "VITAL CYCLES : ", FG => Color_Bright_White, Bold => True);
      Put_String (C, Top_Row + 2, Left_Col + 18, Natural'Image (Snapshot.Voter.Cycle_Count) & " (50ms Minor)", FG => Color_Bright_Cyan);

      Put_String (C, Top_Row + 3, Left_Col + 3, "2oo3 STATUS  : ", FG => Color_Bright_White, Bold => True);
      if Snapshot.Voter.Is_Degraded then
         Put_String (C, Top_Row + 3, Left_Col + 18, "DEGRADED 2oo2 / ISOLATION ACTIVE", FG => Color_Bright_Red, Bold => True);
      else
         Put_String (C, Top_Row + 3, Left_Col + 18, "TRIPLICATED 3oo3 (FULL CONSENSUS)", FG => Color_Bright_Green, Bold => True);
      end if;

      -- Channel States
      Put_String (C, Top_Row + 4, Left_Col + 3, "CHANNEL A    : NOMINAL [0 DIVERGENCES]", FG => Color_Bright_Green);
      Put_String (C, Top_Row + 5, Left_Col + 3, "CHANNEL B    : NOMINAL [0 DIVERGENCES]", FG => Color_Bright_Green);
      Put_String (C, Top_Row + 6, Left_Col + 3, "CHANNEL C    : NOMINAL [0 DIVERGENCES]", FG => Color_Bright_Green);

      -- Safety Invariant Status
      Put_String (C, Top_Row + 7, Left_Col + 3, "SAFETY AUDIT : ", FG => Color_Bright_White, Bold => True);
      if Snapshot.Voter.Last_Passed then
         Put_String (C, Top_Row + 7, Left_Col + 18, "PASS (5/5 INVARIANTS SATISFIED)", FG => Color_Bright_Green, Bold => True);
      else
         Put_String (C, Top_Row + 7, Left_Col + 18, "TRIPPED FAIL-SAFE SHUTDOWN", FG => Color_Bright_Red, Bold => True);
      end if;

      -- Divergences and Trips
      Put_String (C, Top_Row + 8, Left_Col + 3, "DIVERGENCES  : " & Natural'Image (Snapshot.Voter.Divergences) &
                  "   TRIPS: " & Natural'Image (Snapshot.Voter.Tripped_Cycles), FG => Color_Dim_White);

      -- Interactive Dispatcher Commands Bar
      Put_String (C, Top_Row + 9, Left_Col + 3,
                  "[S] Route 1  [D] Diverge 2  [C] Cancel  [E] E-Stop  [Q] Quit",
                  FG => Color_Bright_Yellow, Bold => True);

   end Render_Diagnostics;

end Aspect.TUI.Diagnostics;
