-- Declarative JSON railway scenario loader and topology parser.
-- Ingests track geometry, signals, turnouts, routes, and train configurations from JSON definitions.

with Aspect.Topology.Network; use Aspect.Topology.Network;
with Aspect.Interlocking.Engine; use Aspect.Interlocking.Engine;
with Aspect.Sim.Track_Simulation; use Aspect.Sim.Track_Simulation;

package Aspect.Sim.Scenario_Loader is

   Max_Error_Len : constant := 128;
   subtype Error_String is String (1 .. Max_Error_Len);

   -- Ingests a scenario from an in-memory JSON string payload
   procedure Load_Scenario_From_JSON
     (JSON_Text : String;
      Net       : out Railway_Network;
      Core      : out Interlocking_Core;
      Reg       : out Simulation_Registry;
      Success   : out Boolean;
      Error_Msg : out Error_String);

   -- Reads and ingests a scenario from a file on disk
   procedure Load_Scenario_From_File
     (File_Path : String;
      Net       : out Railway_Network;
      Core      : out Interlocking_Core;
      Reg       : out Simulation_Registry;
      Success   : out Boolean;
      Error_Msg : out Error_String);

end Aspect.Sim.Scenario_Loader;
