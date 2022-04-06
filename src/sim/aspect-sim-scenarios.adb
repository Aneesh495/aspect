with Aspect.Types; use Aspect.Types;
with Aspect.Topology.Tracks; use Aspect.Topology.Tracks;
with Aspect.Topology.Switches; use Aspect.Topology.Switches;
with Aspect.Topology.Signals; use Aspect.Topology.Signals;
with Aspect.Interlocking.Routes; use Aspect.Interlocking.Routes;
with Aspect.Interlocking.Flank; use Aspect.Interlocking.Flank;
with Aspect.Sim.Vehicle_Dynamics; use Aspect.Sim.Vehicle_Dynamics;

package body Aspect.Sim.Scenarios is

   procedure Build_Junction_Scenario
     (Net  : out Railway_Network;
      Core : out Interlocking_Core;
      Reg  : out Simulation_Registry)
   is
      S1, S2, S3, S4, S5, S6 : Track_Section;
      Sw1, Sw2               : Turnout_Switch;
      Sig1, Sig2, Sig3, Sig4 : Railway_Signal;
      R1, R2                 : Interlocking_Route;
      Train1                 : Train_Vehicle;
   begin
      Initialize_Network (Net);
      Initialize_Registry (Reg);

      -- Track Sections
      Initialize_Section (S1, 1, "SEC_APPROACH", 800.0, 0.0, 160.0, 0.0);
      Initialize_Section (S2, 2, "SEC_MAIN_A", 800.0, 800.0, 160.0, 0.0);
      Initialize_Section (S3, 3, "SEC_MAIN_B", 800.0, 1600.0, 160.0, 0.0);
      Initialize_Section (S4, 4, "SEC_DIVERGE", 600.0, 800.0, 60.0, 0.0);
      Initialize_Section (S5, 5, "SEC_SIDING", 600.0, 1400.0, 40.0, 0.0);
      Initialize_Section (S6, 6, "SEC_OVERLAP", 250.0, 2400.0, 160.0, 0.0);

      -- Turnout Switches
      Initialize_Switch (Sw1, 1, "SW_JUNCTION", 1, 1, 2, 4, 160.0, 60.0);
      Initialize_Switch (Sw2, 2, "SW_SIDING_DEF", 4, 4, 5, 3, 60.0, 40.0);

      -- Signals
      Initialize_Signal (Sig1, 1, "SIG_ENTRY", Category_Main, 1, 1, 2, 0.0, Dir_Nominal);
      Initialize_Signal (Sig2, 2, "SIG_MAIN_EXIT", Category_Main, 3, 2, Null_Signal_Id, 2400.0, Dir_Nominal);
      Initialize_Signal (Sig3, 3, "SIG_DIVERGE", Category_Main, 4, 1, Null_Signal_Id, 1400.0, Dir_Nominal);
      Initialize_Signal (Sig4, 4, "SIG_SHUNT_DEF", Category_Shunt, 5, 5, Null_Signal_Id, 1400.0, Dir_Nominal);

      Register_Section (Net, S1);
      Register_Section (Net, S2);
      Register_Section (Net, S3);
      Register_Section (Net, S4);
      Register_Section (Net, S5);
      Register_Section (Net, S6);

      Register_Switch (Net, Sw1);
      Register_Switch (Net, Sw2);

      Register_Signal (Net, Sig1);
      Register_Signal (Net, Sig2);
      Register_Signal (Net, Sig3);
      Register_Signal (Net, Sig4);

      -- Direct block linkings
      Link_Sections (Net, 2, 3, Dir_Nominal);
      Link_Sections (Net, 3, 6, Dir_Nominal);

      -- Route 1: Mainline Through (S1 -> S2 -> S3, SW1 Normal, protected by SW2 in Normal)
      Initialize_Route (R1, 1, "R1_MAIN_THRU", 1, 2, Class_Main_Train);
      Add_Section (R1, 1);
      Add_Section (R1, 2);
      Add_Section (R1, 3);
      Add_Switch_Alignment (R1, 1, Switch_Normal);
      Set_Overlap_Protection (R1, 6, 250.0);

      -- Route 2: Diverging to Loop (S1 -> S4 -> S5, SW1 Reverse, SW2 Normal)
      Initialize_Route (R2, 2, "R2_DIVERGE", 1, 3, Class_Main_Train);
      Add_Section (R2, 1);
      Add_Section (R2, 4);
      Add_Section (R2, 5);
      Add_Switch_Alignment (R2, 1, Switch_Reverse);
      Add_Switch_Alignment (R2, 2, Switch_Normal);

      Initialize_Core (Core, Net);
      Register_Route (Core, R1);
      Register_Route (Core, R2);

      -- Flank defense for Route 1: Diverting switch SW2 must be locked in Normal
      -- to prevent runaway wagons in siding S5 from fouling mainline section S3
      Add_Flank_Defense (Core.Flank, Route => 1,
                         Protective_Switch => 2,
                         Diverting_Position => Switch_Normal,
                         Protective_Signal => 4,
                         Fouling_Section => 4);

      Finalize_Configuration (Core);

      -- Express Train
      Initialize_Train (Train1, 1, "EXPRESS_101", Mass => 480.0, Length_M => 200.0);
      Add_Train (Reg, Train1, Start_Km => 0.0, Start_Sec => 1);
   end Build_Junction_Scenario;

   procedure Build_High_Speed_Scenario
     (Net  : out Railway_Network;
      Core : out Interlocking_Core;
      Reg  : out Simulation_Registry)
   is
      Sec    : Track_Section;
      Sig    : Railway_Signal;
      R1     : Interlocking_Route;
      HST    : Train_Vehicle;
   begin
      Initialize_Network (Net);
      Initialize_Registry (Reg);

      -- 8 high-speed blocks of 1200m each = 9600m corridor
      for I in 1 .. 8 loop
         declare
            Name_Str : constant String := "HS_BLOCK_0" & Character'Val (Character'Pos ('0') + I);
            Start_D  : constant Track_Chainage := Track_Chainage (Float (I - 1) * 1200.0);
            Grad     : Gradient_Per_Mille := 0.0;
         begin
            if I = 3 then
               Grad := 8.0; -- +8 per mille uphill
            elsif I = 6 then
               Grad := -12.0; -- -12 per mille downhill
            end if;

            Initialize_Section (Sec, Section_Id (I), Name_Str, 1200.0, Start_D, 300.0, Grad);
            Register_Section (Net, Sec);

            if I > 1 then
               Link_Sections (Net, Section_Id (I - 1), Section_Id (I), Dir_Nominal);
            end if;
         end;
      end loop;

      -- Entry and exit signals
      Initialize_Signal (Sig, 1, "SIG_HS_ENTRY", Category_Main, 1, 1, 2, 0.0, Dir_Nominal);
      Register_Signal (Net, Sig);
      Initialize_Signal (Sig, 2, "SIG_HS_EXIT", Category_Main, 8, 7, Null_Signal_Id, 9600.0, Dir_Nominal);
      Register_Signal (Net, Sig);

      -- Master 9.6 km high speed route
      Initialize_Route (R1, 1, "R_HST_FULL", 1, 2, Class_Main_Train);
      for I in 1 .. 8 loop
         Add_Section (R1, Section_Id (I));
      end loop;

      Initialize_Core (Core, Net);
      Register_Route (Core, R1);
      Finalize_Configuration (Core);

      -- High-Speed Train
      Initialize_Train (HST, 1, "FRECCIA_300", Mass => 420.0, Length_M => 200.0);
      HST.Max_Power_KW := 9800.0;
      Add_Train (Reg, HST, Start_Km => 0.0, Start_Sec => 1);
   end Build_High_Speed_Scenario;

   procedure Build_Safety_Stress_Scenario
     (Net  : out Railway_Network;
      Core : out Interlocking_Core;
      Reg  : out Simulation_Registry)
   is
   begin
      Build_Junction_Scenario (Net, Core, Reg);
   end Build_Safety_Stress_Scenario;

end Aspect.Sim.Scenarios;
