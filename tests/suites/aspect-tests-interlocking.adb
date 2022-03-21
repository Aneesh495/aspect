with Aspect.Types; use Aspect.Types;
with Aspect.Topology; use Aspect.Topology;
with Aspect.Topology.Tracks; use Aspect.Topology.Tracks;
with Aspect.Topology.Switches; use Aspect.Topology.Switches;
with Aspect.Topology.Signals; use Aspect.Topology.Signals;
with Aspect.Topology.Network; use Aspect.Topology.Network;
with Aspect.Interlocking; use Aspect.Interlocking;
with Aspect.Interlocking.Routes; use Aspect.Interlocking.Routes;
with Aspect.Interlocking.Locking_Table; use Aspect.Interlocking.Locking_Table;
with Aspect.Interlocking.Engine; use Aspect.Interlocking.Engine;
with Aspect.Tests.Framework; use Aspect.Tests.Framework;

package body Aspect.Tests.Interlocking is

   procedure Run_Interlocking_Tests (Overall_Passed : in out Boolean) is
      Ctx  : Test_Context;
      Net  : Railway_Network;
      Core : Interlocking_Core;
      S1, S2, S3, S4, S_Overlap : Track_Section;
      Sw1  : Turnout_Switch;
      Sig1, Sig2 : Railway_Signal;
      R1, R2 : Interlocking_Route;
      Cmd  : Interlocking_Command;
      Succ : Boolean;
      Reas : Rejection_Reason;
   begin
      Init_Context (Ctx, "Aspect.Interlocking (CBI Engine, Locking Table, Flank, Sectional Release)");

      -------------------------------------------------------------------------
      -- Setup Test Railway Junction
      -------------------------------------------------------------------------
      Initialize_Network (Net);

      -- Sections: S1 (Approach & Facing), S2 (Normal Leg), S3 (Reverse Leg), S4 (Downstream), S_Overlap
      Initialize_Section (S1, 1, "SEC_01", 600.0, 0.0, 160.0, 0.0);
      Initialize_Section (S2, 2, "SEC_02", 600.0, 600.0, 160.0, 0.0);
      Initialize_Section (S3, 3, "SEC_03", 600.0, 600.0, 60.0, 0.0);
      Initialize_Section (S4, 4, "SEC_04", 600.0, 1200.0, 160.0, 0.0);
      Initialize_Section (S_Overlap, 5, "SEC_OV", 200.0, 1800.0, 160.0, 0.0);

      -- Turnout Switch: Point on S1, Normal leads to S2, Reverse leads to S3
      Initialize_Switch (Sw1, 1, "SW_JUNCTION", 1, 1, 2, 3, 160.0, 60.0);

      -- Signals: Sig1 at entrance of S1, Sig2 at exit of S2
      Initialize_Signal (Sig1, 1, "SIG_ENTRY", Category_Main, 1, 1, 2, 0.0, Dir_Nominal);
      Initialize_Signal (Sig2, 2, "SIG_EXIT", Category_Main, 2, 1, Null_Signal_Id, 1200.0, Dir_Nominal);

      Register_Section (Net, S1);
      Register_Section (Net, S2);
      Register_Section (Net, S3);
      Register_Section (Net, S4);
      Register_Section (Net, S_Overlap);
      Register_Switch (Net, Sw1);
      Register_Signal (Net, Sig1);
      Register_Signal (Net, Sig2);

      -- Route 1: S1 -> S2 (Mainline Through Route, requires SW1 in Normal)
      Initialize_Route (R1, 1, "R1_MAIN", 1, 2, Class_Main_Train);
      Add_Section (R1, 1);
      Add_Section (R1, 2);
      Add_Switch_Alignment (R1, 1, Switch_Normal);
      Set_Overlap_Protection (R1, 5, 200.0);

      -- Route 2: S1 -> S3 (Diverging Turnout Route, requires SW1 in Reverse)
      Initialize_Route (R2, 2, "R2_DIVERGE", 1, Null_Signal_Id, Class_Main_Train);
      Add_Section (R2, 1);
      Add_Section (R2, 3);
      Add_Switch_Alignment (R2, 1, Switch_Reverse);

      Initialize_Core (Core, Net);
      Register_Route (Core, R1);
      Register_Route (Core, R2);
      Finalize_Configuration (Core);

      -------------------------------------------------------------------------
      -- Test 1: Conflict Matrix Verification
      -------------------------------------------------------------------------
      Assert (Ctx, Are_Conflicting (Core.Locking, 1, 2),
              "Route 1 and Route 2 recognized as mutually conflicting (shared track & switch)");

      -------------------------------------------------------------------------
      -- Test 2: Set Route 1 (Nominal Path)
      -------------------------------------------------------------------------
      Cmd := (Kind => Cmd_Set_Route, Route => 1, Sw_Id => Null_Switch_Id,
              Sw_Target => Switch_Normal, Issuer_Id => 1);
      Execute_Command (Core, Cmd, Succ, Reas);
      Assert (Ctx, Succ, "Route 1 command successfully accepted");
      Assert (Ctx, Core.Routes (1).State = Route_Cleared, "Route 1 state transitioned to Cleared");
      Assert (Ctx, Core.Net.Signals (1).Current_Aspect = Aspect_Clear,
              "Origin signal displays Clear (Green) for Route 1");
      Assert (Ctx, Core.Net.Sections (1).Lock_Status = Lock_Route_Reserved,
              "Track section 1 is locked for Route 1");
      Assert (Ctx, Core.Net.Switches (1).Is_Mechanically_Locked,
              "Switch 1 is mechanically locked by Route 1");

      -------------------------------------------------------------------------
      -- Test 3: Mutual Exclusion: Attempt to Set Conflicting Route 2
      -------------------------------------------------------------------------
      Cmd := (Kind => Cmd_Set_Route, Route => 2, Sw_Id => Null_Switch_Id,
              Sw_Target => Switch_Reverse, Issuer_Id => 1);
      Execute_Command (Core, Cmd, Succ, Reas);
      Assert (Ctx, not Succ, "Conflicting Route 2 is strictly rejected while Route 1 is active");
      Assert (Ctx, Reas = Reject_Conflicting_Route_Locked,
              "Rejection reason is Reject_Conflicting_Route_Locked");

      -------------------------------------------------------------------------
      -- Test 4: Train Progression and Signal Drop Behind Train
      -------------------------------------------------------------------------
      -- Train 1 enters Section 1
      Handle_Train_Movement (Core, Train => 1, Entered_Sec => 1, Vacated_Sec => Null_Section_Id);
      Assert (Ctx, Core.Routes (1).State = Route_Occupied, "Route 1 transitions to Occupied");
      Assert (Ctx, Core.Net.Signals (1).Current_Aspect = Aspect_Stop,
              "Origin signal drops to Stop (Red) immediately upon train entry");

      -------------------------------------------------------------------------
      -- Test 5: Sectional Route Release
      -------------------------------------------------------------------------
      -- Train moves forward: enters Section 2, vacates Section 1
      Handle_Train_Movement (Core, Train => 1, Entered_Sec => 2, Vacated_Sec => 1);
      Assert (Ctx, Core.Routes (1).State = Route_Sectional_Release,
              "Route 1 enters Sectional Release mode");
      Assert (Ctx, Core.Net.Sections (1).Lock_Status = Lock_None,
              "Vacated track section 1 is released and unlocked behind the train");

      -- Train clears final Section 2
      Handle_Train_Movement (Core, Train => 1, Entered_Sec => 4, Vacated_Sec => 2);
      Assert (Ctx, Core.Routes (1).State = Route_Unset,
              "Route 1 completely releases and returns to Route_Unset");
      Assert (Ctx, not Core.Net.Switches (1).Is_Mechanically_Locked,
              "Switch 1 unlocked after full route clearance");

      -------------------------------------------------------------------------
      -- Test 6: Setting Route 2 after Route 1 Releases (Switch Transit)
      -------------------------------------------------------------------------
      Cmd := (Kind => Cmd_Set_Route, Route => 2, Sw_Id => Null_Switch_Id,
              Sw_Target => Switch_Reverse, Issuer_Id => 1);
      Execute_Command (Core, Cmd, Succ, Reas);
      Assert (Ctx, Succ, "Route 2 now accepted since Route 1 is released");
      Assert (Ctx, Core.Routes (2).State = Route_Requested,
              "Route 2 in Route_Requested awaiting motor throw to Reverse");

      -- Advance clock: 3500ms stroke duration
      Step_Cycle (Core, 3500);
      Assert (Ctx, Core.Routes (2).State = Route_Cleared,
              "Route 2 clears after switch reaches Reverse with verified detection");
      Assert (Ctx, Core.Net.Switches (1).Position = Switch_Reverse,
              "Switch 1 successfully locked in Reverse position");

      -------------------------------------------------------------------------
      -- Test 7: Global Emergency Stop
      -------------------------------------------------------------------------
      Trigger_Emergency_Stop (Core);
      Assert (Ctx, Core.Net.Signals (1).Current_Aspect = Aspect_Stop,
              "Emergency stop clamps all signals to Stop (Red)");

      if not Summarize (Ctx) then
         Overall_Passed := False;
      end if;
   end Run_Interlocking_Tests;

end Aspect.Tests.Interlocking;
