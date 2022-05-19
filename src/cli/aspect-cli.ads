-- Command-line interface argument parser and runtime configuration.
-- Configures simulation scenarios, interactive TUI mode, telemetry ports,
-- and headless batch execution limits.

with Aspect.Sim.Scenarios; use Aspect.Sim.Scenarios;

package Aspect.CLI is

   type Run_Mode is (
      Mode_Interactive_TUI,   -- Full ANSI terminal user interface with live diagrams
      Mode_Headless_Server    -- High-throughput headless simulation with telemetry broadcast
   );

   type CLI_Config is record
      Scenario         : Scenario_Kind := Scenario_Junction;
      Mode             : Run_Mode      := Mode_Interactive_TUI;
      Telemetry_Port   : Positive      := 9002;
      Max_Ticks        : Natural       := 0; -- 0 means run continuously until user quit
      Tick_Delta_Ms    : Positive      := 50;
      Speed_Multiplier : Float         := 1.0;
   end record;

   -- Parses command line arguments from Ada.Command_Line
   procedure Parse_Arguments
     (Config      : out CLI_Config;
      Should_Exit : out Boolean);

   -- Prints CLI usage help and options
   procedure Print_Usage;

   -- Prints system version and standard compliance banner
   procedure Print_Version;

end Aspect.CLI;
