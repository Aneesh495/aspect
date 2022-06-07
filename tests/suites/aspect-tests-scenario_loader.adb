-- Implementation of scenario loader test suite.

with Ada.Text_IO;
with Aspect.Types; use Aspect.Types;
with Aspect.Topology.Network; use Aspect.Topology.Network;
with Aspect.Interlocking.Engine; use Aspect.Interlocking.Engine;
with Aspect.Sim.Track_Simulation; use Aspect.Sim.Track_Simulation;
with Aspect.Sim.Scenario_Loader; use Aspect.Sim.Scenario_Loader;
with Aspect.Tests.Framework; use Aspect.Tests.Framework;

package body Aspect.Tests.Scenario_Loader is

   ----------------------------------------------------------------------------
   -- Test: Load Grand Central Junction JSON
   ----------------------------------------------------------------------------
   procedure Test_Load_Junction (Ctx : in out Test_Context) is
      Net     : Railway_Network;
      Core    : Interlocking_Core;
      Reg     : Simulation_Registry;
      Success : Boolean;
      Err_Msg : Error_String;
   begin
      Load_Scenario_From_File
        (File_Path => "scenarios/junction.json",
         Net       => Net,
         Core      => Core,
         Reg       => Reg,
         Success   => Success,
         Error_Msg => Err_Msg);

      Assert (Ctx, Success, "Loaded scenarios/junction.json successfully");
      Assert (Ctx, Net.Section_Count = 6, "Junction scenario contains 6 sections");
      Assert (Ctx, Net.Switch_Count = 2, "Junction scenario contains 2 switches");
      Assert (Ctx, Net.Signal_Count = 4, "Junction scenario contains 4 signals");
      Assert (Ctx, Reg.Train_Count = 2, "Junction scenario contains 2 trains");
   end Test_Load_Junction;

   ----------------------------------------------------------------------------
   -- Test: Load High Speed Corridor JSON
   ----------------------------------------------------------------------------
   procedure Test_Load_High_Speed (Ctx : in out Test_Context) is
      Net     : Railway_Network;
      Core    : Interlocking_Core;
      Reg     : Simulation_Registry;
      Success : Boolean;
      Err_Msg : Error_String;
   begin
      Load_Scenario_From_File
        (File_Path => "scenarios/high_speed.json",
         Net       => Net,
         Core      => Core,
         Reg       => Reg,
         Success   => Success,
         Error_Msg => Err_Msg);

      Assert (Ctx, Success, "Loaded scenarios/high_speed.json successfully");
      Assert (Ctx, Net.Section_Count = 8, "High-Speed corridor contains 8 sections");
      Assert (Ctx, Net.Sections (1).Line_Speed_Limit = 320.0, "Section 1 speed limit is 320 km/h");
      Assert (Ctx, Reg.Train_Count = 1, "High-Speed corridor contains 1 train");
   end Test_Load_High_Speed;

   ----------------------------------------------------------------------------
   -- Test: Load Safety Fault Stress JSON
   ----------------------------------------------------------------------------
   procedure Test_Load_Safety_Stress (Ctx : in out Test_Context) is
      Net     : Railway_Network;
      Core    : Interlocking_Core;
      Reg     : Simulation_Registry;
      Success : Boolean;
      Err_Msg : Error_String;
   begin
      Load_Scenario_From_File
        (File_Path => "scenarios/safety_stress.json",
         Net       => Net,
         Core      => Core,
         Reg       => Reg,
         Success   => Success,
         Error_Msg => Err_Msg);

      Assert (Ctx, Success, "Loaded scenarios/safety_stress.json successfully");
      Assert (Ctx, Net.Section_Count = 4, "Safety Stress scenario contains 4 sections");
      Assert (Ctx, Reg.Train_Count = 2, "Safety Stress scenario contains 2 trains");
   end Test_Load_Safety_Stress;

   ----------------------------------------------------------------------------
   -- Test: Load Invalid Schema
   ----------------------------------------------------------------------------
   procedure Test_Invalid_JSON (Ctx : in out Test_Context) is
      Net     : Railway_Network;
      Core    : Interlocking_Core;
      Reg     : Simulation_Registry;
      Success : Boolean;
      Err_Msg : Error_String;
   begin
      Load_Scenario_From_JSON
        (JSON_Text => "{""invalid_payload"": true}",
         Net       => Net,
         Core      => Core,
         Reg       => Reg,
         Success   => Success,
         Error_Msg => Err_Msg);

      Assert (Ctx, not Success, "Invalid JSON returns failure");
   end Test_Invalid_JSON;

   ----------------------------------------------------------------------------
   -- Main Entry Point
   ----------------------------------------------------------------------------
   procedure Run_Scenario_Loader_Tests (Overall_Passed : in out Boolean) is
      Ctx : Test_Context;
   begin
      Init_Context (Ctx, "Aspect.Sim (Declarative JSON Scenario Loader)");

      Test_Load_Junction (Ctx);
      Test_Load_High_Speed (Ctx);
      Test_Load_Safety_Stress (Ctx);
      Test_Invalid_JSON (Ctx);

      if not Summarize (Ctx) then
         Overall_Passed := False;
      end if;
   end Run_Scenario_Loader_Tests;

end Aspect.Tests.Scenario_Loader;
