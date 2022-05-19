-- Implementation of CLI argument parser.

with Ada.Command_Line;
with Ada.Text_IO; use Ada.Text_IO;

package body Aspect.CLI is

   procedure Print_Version is
   begin
      Put_Line ("Aspect Railway Vital Interlocking & ETCS Level 2 Kernel");
      Put_Line ("Version: 1.0.0 (Standards: EN 50128 SIL 4, ERA ETCS Subset-026)");
      Put_Line ("Architecture: 2-out-of-3 (2oo3) Triple-Modular Redundant Vital Executive");
      Put_Line ("Copyright (C) 2026. Distributed under the MIT License.");
   end Print_Version;

   procedure Print_Usage is
   begin
      Put_Line ("Usage: aspect [OPTIONS]");
      New_Line;
      Put_Line ("Options:");
      Put_Line ("  --scenario <name>   Simulation topology: junction (default), high_speed, safety_stress");
      Put_Line ("  --tui               Run full-screen interactive ANSI terminal UI (default)");
      Put_Line ("  --headless          Run headless without TUI (suitable for servers and benchmarks)");
      Put_Line ("  --port <number>     Telemetry TCP broadcast server port (default: 9002)");
      Put_Line ("  --ticks <count>     Terminate after specified simulation steps (default: 0 = continuous)");
      Put_Line ("  --delta <ms>        Physics integration timestep in milliseconds (default: 50)");
      Put_Line ("  --version, -v       Display version and safety certification metadata");
      Put_Line ("  --help, -h          Display this help message and exit");
      New_Line;
      Put_Line ("Examples:");
      Put_Line ("  ./bin/aspect --scenario junction --tui");
      Put_Line ("  ./bin/aspect --scenario high_speed --port 9002 --headless");
      Put_Line ("  ./bin/aspect --scenario safety_stress --ticks 1000 --headless");
   end Print_Usage;

   procedure Parse_Arguments
     (Config      : out CLI_Config;
      Should_Exit : out Boolean)
   is
      Arg_Count : constant Natural := Ada.Command_Line.Argument_Count;
      Idx       : Positive := 1;
   begin
      Config      := (others => <>);
      Should_Exit := False;

      while Idx <= Arg_Count loop
         declare
            Arg : constant String := Ada.Command_Line.Argument (Idx);
         begin
            if Arg = "--help" or else Arg = "-h" then
               Print_Usage;
               Should_Exit := True;
               return;
            elsif Arg = "--version" or else Arg = "-v" then
               Print_Version;
               Should_Exit := True;
               return;
            elsif Arg = "--tui" then
               Config.Mode := Mode_Interactive_TUI;
            elsif Arg = "--headless" then
               Config.Mode := Mode_Headless_Server;
            elsif Arg = "--scenario" then
               if Idx < Arg_Count then
                  Idx := Idx + 1;
                  declare
                     Scen_Str : constant String := Ada.Command_Line.Argument (Idx);
                  begin
                     if Scen_Str = "junction" then
                        Config.Scenario := Scenario_Junction;
                     elsif Scen_Str = "high_speed" then
                        Config.Scenario := Scenario_High_Speed;
                     elsif Scen_Str = "safety_stress" then
                        Config.Scenario := Scenario_Safety_Stress;
                     else
                        Put_Line ("Unknown scenario: " & Scen_Str);
                        Print_Usage;
                        Should_Exit := True;
                        return;
                     end if;
                  end;
               else
                  Put_Line ("Error: --scenario requires an argument.");
                  Should_Exit := True;
                  return;
               end if;
            elsif Arg = "--port" then
               if Idx < Arg_Count then
                  Idx := Idx + 1;
                  Config.Telemetry_Port := Positive'Value (Ada.Command_Line.Argument (Idx));
               else
                  Put_Line ("Error: --port requires a port number.");
                  Should_Exit := True;
                  return;
               end if;
            elsif Arg = "--ticks" then
               if Idx < Arg_Count then
                  Idx := Idx + 1;
                  Config.Max_Ticks := Natural'Value (Ada.Command_Line.Argument (Idx));
               else
                  Put_Line ("Error: --ticks requires a count.");
                  Should_Exit := True;
                  return;
               end if;
            elsif Arg = "--delta" then
               if Idx < Arg_Count then
                  Idx := Idx + 1;
                  Config.Tick_Delta_Ms := Positive'Value (Ada.Command_Line.Argument (Idx));
               else
                  Put_Line ("Error: --delta requires a millisecond value.");
                  Should_Exit := True;
                  return;
               end if;
            else
               Put_Line ("Unrecognized option: " & Arg);
               Print_Usage;
               Should_Exit := True;
               return;
            end if;
         end;
         Idx := Idx + 1;
      end loop;
   end Parse_Arguments;

end Aspect.CLI;
