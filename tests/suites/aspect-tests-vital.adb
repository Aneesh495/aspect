with Aspect.Types; use Aspect.Types;
with Aspect.Topology; use Aspect.Topology;
with Aspect.Topology.Tracks; use Aspect.Topology.Tracks;
with Aspect.Topology.Switches; use Aspect.Topology.Switches;
with Aspect.Topology.Signals; use Aspect.Topology.Signals;
with Aspect.Topology.Network; use Aspect.Topology.Network;
with Aspect.Interlocking; use Aspect.Interlocking;
with Aspect.Interlocking.Routes; use Aspect.Interlocking.Routes;
with Aspect.Interlocking.Engine; use Aspect.Interlocking.Engine;
with Aspect.Vital; use Aspect.Vital;
with Aspect.Vital.Channels; use Aspect.Vital.Channels;
with Aspect.Vital.Voter; use Aspect.Vital.Voter;
with Aspect.Vital.Safety_Invariants; use Aspect.Vital.Safety_Invariants;
with Aspect.Vital.Cyclic_Executive; use Aspect.Vital.Cyclic_Executive;
with Aspect.Vital.FDIR; use Aspect.Vital.FDIR;
with Aspect.Tests.Framework; use Aspect.Tests.Framework;

package body Aspect.Tests.Vital is

   procedure Run_Vital_Tests (Overall_Passed : in out Boolean) is
      Ctx          : Test_Context;
      Net          : Railway_Network;
      Core         : Interlocking_Core;
      S1, S2       : Track_Section;
      Sw1          : Turnout_Switch;
      Sig1         : Railway_Signal;
      R1           : Interlocking_Route;
      Chans        : Triplicated_Channels;
      Supervisor   : Vital_Supervisor;
      Fdir_Sup     : FDIR_Supervisor;
   begin
      Init_Context (Ctx, "Aspect.Vital (2oo3 TMR, Voting, Safety Barrier Invariants, FDIR)");

      -------------------------------------------------------------------------
      -- Setup Minimal Base Layout for Redundant Channels
      -------------------------------------------------------------------------
      Initialize_Network (Net);
      Initialize_Section (S1, 1, "SEC_A", 500.0, 0.0, 160.0, 0.0);
      Initialize_Section (S2, 2, "SEC_B", 500.0, 500.0, 160.0, 0.0);
      Initialize_Switch (Sw1, 1, "SW_1", 1, 1, 2, 2, 160.0, 60.0);
      Initialize_Signal (Sig1, 1, "SIG_1", Category_Main, 1, 1, Null_Signal_Id, 0.0, Dir_Nominal);

      Register_Section (Net, S1);
      Register_Section (Net, S2);
      Register_Switch (Net, Sw1);
      Register_Signal (Net, Sig1);

      Initialize_Route (R1, 1, "ROUTE_1", 1, Null_Signal_Id, Class_Main_Train);
      Add_Section (R1, 1);
      Add_Section (R1, 2);
      Add_Switch_Alignment (R1, 1, Switch_Normal);

      Initialize_Core (Core, Net);
      Register_Route (Core, R1);
      Finalize_Configuration (Core);

      Initialize_Channels (Chans, Core);
      Initialize_FDIR (Fdir_Sup);

      -------------------------------------------------------------------------
      -- Test 1: Bit-Exact 2oo3 Majority Voting (Unanimous, Majority, Trip)
      -------------------------------------------------------------------------
      declare
         Voted_Asp : Signal_Aspect;
         Outcome   : Voting_Outcome;
      begin
         -- Unanimous vote (Green, Green, Green)
         Vote_Signal_Aspect (Chans, Aspect_Clear, Aspect_Clear, Aspect_Clear, Voted_Asp, Outcome);
         Assert (Ctx, Voted_Asp = Aspect_Clear, "Unanimous vote yields Clear aspect");
         Assert (Ctx, Outcome.Verdict = Verdict_Unanimous_3oo3, "Verdict is Verdict_Unanimous_3oo3");
         Assert (Ctx, not Outcome.Has_Divergence, "No divergence in unanimous vote");

         -- Majority vote: Channel C diverges (Green, Green, Red)
         Vote_Signal_Aspect (Chans, Aspect_Clear, Aspect_Clear, Aspect_Stop, Voted_Asp, Outcome);
         Assert (Ctx, Voted_Asp = Aspect_Clear, "Majority vote masks Channel C fault, yields Clear");
         Assert (Ctx, Outcome.Verdict = Verdict_Majority_2oo3, "Verdict is Verdict_Majority_2oo3");
         Assert (Ctx, Outcome.Faulty_Channel = Channel_C, "Channel C identified as faulty");
         Assert (Ctx, Outcome.Has_Divergence, "Divergence detected and logged");

         -- Total Byzantine breakdown: (Green, Yellow, Red) -> Must Trip Fail-Safe to Stop!
         Vote_Signal_Aspect (Chans, Aspect_Clear, Aspect_Caution, Aspect_Stop, Voted_Asp, Outcome);
         Assert (Ctx, Voted_Asp = Aspect_Stop, "Byzantine disagreement forces fail-safe Aspect_Stop");
         Assert (Ctx, Outcome.Verdict = Verdict_Tripped_Fail_Safe, "Verdict is Verdict_Tripped_Fail_Safe");
      end;

      -------------------------------------------------------------------------
      -- Test 2: Degraded 2oo2 Mode and Consensus Loss Trip
      -------------------------------------------------------------------------
      declare
         Voted_Bool : Boolean;
         Outcome    : Voting_Outcome;
      begin
         -- Isolate Channel C to simulate permanent single-channel hardware loss
         Chans (Channel_C).Is_Isolated := True;
         Chans (Channel_C).Health      := Channel_Faulted;
         Assert (Ctx, Determine_Operational_Mode (Chans) = Mode_Degraded_2oo2,
                 "System enters Mode_Degraded_2oo2 after isolating Channel C");

         -- In 2oo2: Channel A and Channel B agree (True, True)
         Vote_Boolean (Chans, True, True, False, Fail_Safe => False,
                       Voted_Val => Voted_Bool, Outcome => Outcome);
         Assert (Ctx, Voted_Bool, "Degraded 2oo2 consensus succeeds when A and B agree");
         Assert (Ctx, Outcome.Verdict = Verdict_Degraded_2oo2, "Verdict is Verdict_Degraded_2oo2");

         -- In 2oo2: Channel A and Channel B disagree (True, False) -> Fail-safe trip!
         Vote_Boolean (Chans, True, False, False, Fail_Safe => False,
                       Voted_Val => Voted_Bool, Outcome => Outcome);
         Assert (Ctx, not Voted_Bool, "Degraded 2oo2 disagreement forces fail-safe False");
         Assert (Ctx, Outcome.Verdict = Verdict_Tripped_Fail_Safe,
                 "2oo2 disagreement trips fail-safe shutdown");
      end;

      -------------------------------------------------------------------------
      -- Test 3: FDIR Discrepancy Tracking and Channel Resynchronization
      -------------------------------------------------------------------------
      declare
         Succ : Boolean;
      begin
         Initialize_Channels (Chans, Core);

         -- Inject 3 consecutive divergences on Channel B
         Handle_Channel_Discrepancy (Fdir_Sup, Chans, Channel_B, Time_Ms => 100);
         Handle_Channel_Discrepancy (Fdir_Sup, Chans, Channel_B, Time_Ms => 200);
         Handle_Channel_Discrepancy (Fdir_Sup, Chans, Channel_B, Time_Ms => 300);

         Assert (Ctx, Chans (Channel_B).Is_Isolated, "Channel B automatically isolated after 3 faults");
         Assert (Ctx, Chans (Channel_B).Health = Channel_Faulted, "Channel B marked Channel_Faulted");

         -- Resynchronize Channel B from Channel A
         Resynchronize_Channel (Fdir_Sup, Chans, Target_Channel => Channel_B,
                                Master_Channel => Channel_A, Success => Succ);
         Assert (Ctx, Succ, "Resynchronize Channel B from Channel A succeeded");
         Assert (Ctx, not Chans (Channel_B).Is_Isolated, "Channel B restored from isolation");
         Assert (Ctx, Chans (Channel_B).Health = Channel_Nominal, "Channel B restored to Channel_Nominal");
         Assert_Equal_Int (Ctx, 0, Long_Long_Integer (Chans (Channel_B).Consecutive_Divergences),
                           "Consecutive discrepancies reset to 0");
      end;

      -------------------------------------------------------------------------
      -- Test 4: Independent Formal Safety Barrier Invariant Checks
      -------------------------------------------------------------------------
      declare
         Audit_Res : Invariant_Check_Result;
         Bad_Core  : Interlocking_Core := Core;
      begin
         -- Nominal core: all invariants must pass
         Audit_Res := Audit_Safety_Invariants (Core);
         Assert (Ctx, Audit_Res.Passed, "Nominal interlocking passes all 5 safety invariants");

         -- Violation Test: Unauthorized Green Signal without route lock
         Bad_Core.Net.Signals (1).Current_Aspect := Aspect_Clear;
         Audit_Res := Audit_Safety_Invariants (Bad_Core);
         Assert (Ctx, not Audit_Res.Passed, "Unauthorized green signal trips safety barrier");
         Assert_Equal_Int (Ctx, 4, Long_Long_Integer (Audit_Res.Violated_Rule_Index),
                           "Violated rule index is 4 (Aspect Authorization)");

         -- Violation Test: Detector locking (switch throwing under occupied track)
         Bad_Core := Core;
         Bad_Core.Net.Switches (1).Position := Switch_In_Transit;
         Bad_Core.Net.Sections (1).Occupancy := State_Occupied;
         Audit_Res := Audit_Safety_Invariants (Bad_Core);
         Assert (Ctx, not Audit_Res.Passed, "Point throw under wheel occupancy trips safety barrier");
         Assert_Equal_Int (Ctx, 3, Long_Long_Integer (Audit_Res.Violated_Rule_Index),
                           "Violated rule index is 3 (Detector Locking)");
      end;

      -------------------------------------------------------------------------
      -- Test 5: Full Vital Supervisor Cyclic Executive
      -------------------------------------------------------------------------
      Initialize_Supervisor (Supervisor, Core);

      -- Dispatch Set Route command across all redundant channels
      Dispatch_Command
        (Supervisor,
         (Kind => Cmd_Set_Route, Route => 1, Sw_Id => Null_Switch_Id,
          Sw_Target => Switch_Normal, Issuer_Id => 1));

      -- Run minor cycle (50ms)
      Execute_Minor_Cycle (Supervisor, Delta_Ms => 50);

      Assert_Equal_Int (Ctx, 1, Long_Long_Integer (Supervisor.Metrics.Total_Cycles_Executed),
                        "Total cycles executed is 1");
      Assert (Ctx, Supervisor.Metrics.Last_Invariant_Passed,
              "Safety barrier passed on cyclic executive step");
      Assert (Ctx, Get_Voted_Core (Supervisor).Net.Signals (1).Current_Aspect = Aspect_Clear,
              "Voted interlocking consensus signal aspect is Clear");

      if not Summarize (Ctx) then
         Overall_Passed := False;
      end if;
   end Run_Vital_Tests;

end Aspect.Tests.Vital;
