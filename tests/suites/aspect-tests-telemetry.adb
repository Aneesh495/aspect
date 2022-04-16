-- Implementation of telemetry test suite.
-- Verifies telemetry snapshot capture, JSON serialization format,
-- and dispatcher command ingestion parsing.

with Aspect.Types; use Aspect.Types;
with Aspect.Interlocking; use Aspect.Interlocking;
with Aspect.Sim.Scenarios; use Aspect.Sim.Scenarios;
with Aspect.Sim.World; use Aspect.Sim.World;
with Aspect.Telemetry; use Aspect.Telemetry;
with Aspect.Telemetry.Protocol; use Aspect.Telemetry.Protocol;
with Aspect.Tests.Framework; use Aspect.Tests.Framework;

package body Aspect.Tests.Telemetry is

   function Contains (Haystack : String; Needle : String) return Boolean is
   begin
      if Needle'Length = 0 or else Haystack'Length < Needle'Length then
         return False;
      end if;
      for I in Haystack'First .. Haystack'Last - Needle'Length + 1 loop
         if Haystack (I .. I + Needle'Length - 1) = Needle then
            return True;
         end if;
      end loop;
      return False;
   end Contains;

   ----------------------------------------------------------------------------
   -- Test: Snapshot Capture and JSON Serialization
   ----------------------------------------------------------------------------
   procedure Test_Snapshot_And_JSON (Ctx : in out Test_Context) is
      World    : World_Context;
      Snapshot : Telemetry_Snapshot;
      Buffer   : JSON_String_Buffer;
      Length   : Natural := 0;
   begin
      Initialize_Simulation_World (World, Scenario => Scenario_Junction);
      Step_Simulation (World, Delta_Ms => 50);

      Capture_Snapshot (World, Snapshot);

      Assert (Ctx, Snapshot.Timestamp_Ms = 50, "Snapshot timestamp equals 50 ms");
      Assert (Ctx, Snapshot.Step_Number = 1, "Snapshot step number equals 1");
      Assert (Ctx, Snapshot.Section_Count > 0, "Snapshot captured track sections");
      Assert (Ctx, Snapshot.Switch_Count > 0, "Snapshot captured switches");
      Assert (Ctx, Snapshot.Signal_Count > 0, "Snapshot captured signals");
      Assert (Ctx, Snapshot.Route_Count > 0, "Snapshot captured routes");
      Assert (Ctx, Snapshot.Train_Count > 0, "Snapshot captured simulated trains");

      Snapshot_To_JSON (Snapshot, Buffer, Length);

      Assert (Ctx, Length > 50, "JSON payload length is greater than 50 bytes");
      Assert (Ctx, Buffer (1) = '{', "JSON starts with opening brace");
      Assert (Ctx, Buffer (Length) = '}', "JSON ends with closing brace");

      declare
         JSON_Slice : constant String := Buffer (1 .. Length);
      begin
         Assert (Ctx, Contains (JSON_Slice, """type"":""telemetry_snapshot"""), "JSON contains type header");
         Assert (Ctx, Contains (JSON_Slice, """sections"":["), "JSON contains sections array");
         Assert (Ctx, Contains (JSON_Slice, """switches"":["), "JSON contains switches array");
         Assert (Ctx, Contains (JSON_Slice, """signals"":["), "JSON contains signals array");
         Assert (Ctx, Contains (JSON_Slice, """routes"":["), "JSON contains routes array");
         Assert (Ctx, Contains (JSON_Slice, """trains"":["), "JSON contains trains array");
         Assert (Ctx, Contains (JSON_Slice, """voter"":{"), "JSON contains voter object");
      end;
   end Test_Snapshot_And_JSON;

   ----------------------------------------------------------------------------
   -- Test: Dispatcher Command JSON Ingestion
   ----------------------------------------------------------------------------
   procedure Test_Command_Parsing (Ctx : in out Test_Context) is
      Cmd  : Interlocking_Command;
      Succ : Boolean;
   begin
      -- Test Set Route
      Parse_Command_JSON ("{""command"": ""set_route"", ""route"": 1}", Cmd, Succ);
      Assert (Ctx, Succ, "Parsed set_route command successfully");
      Assert (Ctx, Cmd.Kind = Cmd_Set_Route, "Command kind is Cmd_Set_Route");
      Assert (Ctx, Cmd.Route = 1, "Command route ID equals 1");

      -- Test Cancel Route
      Parse_Command_JSON ("{""command"": ""cancel_route"", ""route"": 2}", Cmd, Succ);
      Assert (Ctx, Succ, "Parsed cancel_route command successfully");
      Assert (Ctx, Cmd.Kind = Cmd_Cancel_Route, "Command kind is Cmd_Cancel_Route");
      Assert (Ctx, Cmd.Route = 2, "Command route ID equals 2");

      -- Test Manual Switch Throw
      Parse_Command_JSON ("{""command"": ""throw_switch"", ""switch"": 1, ""position"": ""REVERSE""}", Cmd, Succ);
      Assert (Ctx, Succ, "Parsed throw_switch command successfully");
      Assert (Ctx, Cmd.Kind = Cmd_Manual_Switch_Throw, "Command kind is Cmd_Manual_Switch_Throw");
      Assert (Ctx, Cmd.Sw_Id = 1, "Command switch ID equals 1");
      Assert (Ctx, Cmd.Sw_Target = Switch_Reverse, "Command target position is Switch_Reverse");

      -- Test Emergency Stop
      Parse_Command_JSON ("{""command"": ""emergency_stop""}", Cmd, Succ);
      Assert (Ctx, Succ, "Parsed emergency_stop command successfully");
      Assert (Ctx, Cmd.Kind = Cmd_Emergency_Stop_All, "Command kind is Cmd_Emergency_Stop_All");

      -- Test Invalid Command
      Parse_Command_JSON ("{""unknown_command"": 99}", Cmd, Succ);
      Assert (Ctx, not Succ, "Invalid command returns failure");
   end Test_Command_Parsing;

   ----------------------------------------------------------------------------
   -- Main Entry Point
   ----------------------------------------------------------------------------
   procedure Run_Telemetry_Tests (Overall_Passed : in out Boolean) is
      Ctx : Test_Context;
   begin
      Init_Context (Ctx, "Aspect.Telemetry (Snapshot Capture and JSON Protocol)");

      Test_Snapshot_And_JSON (Ctx);
      Test_Command_Parsing (Ctx);

      if not Summarize (Ctx) then
         Overall_Passed := False;
      end if;
   end Run_Telemetry_Tests;

end Aspect.Tests.Telemetry;
