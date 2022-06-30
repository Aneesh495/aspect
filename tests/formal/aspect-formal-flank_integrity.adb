-- Implementation of flank protection property test.

with Aspect.Types; use Aspect.Types;
with Aspect.Interlocking; use Aspect.Interlocking;
with Aspect.Sim.Scenarios; use Aspect.Sim.Scenarios;
with Aspect.Sim.World; use Aspect.Sim.World;
with Aspect.Formal.Oracles; use Aspect.Formal.Oracles;

package body Aspect.Formal.Flank_Integrity is

   procedure Verify_Flank_Property (Ctx : in out Test_Context) is
      World  : World_Context;
      Report : Oracle_Report;
   begin
      Initialize_Simulation_World (World, Scenario => Scenario_Junction);

      -- 1. Initial State: Switch 2 is unlocked
      Assert (Ctx, not World.Net.Switches (2).Is_Mechanically_Locked,
              "Initial switch 2 is mechanically unlocked");

      -- 2. Request and lock Route 1 (Mainline through)
      Send_Dispatcher_Command
        (World,
         (Kind      => Cmd_Set_Route,
          Route     => 1,
          Sw_Id     => Null_Switch_Id,
          Sw_Target => Switch_Normal,
          Issuer_Id => 1));

      -- Execute 10 minor cycles to allow point throws and interlock proving
      for Step in 1 .. 10 loop
         Step_Simulation (World, Delta_Ms => 50);
      end loop;

      -- 3. Verify Flank Protection Lock on Switch 2
      Assert (Ctx, World.Net.Switches (2).Position = Switch_Normal,
              "Switch 2 aligned to Normal for defensive flank diversion");
      Assert (Ctx, World.Net.Switches (2).Is_Mechanically_Locked,
              "Switch 2 mechanically locked for flank protection");

      -- 4. Verify Protective Opposing Signal 4 is held at Stop
      Assert (Ctx, World.Net.Signals (4).Current_Aspect = Aspect_Stop,
              "Opposing siding signal 4 held strictly at Stop");

      -- 5. Execute Oracle Check
      Report := Verify_Flank_Integrity (World);
      Assert (Ctx, Report.Passed, "Formal flank integrity oracle holds on active Route 1");

      -- 6. Attempt conflicting manual throw on defensive Switch 2
      Send_Dispatcher_Command
        (World,
         (Kind      => Cmd_Manual_Switch_Throw,
          Route     => Null_Route_Id,
          Sw_Id     => 2,
          Sw_Target => Switch_Reverse,
          Issuer_Id => 99));

      Step_Simulation (World, Delta_Ms => 50);

      Assert (Ctx, World.Net.Switches (2).Position = Switch_Normal,
              "Switch 2 throw command rejected; remained in defensive Normal alignment");

      -- 7. Cancel Route 1 and verify flank release
      Send_Dispatcher_Command
        (World,
         (Kind      => Cmd_Cancel_Route,
          Route     => 1,
          Sw_Id     => Null_Switch_Id,
          Sw_Target => Switch_Normal,
          Issuer_Id => 1));

      for Step in 1 .. 10 loop
         Step_Simulation (World, Delta_Ms => 50);
      end loop;

      Assert (Ctx, not World.Net.Switches (2).Is_Mechanically_Locked,
              "Switch 2 flank lock safely released after route cancellation");
   end Verify_Flank_Property;

end Aspect.Formal.Flank_Integrity;
