-- Implementation of point detector locking property test.

with Aspect.Types; use Aspect.Types;
with Aspect.Interlocking; use Aspect.Interlocking;
with Aspect.Sim.Scenarios; use Aspect.Sim.Scenarios;
with Aspect.Sim.World; use Aspect.Sim.World;
with Aspect.Formal.Oracles; use Aspect.Formal.Oracles;

package body Aspect.Formal.Switch_Locking is

   procedure Verify_Switch_Locking_Property (Ctx : in out Test_Context) is
      World  : World_Context;
      Report : Oracle_Report;
   begin
      Initialize_Simulation_World (World, Scenario => Scenario_Junction);

      -- 1. Initial State: Switch 1 is Normal and free
      Assert (Ctx, World.Net.Switches (1).Position = Switch_Normal,
              "Initial switch 1 position is Switch_Normal");

      -- 2. Simulate Train occupancy on Section 1 (Point Section for Switch 1)
      World.Net.Sections (1).Occupancy := State_Occupied;

      -- Attempt malicious dispatcher throw command to REVERSE
      Send_Dispatcher_Command
        (World,
         (Kind      => Cmd_Manual_Switch_Throw,
          Route     => Null_Route_Id,
          Sw_Id     => 1,
          Sw_Target => Switch_Reverse,
          Issuer_Id => 99));

      -- Execute 20 minor cycles (1000 ms)
      for Step in 1 .. 20 loop
         Step_Simulation (World, Delta_Ms => 50);

         -- Verify oracle property
         Report := Verify_Detector_Locking (World);
         Assert (Ctx, Report.Passed,
                 "Point detector locking oracle holds at step " & Natural'Image (Step));
      end loop;

      -- Assert switch never threw to REVERSE or entered transit
      Assert (Ctx, World.Net.Switches (1).Position = Switch_Normal,
              "Switch 1 remained locked in Normal position under occupancy");
      Assert (Ctx, World.Net.Switches (1).Stroke_Timer_Ms = 0,
              "Switch 1 motor stroke timer remained idle at 0 ms");

      -- 3. Simulate Route Lock
      World.Net.Sections (1).Occupancy := State_Clear;
      Send_Dispatcher_Command
        (World,
         (Kind      => Cmd_Set_Route,
          Route     => 1,
          Sw_Id     => Null_Switch_Id,
          Sw_Target => Switch_Normal,
          Issuer_Id => 1));

      Step_Simulation (World, Delta_Ms => 50);

      -- Attempt switch throw while locked by Route 1
      Send_Dispatcher_Command
        (World,
         (Kind      => Cmd_Manual_Switch_Throw,
          Route     => Null_Route_Id,
          Sw_Id     => 1,
          Sw_Target => Switch_Reverse,
          Issuer_Id => 99));

      for Step in 1 .. 10 loop
         Step_Simulation (World, Delta_Ms => 50);
         Report := Verify_Detector_Locking (World);
         Assert (Ctx, Report.Passed, "Detector locking holds under active route reservation");
      end loop;

      Assert (Ctx, World.Net.Switches (1).Position = Switch_Normal,
              "Switch 1 remained immobilized under route locking");
   end Verify_Switch_Locking_Property;

end Aspect.Formal.Switch_Locking;
