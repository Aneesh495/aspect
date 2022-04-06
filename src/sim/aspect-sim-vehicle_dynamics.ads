-- High-fidelity train vehicle dynamics and tractive-braking physics.
-- Implements the empirical Davis resistance equation, electric motor tractive effort curves,
-- pneumatic brake propagation delays, and wheel adhesion limits.

package Aspect.Sim.Vehicle_Dynamics is

   type Davis_Coefficients is record
      A_Mechanical_KN   : Float := 3.50;  -- Rolling and bearing resistance (kN)
      B_Flange_KN_Per_V : Float := 0.08;  -- Flange contact and side turbulence (kN/(m/s))
      C_Aero_KN_Per_V2  : Float := 0.007; -- Aerodynamic head/tail form drag (kN/(m/s)^2)
   end record;

   type Train_Vehicle is record
      Id                   : Train_Id_Base    := Null_Train_Id;
      Name                 : String (1 .. 16) := [others => ' '];
      Name_Len             : Natural          := 0;

      -- Mass and Geometry
      Total_Mass_Tonnes    : Mass_Tonnes      := 450.0;
      Length_M             : Distance_M       := 200.0;
      Rotating_Mass_Factor : Percent          := 12.0; -- 12% kinetic wheelset inertia

      -- Propulsion and Braking Ratings
      Max_Tractive_KN      : Float            := 300.0;
      Max_Power_KW         : Float            := 8800.0;
      Max_Service_Brake_KN : Float            := 380.0;
      Max_Emergency_Brake_KN: Float           := 520.0;
      Brake_Lag_Tau_S      : Float            := 1.80;  -- Pneumatic pipe build-up delay

      Davis                : Davis_Coefficients;

      -- Instantaneous Dynamic State
      Speed                : Speed_Mps         := 0.0;
      Acceleration         : Acceleration_Mps2 := 0.0;
      Throttle_Demand      : Percent           := 0.0;
      Brake_Demand         : Percent           := 0.0;
      Is_Emergency_Braking : Boolean           := False;
      Actual_Brake_KN      : Float             := 0.0;
      Wheel_Slide_Detected : Boolean           := False;
   end record;

   procedure Initialize_Train
     (Train       : out Train_Vehicle;
      Id          : Train_Id;
      Name        : String;
      Mass        : Mass_Tonnes := 450.0;
      Length_M    : Distance_M  := 200.0);

   -- Computes total Davis resistance force in kilonewtons (kN)
   function Compute_Davis_Resistance
     (Train : Train_Vehicle;
      Speed : Speed_Mps) return Float with
     Post => Compute_Davis_Resistance'Result >= 0.0;

   -- Commands tractive motor throttle (0% to 100%)
   procedure Set_Throttle
     (Train   : in out Train_Vehicle;
      Demand  : Percent);

   -- Commands service brake or emergency brake (0% to 100%)
   procedure Set_Braking
     (Train        : in out Train_Vehicle;
      Demand       : Percent;
      Is_Emergency : Boolean := False);

   -- Integrates vehicle physics across time step Delta_S (seconds)
   procedure Step_Dynamics
     (Train       : in out Train_Vehicle;
      Gradient    : Gradient_Per_Mille;
      Adhesion    : Adhesion_Factor;
      Delta_S     : Float;
      Dist_Traveled: out Distance_M);

end Aspect.Sim.Vehicle_Dynamics;
