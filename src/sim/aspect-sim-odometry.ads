-- On-board odometry sensor fusion and position estimation.
-- Fuses dual axle pulse tachometers with Doppler radar ground speed,
-- detects wheel slip and slide, and recalibrates upon Eurobalise group passage.

with Aspect.Topology; use Aspect.Topology;

package Aspect.Sim.Odometry is

   type Odometry_State is record
      -- Physical ground truth position
      True_Chainage        : Track_Chainage  := 0.0;
      True_Speed           : Speed_Mps       := 0.0;

      -- Fused On-Board Estimator
      Estimated_Chainage   : Track_Chainage  := 0.0;
      Estimated_Speed      : Speed_Mps       := 0.0;
      Min_Safe_Front       : Track_Chainage  := 0.0;
      Max_Safe_Front       : Track_Chainage  := 0.0;
      Confidence_Margin_M  : Distance_M      := 5.0;

      -- Raw Sensor Channels
      APG1_Speed           : Speed_Mps       := 0.0;
      APG2_Speed           : Speed_Mps       := 0.0;
      Doppler_Speed        : Speed_Mps       := 0.0;

      -- Slip and Slide Flags
      Wheel_Slip_Detected  : Boolean         := False;
      Wheel_Slide_Detected : Boolean         := False;
      Sensors_Healthy      : Boolean         := True;
   end record;

   procedure Initialize_Odometry
     (Odo      : out Odometry_State;
      Start_Km : Track_Chainage);

   -- Integrates sensor measurements over time step Delta_S
   procedure Update_Sensors
     (Odo             : in out Odometry_State;
      True_Speed      : Speed_Mps;
      Is_Accelerating : Boolean;
      Is_Braking      : Boolean;
      Adhesion_Low    : Boolean;
      Delta_S         : Float);

   -- Recalibrates estimated chainage upon passing an active balise group
   procedure Recalibrate_At_Balise
     (Odo             : in out Odometry_State;
      Balise_Chainage : Track_Chainage);

end Aspect.Sim.Odometry;
