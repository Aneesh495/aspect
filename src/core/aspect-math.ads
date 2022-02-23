-- Mathematical foundations and kinematic solvers for Aspect.
-- Implements safe arithmetic, gradient compensation, kinematic braking distances,
-- and piecewise deceleration profile interpolations.

with Aspect.Types; use Aspect.Types;

package Aspect.Math with
   Pure
is

   -- Standard gravitational acceleration in meters per second squared
   Standard_Gravity : constant Float := 9.80665;

   ----------------------------------------------------------------------------
   -- Kinematic Deceleration and Distance Calculations
   ----------------------------------------------------------------------------

   -- Computes required stopping distance given initial speed and constant deceleration:
   -- d = v^2 / (2 * a)
   function Stopping_Distance
     (V0 : Speed_Mps;
      A  : Deceleration_Mps2) return Distance_M with
     Pre  => A > 0.0,
     Post => Stopping_Distance'Result >= 0.0;

   -- Computes braking distance between an initial speed V0 and target speed V1:
   -- d = (V0^2 - V1^2) / (2 * a)
   function Deceleration_Distance
     (V0 : Speed_Mps;
      V1 : Speed_Mps;
      A  : Deceleration_Mps2) return Distance_M with
     Pre  => V0 >= V1 and A > 0.0,
     Post => Deceleration_Distance'Result >= 0.0;

   -- Computes the maximum safe speed that allows decelerating to target speed V_Target
   -- over distance D under deceleration A:
   -- v = sqrt(V_Target^2 + 2 * a * d)
   function Safe_Speed_At_Distance
     (V_Target : Speed_Mps;
      Distance : Distance_M;
      A        : Deceleration_Mps2) return Speed_Mps with
     Pre  => A >= 0.0,
     Post => Safe_Speed_At_Distance'Result >= V_Target;

   ----------------------------------------------------------------------------
   -- Railway Environmental & Train Physics Corrections
   ----------------------------------------------------------------------------

   -- Computes effective gravitational acceleration component due to track gradient.
   -- Gradient in per mille: positive is uphill (+ aids braking), negative is downhill.
   -- Returns acceleration component in m/s^2.
   function Gradient_Acceleration
     (Gradient : Gradient_Per_Mille) return Acceleration_Mps2;

   -- Computes composite deceleration incorporating base brake power, track gradient,
   -- rotating mass factor, and wheel-rail adhesion coefficient:
   -- a_eff = (a_nominal * K_adh + a_gradient) / (1.0 + rotating_mass_factor)
   function Composite_Deceleration
     (A_Nominal      : Deceleration_Mps2;
      Gradient       : Gradient_Per_Mille;
      Adhesion       : Adhesion_Factor;
      Rotating_Mass  : Percent) return Deceleration_Mps2 with
     Pre => Rotating_Mass >= 0.0 and Rotating_Mass <= 50.0;

   ----------------------------------------------------------------------------
   -- Safe Clamped Numeric Operations
   ----------------------------------------------------------------------------

   function Clamp_Float (Val : Float; Low : Float; High : Float) return Float with
     Pre  => Low <= High,
     Post => Clamp_Float'Result >= Low and Clamp_Float'Result <= High;

   function Min_Distance (D1 : Distance_M; D2 : Distance_M) return Distance_M is
     (if D1 < D2 then D1 else D2);

   function Max_Distance (D1 : Distance_M; D2 : Distance_M) return Distance_M is
     (if D1 > D2 then D1 else D2);

   function Min_Speed (S1 : Speed_Mps; S2 : Speed_Mps) return Speed_Mps is
     (if S1 < S2 then S1 else S2);

   function Max_Speed (S1 : Speed_Mps; S2 : Speed_Mps) return Speed_Mps is
     (if S1 > S2 then S1 else S2);

   -- Linear interpolation between (X0, Y0) and (X1, Y1) evaluated at X
   function Linear_Interp
     (X, X0, X1, Y0, Y1 : Float) return Float with
     Pre => X1 /= X0;

   -- Fast numerical square root implementation with validation
   function Sqrt (Value : Float) return Float with
     Pre  => Value >= 0.0,
     Post => Sqrt'Result >= 0.0;

end Aspect.Math;
