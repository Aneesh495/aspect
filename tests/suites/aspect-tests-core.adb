with Aspect.Types; use Aspect.Types;
with Aspect.Math; use Aspect.Math;
with Aspect.CRC; use Aspect.CRC;
with Aspect.Tests.Framework; use Aspect.Tests.Framework;
with Interfaces; use Interfaces;

package body Aspect.Tests.Core is

   procedure Run_Core_Tests (Overall_Passed : in out Boolean) is
      Ctx : Test_Context;
   begin
      Init_Context (Ctx, "Aspect.Core (Types, Math, CRC)");

      -------------------------------------------------------------------------
      -- Test 1: Unit Conversions
      -------------------------------------------------------------------------
      declare
         Speed_100_Kph : constant Speed_Kph := 100.0;
         Speed_Mps_Val : constant Speed_Mps := Kph_To_Mps (Speed_100_Kph);
         Speed_Back    : constant Speed_Kph := Mps_To_Kph (Speed_Mps_Val);
      begin
         -- 100 km/h = 27.7777... m/s
         Assert_Within_Float (Ctx, 27.7778, Float (Speed_Mps_Val), 0.001,
                              "100 km/h conversion to m/s");
         Assert_Within_Float (Ctx, 100.0, Float (Speed_Back), 0.001,
                              "Reversible speed conversion");
      end;

      declare
         Mm_Val : constant Millimeter := 12_500;
         M_Val  : constant Meter      := Millimeters_To_Meters (Mm_Val);
         Mm_Back: constant Millimeter := Meters_To_Millimeters (M_Val);
      begin
         Assert_Within_Float (Ctx, 12.5, Float (M_Val), 0.0001,
                              "12,500 mm to 12.5 m");
         Assert_Equal_Int (Ctx, 12_500, Long_Long_Integer (Mm_Back),
                           "Reversible distance conversion");
      end;

      -------------------------------------------------------------------------
      -- Test 2: Kinematic Solvers
      -------------------------------------------------------------------------
      declare
         -- Train traveling at 30 m/s (~108 km/h) braking at 1.0 m/s^2:
         -- d = 30^2 / (2 * 1.0) = 900 / 2 = 450 meters
         V0   : constant Speed_Mps := 30.0;
         A    : constant Deceleration_Mps2 := 1.0;
         Dist : constant Distance_M := Stopping_Distance (V0, A);
      begin
         Assert_Within_Float (Ctx, 450.0, Float (Dist), 0.01,
                              "Kinematic stopping distance 30 m/s @ 1 m/s^2");
      end;

      declare
         -- Decelerating from 50 m/s (180 km/h) to 20 m/s (72 km/h) at 1.0 m/s^2:
         -- d = (50^2 - 20^2) / 2 = (2500 - 400) / 2 = 1050 meters
         V0   : constant Speed_Mps := 50.0;
         V1   : constant Speed_Mps := 20.0;
         A    : constant Deceleration_Mps2 := 1.0;
         Dist : constant Distance_M := Deceleration_Distance (V0, V1, A);
      begin
         Assert_Within_Float (Ctx, 1050.0, Float (Dist), 0.01,
                              "Deceleration distance 50 -> 20 m/s @ 1 m/s^2");
      end;

      declare
         -- Safe speed for target 0 m/s at 200m distance under 1.0 m/s^2:
         -- v = sqrt(0 + 2 * 1.0 * 200) = sqrt(400) = 20.0 m/s
         V_Safe : constant Speed_Mps := Safe_Speed_At_Distance (0.0, 200.0, 1.0);
      begin
         Assert_Within_Float (Ctx, 20.0, Float (V_Safe), 0.01,
                              "Safe speed 200m before stop at 1 m/s^2");
      end;

      -------------------------------------------------------------------------
      -- Test 3: Gradient and Adhesion Environmental Compensation
      -------------------------------------------------------------------------
      declare
         -- Uphill grade of +20 per mille (+2%):
         -- A_grad = 9.80665 * 0.02 = +0.1961 m/s^2
         A_Uphill : constant Acceleration_Mps2 := Gradient_Acceleration (20.0);
         -- Downhill grade of -20 per mille (-2%):
         A_Downhill : constant Acceleration_Mps2 := Gradient_Acceleration (-20.0);
      begin
         Assert_Within_Float (Ctx, 0.1961, Float (A_Uphill), 0.001,
                              "Uphill grade +20 per mille assistance");
         Assert_Within_Float (Ctx, -0.1961, Float (A_Downhill), 0.001,
                              "Downhill grade -20 per mille degradation");
      end;

      declare
         -- Nominal 1.0 m/s^2, flat track (0 per mille), dry rail (1.0), 10% rotating mass:
         -- A_eff = (1.0 * 1.0 + 0) / 1.10 = 0.90909 m/s^2
         A_Comp : constant Deceleration_Mps2 := Composite_Deceleration
           (A_Nominal     => 1.0,
            Gradient      => 0.0,
            Adhesion      => 1.0,
            Rotating_Mass => 10.0);
      begin
         Assert_Within_Float (Ctx, 0.9091, Float (A_Comp), 0.001,
                              "Composite deceleration with 10% rotating mass");
      end;

      -------------------------------------------------------------------------
      -- Test 4: CRC Standard Checksums
      -------------------------------------------------------------------------
      declare
         -- "123456789" in ASCII
         Test_Bytes : constant Byte_Array :=
           [16#31#, 16#32#, 16#33#, 16#34#, 16#35#, 16#36#, 16#37#, 16#38#, 16#39#];
         Crc32_Val  : constant Unsigned_32 := Calculate_CRC32_IEEE (Test_Bytes);
         Crc32c_Val : constant Unsigned_32 := Calculate_CRC32C (Test_Bytes);
      begin
         -- Standard IEEE 802.3 CRC-32 for "123456789" is 0xCBF43926
         Assert_Equal_Int (Ctx, 16#CBF43926#, Long_Long_Integer (Crc32_Val),
                           "CRC-32 IEEE standard check vector (0xCBF43926)");
         -- Castagnoli CRC-32C for "123456789" is 0xE3069283
         Assert_Equal_Int (Ctx, 16#E3069283#, Long_Long_Integer (Crc32c_Val),
                           "CRC-32C Castagnoli standard check vector (0xE3069283)");
      end;

      declare
         -- Single byte zero telegram CRC-10 calculation
         Zero_Bytes : constant Byte_Array := [1 => 0];
         Crc10_Val  : constant CRC10_Type := Calculate_CRC10 (Zero_Bytes, 8);
      begin
         Assert_Equal_Int (Ctx, 0, Long_Long_Integer (Crc10_Val),
                           "CRC-10 zero-block checksum");
      end;

      if not Summarize (Ctx) then
         Overall_Passed := False;
      end if;
   end Run_Core_Tests;

end Aspect.Tests.Core;
