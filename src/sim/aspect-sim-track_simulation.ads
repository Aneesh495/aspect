-- Multi-train track block simulation and wheelset shunting supervisor.
-- Maps continuous spatial train positions to discrete track circuits,
-- detects balise antenna crossings, and triggers sectional route release events.

with Aspect.Topology; use Aspect.Topology;
with Aspect.Topology.Network; use Aspect.Topology.Network;
with Aspect.Interlocking.Engine; use Aspect.Interlocking.Engine;
with Aspect.Sim.Vehicle_Dynamics; use Aspect.Sim.Vehicle_Dynamics;
with Aspect.Sim.Odometry; use Aspect.Sim.Odometry;

package Aspect.Sim.Track_Simulation is

   type Simulated_Train is record
      Id                  : Train_Id_Base    := Null_Train_Id;
      Vehicle             : Train_Vehicle;
      Odometry            : Odometry_State;
      Current_Section     : Section_Id_Base  := Null_Section_Id;
      Rear_Section        : Section_Id_Base  := Null_Section_Id;
      Is_Active           : Boolean          := False;
   end record;

   type Simulated_Train_Array is array (Train_Id) of Simulated_Train;

   type Simulation_Registry is record
      Trains       : Simulated_Train_Array := [others => <>];
      Train_Count  : Natural               := 0;
   end record;

   procedure Initialize_Registry (Reg : out Simulation_Registry);

   procedure Add_Train
     (Reg      : in out Simulation_Registry;
      Train    : Train_Vehicle;
      Start_Km : Track_Chainage;
      Start_Sec: Section_Id);

   -- Advances train position, updates wheelset shunting on track circuits,
   -- and notifies interlocking engine of sectional block entries and exits
   procedure Update_Train_Positions
     (Reg      : in out Simulation_Registry;
      Net      : in out Railway_Network;
      Core     : in out Interlocking_Core;
      Delta_S  : Float);

end Aspect.Sim.Track_Simulation;
