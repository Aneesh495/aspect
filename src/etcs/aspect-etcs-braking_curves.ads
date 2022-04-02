-- ERA ETCS Subset-026 Chapter 3.13 dynamic speed profiles and braking curves.
-- Computes Emergency Brake Intervention (EBI), Service Brake Intervention (SBI),
-- Warning (W), Permitted Speed (P), Indication (I), and release speed supervisory envelopes.

package Aspect.ETCS.Braking_Curves is

   type Supervision_State is (
      Status_Normal,               -- Train within permitted speed boundary
      Status_Indication,           -- Approaching target deceleration curve
      Status_Overspeed_Warning,     -- Audio/visual alarm; driver must apply brakes
      Status_Service_Intervention, -- Automatic full service brake application
      Status_Emergency_Trip        -- Irrevocable emergency brake application to stop
   );

   type Train_Brake_Parameters is record
      Nominal_Emergency_A : Deceleration_Mps2  := 1.20; -- m/s^2
      Nominal_Service_A   : Deceleration_Mps2  := 0.85; -- m/s^2
      Emergency_Lag_S     : Float              := 1.50; -- t_ebi pneumatic propagation
      Service_Lag_S       : Float              := 2.50; -- t_sbi pneumatic propagation
      Warning_Time_S      : Float              := 2.00; -- t_warning acoustic buffer
      Driver_Reaction_S   : Float              := 4.00; -- t_driver cognitive delay
      Adhesion            : Adhesion_Factor    := 1.00; -- Dry rail adhesion factor
      Rotating_Mass       : Percent            := 12.0; -- 12% kinetic rotating inertia
      Gradient            : Gradient_Per_Mille := 0.0;  -- Track gradient
   end record;

   type Supervision_Envelope is record
      Distance_To_Target  : Distance_M        := 0.0;
      Target_Speed        : Speed_Kph         := 0.0;
      Ceiling_Speed       : Speed_Kph         := 160.0;
      Indication_Speed    : Speed_Kph         := 160.0;
      Permitted_Speed     : Speed_Kph         := 160.0;
      Warning_Speed       : Speed_Kph         := 160.0;
      SBI_Speed           : Speed_Kph         := 160.0;
      EBI_Speed           : Speed_Kph         := 160.0;
      Release_Speed       : Speed_Kph         := 25.0;
      Current_Status      : Supervision_State := Status_Normal;
   end record;

   -- Computes the dynamic speed profile at current distance from target
   procedure Calculate_Envelopes
     (Params         : Train_Brake_Parameters;
      Current_Speed  : Speed_Kph;
      Distance_To_EoA: Distance_M;
      Distance_To_SvL: Distance_M;
      Target_Speed   : Speed_Kph;
      Ceiling_Speed  : Speed_Kph;
      Envelope       : out Supervision_Envelope);

   -- Evaluates current speed against computed supervisory envelopes
   function Evaluate_State
     (Current_Speed : Speed_Kph;
      Envelope      : Supervision_Envelope) return Supervision_State;

end Aspect.ETCS.Braking_Curves;
