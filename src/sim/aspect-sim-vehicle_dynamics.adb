with Aspect.Math; use Aspect.Math;

package body Aspect.Sim.Vehicle_Dynamics is

   procedure Initialize_Train
     (Train    : out Train_Vehicle;
      Id       : Train_Id;
      Name     : String;
      Mass     : Mass_Tonnes := 450.0;
      Length_M : Distance_M  := 200.0)
   is
      Len : constant Natural := Natural'Min (Name'Length, 16);
   begin
      Train.Id                   := Id;
      Train.Name                 := [others => ' '];
      Train.Name (1 .. Len)      := Name (Name'First .. Name'First + Len - 1);
      Train.Name_Len             := Len;
      Train.Total_Mass_Tonnes    := Mass;
      Train.Length_M             := Length_M;
      Train.Rotating_Mass_Factor := 12.0;

      Train.Max_Tractive_KN       := 300.0;
      Train.Max_Power_KW          := 8800.0;
      Train.Max_Service_Brake_KN  := 380.0;
      Train.Max_Emergency_Brake_KN:= 520.0;
      Train.Brake_Lag_Tau_S       := 1.80;

      Train.Davis                := (others => <>);
      Train.Speed                := 0.0;
      Train.Acceleration         := 0.0;
      Train.Throttle_Demand      := 0.0;
      Train.Brake_Demand         := 0.0;
      Train.Is_Emergency_Braking := False;
      Train.Actual_Brake_KN      := 0.0;
      Train.Wheel_Slide_Detected := False;
   end Initialize_Train;

   function Compute_Davis_Resistance
     (Train : Train_Vehicle;
      Speed : Speed_Mps) return Float
   is
      V : constant Float := Float (Speed);
   begin
      if V <= 0.01 then
         return 0.0;
      end if;
      return Train.Davis.A_Mechanical_KN
           + (Train.Davis.B_Flange_KN_Per_V * V)
           + (Train.Davis.C_Aero_KN_Per_V2 * V * V);
   end Compute_Davis_Resistance;

   procedure Set_Throttle
     (Train  : in out Train_Vehicle;
      Demand : Percent)
   is
   begin
      Train.Throttle_Demand      := Demand;
      Train.Brake_Demand         := 0.0;
      Train.Is_Emergency_Braking := False;
   end Set_Throttle;

   procedure Set_Braking
     (Train        : in out Train_Vehicle;
      Demand       : Percent;
      Is_Emergency : Boolean := False)
   is
   begin
      Train.Brake_Demand         := Demand;
      Train.Is_Emergency_Braking := Is_Emergency;
      Train.Throttle_Demand      := 0.0;
   end Set_Braking;

   procedure Step_Dynamics
     (Train        : in out Train_Vehicle;
      Gradient     : Gradient_Per_Mille;
      Adhesion     : Adhesion_Factor;
      Delta_S      : Float;
      Dist_Traveled: out Distance_M)
   is
      V_Curr : constant Float := Float (Train.Speed);
      M_Kg   : constant Float := Float (Train.Total_Mass_Tonnes) * 1000.0;
      M_Eff  : constant Float := M_Kg * (1.0 + (Float (Train.Rotating_Mass_Factor) / 100.0));

      F_Tractive_KN : Float := 0.0;
      F_Target_Brake: Float := 0.0;
      F_Davis_KN    : constant Float := Compute_Davis_Resistance (Train, Train.Speed);
      F_Grad_KN     : Float;
      F_Net_KN      : Float;
      A_Mps2        : Float;
      V_New         : Float;
      V_Avg         : Float;
   begin
      -- 1. Compute tractive effort (constant force below base speed, constant power above)
      if Train.Throttle_Demand > 0.0 then
         declare
            Throttle_Ratio : constant Float := Float (Train.Throttle_Demand) / 100.0;
            Avail_Force_KN : Float          := Train.Max_Tractive_KN;
         begin
            if V_Curr > 5.0 then
               -- P = F * v => F = P / v
               declare
                  Power_Limit_KN : constant Float := Train.Max_Power_KW / V_Curr;
               begin
                  if Power_Limit_KN < Avail_Force_KN then
                     Avail_Force_KN := Power_Limit_KN;
                  end if;
               end;
            end if;
            F_Tractive_KN := Avail_Force_KN * Throttle_Ratio;
         end;
      end if;

      -- 2. Compute braking demand
      if Train.Is_Emergency_Braking then
         F_Target_Brake := Train.Max_Emergency_Brake_KN;
      elsif Train.Brake_Demand > 0.0 then
         F_Target_Brake := Train.Max_Service_Brake_KN * (Float (Train.Brake_Demand) / 100.0);
      else
         F_Target_Brake := 0.0;
      end if;

      -- Pneumatic brake cylinder pressure buildup lag:
      -- dF/dt = (F_target - F_actual) / tau
      declare
         Alpha : constant Float := Delta_S / (Train.Brake_Lag_Tau_S + Delta_S);
      begin
         Train.Actual_Brake_KN := Train.Actual_Brake_KN + Alpha * (F_Target_Brake - Train.Actual_Brake_KN);
      end;

      -- Adhesion limit check: F_adh = mu * m * g
      declare
         Max_Adh_KN : constant Float :=
           (Float (Adhesion) * (Float (Train.Total_Mass_Tonnes) * Standard_Gravity));
      begin
         if Train.Actual_Brake_KN > Max_Adh_KN then
            Train.Actual_Brake_KN      := Max_Adh_KN;
            Train.Wheel_Slide_Detected := True;
         else
            Train.Wheel_Slide_Detected := False;
         end if;
      end;

      -- 3. Gradient gravity force: positive uphill slows train, negative downhill accelerates
      -- F_grad = - M * g * (Gradient / 1000.0) in kN
      F_Grad_KN := -(Float (Train.Total_Mass_Tonnes) * Standard_Gravity * (Float (Gradient) / 1000.0));

      -- 4. Net force: Tractive - Braking - Davis_drag + Gradient
      if V_Curr > 0.01 then
         F_Net_KN := F_Tractive_KN - Train.Actual_Brake_KN - F_Davis_KN + F_Grad_KN;
      else
         -- Standstill: brake and drag cannot push train backwards
         F_Net_KN := F_Tractive_KN + F_Grad_KN;
         if Train.Actual_Brake_KN > abs (F_Grad_KN) and then F_Tractive_KN = 0.0 then
            F_Net_KN := 0.0;
         end if;
      end if;

      -- 5. Kinematic integration
      -- F in kN = 1000 N, M in kg => a = (F * 1000) / M_eff
      A_Mps2 := (F_Net_KN * 1000.0) / M_Eff;

      if A_Mps2 > 15.0 then
         A_Mps2 := 15.0;
      elsif A_Mps2 < -15.0 then
         A_Mps2 := -15.0;
      end if;

      V_New := V_Curr + (A_Mps2 * Delta_S);
      if V_New < 0.0 then
         V_New  := 0.0;
         A_Mps2 := 0.0;
      elsif V_New > 140.0 then
         V_New := 140.0;
      end if;

      V_Avg := (V_Curr + V_New) / 2.0;
      Dist_Traveled := Distance_M (Float'Max (0.0, V_Avg * Delta_S));

      Train.Speed        := Speed_Mps (V_New);
      Train.Acceleration := Acceleration_Mps2 (A_Mps2);
   end Step_Dynamics;

end Aspect.Sim.Vehicle_Dynamics;
