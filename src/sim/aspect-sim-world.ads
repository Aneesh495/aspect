-- Master railway simulation world coordinator.
-- Integrates the 2oo3 vital executive, Radio Block Centre, track topology,
-- and train physics in a deterministic closed loop.

with Aspect.Topology.Network; use Aspect.Topology.Network;
with Aspect.Interlocking; use Aspect.Interlocking;
with Aspect.Vital.Cyclic_Executive; use Aspect.Vital.Cyclic_Executive;
with Aspect.ETCS.RBC; use Aspect.ETCS.RBC;
with Aspect.Sim.Track_Simulation; use Aspect.Sim.Track_Simulation;
with Aspect.Sim.Scenarios; use Aspect.Sim.Scenarios;

package Aspect.Sim.World is

   type World_Context is record
      Net              : Railway_Network;
      Supervisor       : Vital_Supervisor;
      RBC              : Radio_Block_Centre;
      Registry         : Simulation_Registry;
      Scenario         : Scenario_Kind := Scenario_Junction;
      Sim_Time_Ms      : Natural       := 0;
      Total_Steps      : Natural       := 0;
   end record;

   procedure Initialize_Simulation_World
     (World    : out World_Context;
      Scenario : Scenario_Kind := Scenario_Junction);

   -- Advances the entire simulation world by Delta_Ms (typically 50ms)
   procedure Step_Simulation
     (World    : in out World_Context;
      Delta_Ms : Positive := Default_Sim_Step_Ms);

   -- Ingests dispatcher command into the vital executive
   procedure Send_Dispatcher_Command
     (World : in out World_Context;
      Cmd   : Interlocking_Command);

end Aspect.Sim.World;
