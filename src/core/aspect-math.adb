with Ada.Numerics.Elementary_Functions;

package body Aspect.Math is

   package EF renames Ada.Numerics.Elementary_Functions;

   ----------------------------------------------------------------------------
   -- Kinematic Deceleration and Distance Calculations
   ----------------------------------------------------------------------------

   function Stopping_Distance
     (V0 : Speed_Mps;
      A  : Deceleration_Mps2) return Distance_M
   is
      V_Float : constant Float := Float (V0);
      A_Float : constant Float := Float (A);
      D_Raw   : Float;
   begin
      if V_Float <= 0.0 then
         return 0.0;
      end if;
      D_Raw := (V_Float * V_Float) / (2.0 * A_Float);
      if D_Raw > 100_000.0 then
         return 100_000.0;
      else
         return Distance_M (D_Raw);
      end if;
   end Stopping_Distance;

   function Deceleration_Distance
     (V0 : Speed_Mps;
      V1 : Speed_Mps;
      A  : Deceleration_Mps2) return Distance_M
   is
      V0_F  : constant Float := Float (V0);
      V1_F  : constant Float := Float (V1);
      A_F   : constant Float := Float (A);
      D_Raw : Float;
   begin
      if V0_F <= V1_F then
         return 0.0;
      end if;
      D_Raw := (V0_F * V0_F - V1_F * V1_F) / (2.0 * A_F);
      if D_Raw > 100_000.0 then
         return 100_000.0;
      elsif D_Raw < 0.0 then
         return 0.0;
      else
         return Distance_M (D_Raw);
      end if;
   end Deceleration_Distance;

   function Safe_Speed_At_Distance
     (V_Target : Speed_Mps;
      Distance : Distance_M;
      A        : Deceleration_Mps2) return Speed_Mps
   is
      Vt_F  : constant Float := Float (V_Target);
      D_F   : constant Float := Float (Distance);
      A_F   : constant Float := Float (A);
      V2    : constant Float := Vt_F * Vt_F + 2.0 * A_F * D_F;
      Speed : Float;
   begin
      if V2 <= 0.0 then
         return 0.0;
      end if;
      Speed := EF.Sqrt (V2);
      if Speed > 140.0 then
         return 140.0;
      else
         return Speed_Mps (Speed);
      end if;
   end Safe_Speed_At_Distance;

   ----------------------------------------------------------------------------
   -- Railway Environmental & Train Physics Corrections
   ----------------------------------------------------------------------------

   function Gradient_Acceleration
     (Gradient : Gradient_Per_Mille) return Acceleration_Mps2
   is
      -- 1 per mille = 0.001 tangent slope
      -- g_component = Standard_Gravity * (Gradient / 1000.0)
      G_Float : constant Float := Float (Gradient);
      A_Grad  : constant Float := Standard_Gravity * (G_Float / 1000.0);
   begin
      if A_Grad > 15.0 then
         return 15.0;
      elsif A_Grad < -15.0 then
         return -15.0;
      else
         return Acceleration_Mps2 (A_Grad);
      end if;
   end Gradient_Acceleration;

   function Composite_Deceleration
     (A_Nominal     : Deceleration_Mps2;
      Gradient      : Gradient_Per_Mille;
      Adhesion      : Adhesion_Factor;
      Rotating_Mass : Percent) return Deceleration_Mps2
   is
      A_Nom_F   : constant Float := Float (A_Nominal);
      Adh_F     : constant Float := Float (Adhesion);
      Rot_F     : constant Float := 1.0 + (Float (Rotating_Mass) / 100.0);
      A_Grad    : constant Float := Float (Gradient_Acceleration (Gradient));
      
      -- Braking deceleration aided by uphill (+), degraded by downhill (-)
      A_Eff     : Float := (A_Nom_F * Adh_F + A_Grad) / Rot_F;
   begin
      -- Must remain strictly non-negative; minimum residual drag
      if A_Eff < 0.05 then
         A_Eff := 0.05;
      elsif A_Eff > 15.0 then
         A_Eff := 15.0;
      end if;
      return Deceleration_Mps2 (A_Eff);
   end Composite_Deceleration;

   ----------------------------------------------------------------------------
   -- Safe Clamped Numeric Operations
   ----------------------------------------------------------------------------

   function Clamp_Float (Val : Float; Low : Float; High : Float) return Float is
   begin
      if Val < Low then
         return Low;
      elsif Val > High then
         return High;
      else
         return Val;
      end if;
   end Clamp_Float;

   function Linear_Interp
     (X, X0, X1, Y0, Y1 : Float) return Float
   is
      T : constant Float := (X - X0) / (X1 - X0);
   begin
      return Y0 + T * (Y1 - Y0);
   end Linear_Interp;

   function Sqrt (Value : Float) return Float is
   begin
      return EF.Sqrt (Value);
   end Sqrt;

end Aspect.Math;
