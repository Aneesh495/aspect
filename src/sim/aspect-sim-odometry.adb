package body Aspect.Sim.Odometry is

   procedure Initialize_Odometry
     (Odo      : out Odometry_State;
      Start_Km : Track_Chainage)
   is
   begin
      Odo.True_Chainage        := Start_Km;
      Odo.True_Speed           := 0.0;
      Odo.Estimated_Chainage   := Start_Km;
      Odo.Estimated_Speed      := 0.0;
      Odo.Min_Safe_Front       := Start_Km;
      Odo.Max_Safe_Front       := Start_Km;
      Odo.Confidence_Margin_M  := 2.0;
      Odo.APG1_Speed           := 0.0;
      Odo.APG2_Speed           := 0.0;
      Odo.Doppler_Speed        := 0.0;
      Odo.Wheel_Slip_Detected  := False;
      Odo.Wheel_Slide_Detected := False;
      Odo.Sensors_Healthy      := True;
   end Initialize_Odometry;

   procedure Update_Sensors
     (Odo             : in out Odometry_State;
      True_Speed      : Speed_Mps;
      Is_Accelerating : Boolean;
      Is_Braking      : Boolean;
      Adhesion_Low    : Boolean;
      Delta_S         : Float)
   is
      V_Float : constant Float := Float (True_Speed);
      V_Apg1  : Float := V_Float;
      V_Apg2  : Float := V_Float;
      V_Radar : Float := V_Float;
      V_Fused : Float;
      D_Inc   : Float;
   begin
      Odo.True_Speed := True_Speed;

      -- Simulate wheel spin during high acceleration under degraded adhesion
      if Adhesion_Low and then Is_Accelerating and then V_Float > 1.0 then
         V_Apg1 := V_Float * 1.15;
         V_Apg2 := V_Float * 1.12;
         Odo.Wheel_Slip_Detected := True;
      else
         Odo.Wheel_Slip_Detected := False;
      end if;

      -- Simulate wheel lock / slide during heavy braking under degraded adhesion
      if Adhesion_Low and then Is_Braking and then V_Float > 1.0 then
         V_Apg1 := V_Float * 0.80;
         V_Apg2 := V_Float * 0.85;
         Odo.Wheel_Slide_Detected := True;
      else
         Odo.Wheel_Slide_Detected := False;
      end if;

      -- Doppler radar measures true track bed velocity (non-contact)
      V_Radar := V_Float;

      Odo.APG1_Speed    := Speed_Mps (V_Apg1);
      Odo.APG2_Speed    := Speed_Mps (V_Apg2);
      Odo.Doppler_Speed := Speed_Mps (V_Radar);

      -- Sensor fusion logic: If wheel tachometers diverge from radar, trust radar ground speed
      if Odo.Wheel_Slip_Detected or else Odo.Wheel_Slide_Detected then
         V_Fused := V_Radar;
      else
         V_Fused := (V_Apg1 + V_Apg2 + V_Radar) / 3.0;
      end if;

      Odo.Estimated_Speed := Speed_Mps (V_Fused);

      -- Integrate positions
      D_Inc := V_Float * Delta_S;
      Odo.True_Chainage := Odo.True_Chainage + Track_Chainage (D_Inc);

      declare
         D_Est_Inc : constant Float := V_Fused * Delta_S;
      begin
         Odo.Estimated_Chainage := Odo.Estimated_Chainage + Track_Chainage (D_Est_Inc);

         -- Accumulate 1% distance uncertainty drift (Subset-026 Section 3.6.4)
         Odo.Confidence_Margin_M :=
           Distance_M (Float (Odo.Confidence_Margin_M) + (0.01 * D_Est_Inc));
      end;

      -- Compute minimum and maximum safe front boundaries
      declare
         Margin_Km : constant Track_Chainage := Track_Chainage (Odo.Confidence_Margin_M);
      begin
         if Odo.Estimated_Chainage > Margin_Km then
            Odo.Min_Safe_Front := Odo.Estimated_Chainage - Margin_Km;
         else
            Odo.Min_Safe_Front := 0.0;
         end if;
         Odo.Max_Safe_Front := Odo.Estimated_Chainage + Margin_Km;
      end;
   end Update_Sensors;

   procedure Recalibrate_At_Balise
     (Odo             : in out Odometry_State;
      Balise_Chainage : Track_Chainage)
   is
   begin
      -- Balise passage eliminates accumulated wheel odometer distance drift
      Odo.Estimated_Chainage  := Balise_Chainage;
      Odo.Confidence_Margin_M := 2.0; -- Reset confidence error to antenna baseline 2.0m
      Odo.Min_Safe_Front      := Balise_Chainage - 2.0;
      Odo.Max_Safe_Front      := Balise_Chainage + 2.0;
   end Recalibrate_At_Balise;

end Aspect.Sim.Odometry;
