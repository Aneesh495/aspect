-- Pre-configured railway operational scenarios and stress testing topologies.
-- Models complex junctions, high-speed 300 km/h corridors, and safety fault stress topologies.

with Aspect.Topology; use Aspect.Topology;
with Aspect.Topology.Network; use Aspect.Topology.Network;
with Aspect.Interlocking.Engine; use Aspect.Interlocking.Engine;
with Aspect.Sim.Track_Simulation; use Aspect.Sim.Track_Simulation;

package Aspect.Sim.Scenarios is

   type Scenario_Kind is (
      Scenario_Junction,      -- 4-track junction with crossovers, sidings, and flank protection
      Scenario_High_Speed,    -- 300 km/h trunk corridor with ETCS Level 2 moving supervision
      Scenario_Safety_Stress  -- Fault injection testbed (broken rail, switch stall, lamp burn)
   );

   -- Builds and configures the Grand Central Junction scenario
   procedure Build_Junction_Scenario
     (Net  : out Railway_Network;
      Core : out Interlocking_Core;
      Reg  : out Simulation_Registry);

   -- Builds and configures the High-Speed Trunk 300 scenario
   procedure Build_High_Speed_Scenario
     (Net  : out Railway_Network;
      Core : out Interlocking_Core;
      Reg  : out Simulation_Registry);

   -- Builds and configures the Safety Stress scenario
   procedure Build_Safety_Stress_Scenario
     (Net  : out Railway_Network;
      Core : out Interlocking_Core;
      Reg  : out Simulation_Registry);

end Aspect.Sim.Scenarios;
