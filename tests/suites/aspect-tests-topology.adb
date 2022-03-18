with Aspect.Types; use Aspect.Types;
with Aspect.Topology; use Aspect.Topology;
with Aspect.Topology.Tracks; use Aspect.Topology.Tracks;
with Aspect.Topology.Switches; use Aspect.Topology.Switches;
with Aspect.Topology.Signals; use Aspect.Topology.Signals;
with Aspect.Topology.Balises; use Aspect.Topology.Balises;
with Aspect.Topology.Network; use Aspect.Topology.Network;
with Aspect.Tests.Framework; use Aspect.Tests.Framework;

package body Aspect.Tests.Topology is

   procedure Run_Topology_Tests (Overall_Passed : in out Boolean) is
      Ctx : Test_Context;
   begin
      Init_Context (Ctx, "Aspect.Topology (Tracks, Switches, Signals, Balises, Network)");

      -------------------------------------------------------------------------
      -- Test 1: Track Block Shunting, Axle Counting & Fault Injections
      -------------------------------------------------------------------------
      declare
         Sec : Track_Section;
      begin
         Initialize_Section (Sec, 1, "TC_101", 800.0, 10_000.0, 160.0, 0.0, Tech_DC_Track_Circuit);
         Assert (Ctx, Sec.Occupancy = State_Clear, "Initial track section state is Clear");
         Assert (Ctx, Sec.Relay_Energized, "Initial track relay is energized (picked up)");

         -- Train 1 shunts track
         Shunt_By_Train (Sec, 1);
         Assert (Ctx, Sec.Occupancy = State_Occupied, "Shunted track section becomes Occupied");
         Assert (Ctx, not Sec.Relay_Energized, "Track relay drops on train shunt");

         -- Train 1 clears track
         Clear_Train_Shunt (Sec, 1);
         Assert (Ctx, Sec.Occupancy = State_Clear, "Vacated track section restores to Clear");
         Assert (Ctx, Sec.Relay_Energized, "Track relay picks up when train clears");

         -- Broken rail fault injection
         Set_Broken_Rail (Sec, True);
         Assert (Ctx, Sec.Occupancy = State_Disturbed, "Broken rail forces Disturbed state");
         Assert (Ctx, not Sec.Relay_Energized, "Broken rail drops relay fail-safe");
         Set_Broken_Rail (Sec, False);
         Assert (Ctx, Sec.Occupancy = State_Clear, "Clearing broken rail restores Clear");

         -- Low ballast electrical resistance leakage fault
         Set_Ballast_Resistance (Sec, 1.2); -- 1.2 ohms < critical 2.5 ohms
         Assert (Ctx, Sec.Occupancy = State_Disturbed, "Ballast water saturation triggers Disturbed");
         Set_Ballast_Resistance (Sec, 100.0);
         Assert (Ctx, Sec.Occupancy = State_Clear, "Restored ballast resistance clears disturbance");
      end;

      -------------------------------------------------------------------------
      -- Test 2: Turnout Switches and Detector Locking
      -------------------------------------------------------------------------
      declare
         Sw       : Turnout_Switch;
         Accepted : Boolean;
      begin
         Initialize_Switch (Sw, 1, "SW_01A", 10, 10, 11, 12, 160.0, 60.0);
         Assert (Ctx, Sw.Position = Switch_Normal, "Initial switch position is Normal");
         Assert (Ctx, Sw.Normal_Detection_Relay, "Initial normal detection relay is energized");

         -- Detector locking test: Attempt throw while track circuit is occupied!
         Request_Throw (Sw, Switch_Reverse, Track_Occupied => True, Accepted => Accepted);
         Assert (Ctx, not Accepted, "Detector locking rejects throw under wheel occupancy");
         Assert (Ctx, Sw.Position = Switch_Normal, "Switch remains Normal after rejected throw");

         -- Legitimate throw when unoccupied
         Request_Throw (Sw, Switch_Reverse, Track_Occupied => False, Accepted => Accepted);
         Assert (Ctx, Accepted, "Unoccupied switch accepts reverse throw request");
         Assert (Ctx, Sw.Position = Switch_In_Transit, "Switch enters In_Transit state");
         Assert (Ctx, not Sw.Normal_Detection_Relay and not Sw.Reverse_Detection_Relay,
                 "Detection relays drop during physical stroke");

         -- Update stroke timer: 2000 ms elapsed (partial transit)
         Update_Stroke_Timer (Sw, 2000);
         Assert (Ctx, Sw.Position = Switch_In_Transit, "Switch still in transit at 2000ms");

         -- Remaining 1500 ms elapsed (stroke complete)
         Update_Stroke_Timer (Sw, 1500);
         Assert (Ctx, Sw.Position = Switch_Reverse, "Switch locks into Reverse upon completion");
         Assert (Ctx, Sw.Reverse_Detection_Relay, "Reverse detection relay picks up");

         -- Obstacle stall test: Ballast rock blocks point travel
         Inject_Obstacle_Stall (Sw, True);
         Request_Throw (Sw, Switch_Normal, Track_Occupied => False, Accepted => Accepted);
         Update_Stroke_Timer (Sw, 3500);
         Assert (Ctx, Sw.Position = Switch_Lost_Detection,
                 "Obstacle stall forces Switch_Lost_Detection");
         Assert (Ctx, not Has_Verified_Detection (Sw, Switch_Normal),
                 "No verified detection when stalled by obstacle");
      end;

      -------------------------------------------------------------------------
      -- Test 3: Lineside Signals, 4-Aspect Cascading & Lamp Failure
      -------------------------------------------------------------------------
      declare
         Sig : Railway_Signal;
      begin
         Initialize_Signal (Sig, 1, "SIG_10", Category_Main, 10, 9, 2, 5000.0, Dir_Nominal);
         Assert (Ctx, Sig.Current_Aspect = Aspect_Stop, "Initial signal aspect is Stop (Red)");

         -- Multi-aspect cascade logic:
         -- Next signal is Stop -> Current signal is Caution (Yellow)
         Assert (Ctx, Compute_Cascade_Aspect (Aspect_Stop, True) = Aspect_Caution,
                 "Cascade: Next Stop -> Caution (Yellow)");
         -- Next signal is Caution -> Current signal is Preliminary Caution (Double Yellow)
         Assert (Ctx, Compute_Cascade_Aspect (Aspect_Caution, True) = Aspect_Preliminary_Caution,
                 "Cascade: Next Caution -> Preliminary Caution (Double Yellow)");
         -- Next signal is Clear -> Current signal is Clear (Green)
         Assert (Ctx, Compute_Cascade_Aspect (Aspect_Clear, True) = Aspect_Clear,
                 "Cascade: Next Clear -> Clear (Green)");

         -- Command signal to Clear (Green)
         Set_Aspect (Sig, Aspect_Clear);
         Assert (Ctx, Sig.Current_Aspect = Aspect_Clear, "Signal set to Clear displays Green");

         -- Filament burnout fault injection: must fail safe immediately to Stop!
         Inject_Lamp_Burnout (Sig, True);
         Assert (Ctx, Sig.Current_Aspect = Aspect_Stop,
                 "Filament burnout drops aspect to Stop fail-safe");
         Assert (Ctx, not Sig.Lamp_Health_Relay, "Lamp health relay drops on burnout");
      end;

      -------------------------------------------------------------------------
      -- Test 4: Eurobalise Telegram Framing and CRC-10
      -------------------------------------------------------------------------
      declare
         Balise   : Eurobalise;
         Payload  : constant Balise_Telegram_Data := [others => 16#AA#];
         Out_Data : Balise_Telegram_Data;
         Crc_OK   : Boolean;
      begin
         Initialize_Balise (Balise, 1, 101, 1, 2, Balise_Fixed, 5, 2500.0, Dir_Nominal);
         Load_Telegram (Balise, Payload, 832);

         Interrogate_Balise (Balise, Out_Data, Crc_OK);
         Assert (Ctx, Crc_OK, "Interrogate balise verifies correct CRC-10 checksum");
         Assert_Equal_Int (Ctx, 16#AA#, Long_Long_Integer (Out_Data (1)),
                           "Telegram payload retrieved intact");
      end;

      -------------------------------------------------------------------------
      -- Test 5: Network Graph Adjacency and Facing/Trailing Routing
      -------------------------------------------------------------------------
      declare
         Net : Railway_Network;
         S1, S2, S3, S4 : Track_Section;
         Sw  : Turnout_Switch;
      begin
         Initialize_Network (Net);

         -- Create 4 sections: S1 leads into Switch 1 facing point.
         -- Normal leg connects to S2. Reverse leg connects to S3.
         Initialize_Section (S1, 1, "SEC_01", 500.0, 0.0, 160.0, 0.0);
         Initialize_Section (S2, 2, "SEC_02", 500.0, 500.0, 160.0, 0.0);
         Initialize_Section (S3, 3, "SEC_03", 500.0, 500.0, 60.0, 0.0);
         Initialize_Section (S4, 4, "SEC_04", 500.0, 1000.0, 160.0, 0.0);

         Initialize_Switch (Sw, 1, "SW_01", 1, 1, 2, 3, 160.0, 60.0);

         Register_Section (Net, S1);
         Register_Section (Net, S2);
         Register_Section (Net, S3);
         Register_Section (Net, S4);
         Register_Switch (Net, Sw);

         Assert (Ctx, Verify_Integrity (Net), "Network topology integrity holds");

         -- Switch in Normal: S1 facing route must lead to S2
         Assert_Equal_Int (Ctx, 2, Long_Long_Integer (Next_Section (Net, 1, Dir_Nominal)),
                           "Facing switch in Normal routes to Normal leg (SEC_02)");

         -- Switch in Reverse: S1 facing route must lead to S3
         Net.Switches (1).Position := Switch_Reverse;
         Net.Switches (1).Reverse_Detection_Relay := True;
         Net.Switches (1).Normal_Detection_Relay := False;
         Assert_Equal_Int (Ctx, 3, Long_Long_Integer (Next_Section (Net, 1, Dir_Nominal)),
                           "Facing switch in Reverse routes to Reverse leg (SEC_03)");

         -- Compute path distance for [S1, S2, S4] = 500 + 500 + 500 = 1500m
         declare
            Path : constant Section_List := [1, 2, 4];
            Dist : constant Distance_M   := Compute_Path_Distance (Net, Path);
            Spd  : constant Speed_Kph    := Minimum_Speed_Along_Path (Net, Path);
         begin
            Assert_Within_Float (Ctx, 1500.0, Float (Dist), 0.1, "Cumulative path distance 1500m");
            Assert_Within_Float (Ctx, 160.0, Float (Spd), 0.1, "Civil line speed limit 160 km/h");
         end;
      end;

      if not Summarize (Ctx) then
         Overall_Passed := False;
      end if;
   end Run_Topology_Tests;

end Aspect.Tests.Topology;
