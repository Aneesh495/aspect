-- Implementation of the simulation test suite.
-- Verifies train vehicle physics, Davis drag equation, odometry sensor fusion,
-- wheelset shunting detection, and closed-loop world step integration.

with Aspect.Types; use Aspect.Types;
with Aspect.Topology; use Aspect.Topology;
with Aspect.Interlocking; use Aspect.Interlocking;
with Aspect.Sim.Vehicle_Dynamics; use Aspect.Sim.Vehicle_Dynamics;
with Aspect.Sim.Odometry; use Aspect.Sim.Odometry;
with Aspect.Sim.Scenarios; use Aspect.Sim.Scenarios;
with Aspect.Sim.World; use Aspect.Sim.World;
with Aspect.Tests.Framework; use Aspect.Tests.Framework;

package body Aspect.Tests.Sim is

   ----------------------------------------------------------------------------
   -- Test: Vehicle Dynamics and Davis Resistance
   ----------------------------------------------------------------------------
   procedure Test_Vehicle_Dynamics (Ctx : in out Test_Context) is
      Train : Train_Vehicle;
      Dist  : Distance_M;
      Drag0, Drag20, Drag40 : Float;
   begin
      Initialize_Train (Train, 1, "Eurostar-E320", Mass => 450.0, Length_M => 200.0);
      Assert (Ctx, Train.Id = 1, "Train initialized with correct ID");
      Assert (Ctx, Train.Speed = 0.0, "Train initial speed is 0.0 m/s");

      -- Davis drag equation verification
      Drag0  := Compute_Davis_Resistance (Train, Speed => 0.0);
      Drag20 := Compute_Davis_Resistance (Train, Speed => 20.0);
      Drag40 := Compute_Davis_Resistance (Train, Speed => 40.0);

      Assert (Ctx, Drag0 = 0.0, "Drag at standstill is 0.0 kN");
      Assert (Ctx, Drag20 > 3.50, "Moving drag exceeds bearing resistance baseline");
      Assert (Ctx, Drag40 > Drag20, "Davis drag increases quadratically at 40 m/s");

      -- Throttle application and forward acceleration
      Set_Throttle (Train, Demand => 80.0);
      Assert (Ctx, Train.Throttle_Demand = 80.0, "Throttle demand set to 80%");

      Step_Dynamics
        (Train         => Train,
         Gradient      => 0.0,
         Adhesion      => 0.25,
         Delta_S       => 1.0,
         Dist_Traveled => Dist);

      Assert (Ctx, Train.Speed > 0.0, "Train accelerates forward under throttle");
      Assert (Ctx, Dist > 0.0, "Distance traversed is strictly positive");
      Assert (Ctx, Train.Acceleration > 0.0, "Train produces positive acceleration");

      -- Braking application and deceleration
      Set_Throttle (Train, Demand => 0.0);
      Set_Braking (Train, Demand => 100.0, Is_Emergency => True);
      Assert (Ctx, Train.Is_Emergency_Braking, "Emergency brake flag is asserted");

      declare
         Prev_Speed : constant Speed_Mps := Train.Speed;
      begin
         Step_Dynamics
           (Train         => Train,
            Gradient      => 0.0,
            Adhesion      => 0.25,
            Delta_S       => 1.0,
            Dist_Traveled => Dist);

         Assert (Ctx, Train.Speed < Prev_Speed, "Train decelerates under emergency braking");
         Assert (Ctx, Train.Acceleration < 0.0, "Deceleration is negative");
      end;
   end Test_Vehicle_Dynamics;

   ----------------------------------------------------------------------------
   -- Test: Odometry Sensor Fusion and Wheel Slip / Slide
   ----------------------------------------------------------------------------
   procedure Test_Odometry_Fusion (Ctx : in out Test_Context) is
      Odo : Odometry_State;
   begin
      Initialize_Odometry (Odo, Start_Km => 15.0);
      Assert (Ctx, Odo.True_Chainage = 15.0, "Initial true chainage is 15.0 km");
      Assert (Ctx, Odo.Estimated_Chainage = 15.0, "Initial estimated chainage is 15.0 km");
      Assert (Ctx, Odo.Confidence_Margin_M = 2.0, "Initial confidence margin is 2.0 m");

      -- Nominal movement: update sensors with 30 m/s for 1.0s
      Update_Sensors
        (Odo             => Odo,
         True_Speed      => 30.0,
         Is_Accelerating => False,
         Is_Braking      => False,
         Adhesion_Low    => False,
         Delta_S         => 1.0);

      Assert (Ctx, not Odo.Wheel_Slip_Detected, "Nominal adhesion reports no wheel slip");
      Assert (Ctx, not Odo.Wheel_Slide_Detected, "Nominal adhesion reports no wheel slide");
      Assert (Ctx, Odo.Estimated_Chainage > 15.0, "Estimated chainage advances forward");
      Assert
        (Ctx,
         Odo.Min_Safe_Front <= Odo.True_Chainage
           and then Odo.True_Chainage <= Odo.Max_Safe_Front,
         "True chainage is bounded by safe front confidence envelope");

      -- Low adhesion wheel slip during acceleration
      Update_Sensors
        (Odo             => Odo,
         True_Speed      => 30.0,
         Is_Accelerating => True,
         Is_Braking      => False,
         Adhesion_Low    => True,
         Delta_S         => 1.0);

      Assert (Ctx, Odo.Wheel_Slip_Detected, "Low adhesion acceleration triggers wheel slip");

      -- Low adhesion wheel slide during braking
      Update_Sensors
        (Odo             => Odo,
         True_Speed      => 25.0,
         Is_Accelerating => False,
         Is_Braking      => True,
         Adhesion_Low    => True,
         Delta_S         => 1.0);

      Assert (Ctx, Odo.Wheel_Slide_Detected, "Low adhesion braking triggers wheel slide");

      -- Eurobalise passage recalibration
      Recalibrate_At_Balise (Odo, Balise_Chainage => 15.100);
      Assert (Ctx, Odo.Estimated_Chainage = 15.100, "Balise passage recalibrates chainage exactly");
      Assert (Ctx, Odo.Confidence_Margin_M = 2.0, "Balise recalibration resets confidence margin");
   end Test_Odometry_Fusion;

   ----------------------------------------------------------------------------
   -- Test: Closed Loop Simulation World Step
   ----------------------------------------------------------------------------
   procedure Test_World_Step (Ctx : in out Test_Context) is
      World : World_Context;
   begin
      Initialize_Simulation_World (World, Scenario => Scenario_Junction);
      Assert (Ctx, World.Registry.Train_Count = 1, "Junction scenario initialized 1 train");
      Assert (Ctx, World.Sim_Time_Ms = 0, "Simulation clock starts at 0 ms");

      -- Send dispatcher route request
      Send_Dispatcher_Command
        (World,
         (Kind      => Cmd_Set_Route,
          Route     => 1,
          Sw_Id     => Null_Switch_Id,
          Sw_Target => Switch_Normal,
          Issuer_Id => 1));

      -- Advance simulation by 40 steps (2000 ms total)
      for Step in 1 .. 40 loop
         Step_Simulation (World, Delta_Ms => 50);
      end loop;

      Assert (Ctx, World.Sim_Time_Ms = 2000, "Simulation clock advances to 2000 ms");
      Assert (Ctx, World.Total_Steps = 40, "Total executed steps equals 40");
      Assert (Ctx, not World.Supervisor.Is_Halted, "2oo3 Supervisor remains healthy and running");
      Assert
        (Ctx,
         World.Registry.Trains (1).Odometry.True_Chainage >= 0.1,
         "Train 1 has advanced along designated route");
   end Test_World_Step;

   ----------------------------------------------------------------------------
   -- Main Entry Point
   ----------------------------------------------------------------------------
   procedure Run_Sim_Tests (Overall_Passed : in out Boolean) is
      Ctx : Test_Context;
   begin
      Init_Context (Ctx, "Aspect.Sim (Vehicle Dynamics, Odometry, Closed-Loop World)");

      Test_Vehicle_Dynamics (Ctx);
      Test_Odometry_Fusion (Ctx);
      Test_World_Step (Ctx);

      if not Summarize (Ctx) then
         Overall_Passed := False;
      end if;
   end Run_Sim_Tests;

end Aspect.Tests.Sim;
