-- Master package specification for the railway simulation environment.
-- Coordinates train vehicle dynamics, Davis resistance equations,
-- triple-sensor odometry fusion, and multi-train discrete event dispatching.

with Aspect.Types; use Aspect.Types;

package Aspect.Sim is

   -- Base units referenced across simulation models
   subtype Simulation_Distance is Distance_M;

   -- Standard physics simulation integration timestep in milliseconds
   Default_Sim_Step_Ms : constant Positive := 50;

end Aspect.Sim;
