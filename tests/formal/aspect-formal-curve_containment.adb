-- Implementation of ETCS braking curve containment property test.

with Aspect.Types; use Aspect.Types;
with Aspect.ETCS.Braking_Curves; use Aspect.ETCS.Braking_Curves;
with Aspect.Sim.Scenarios; use Aspect.Sim.Scenarios;
with Aspect.Sim.World; use Aspect.Sim.World;
with Aspect.Formal.Oracles; use Aspect.Formal.Oracles;

package body Aspect.Formal.Curve_Containment is

   procedure Verify_Curve_Containment_Property (Ctx : in out Test_Context) is
      Params : Train_Brake_Parameters;
      Env    : Supervision_Envelope;
      World  : World_Context;
      Report : Oracle_Report;
   begin
      Params.Nominal_Emergency_A := 1.20;
      Params.Nominal_Service_A   := 0.85;

      -- 1. Property Test: Speed Hierarchy Monotonicity across 100 distance steps
      for Dist_Step in 1 .. 100 loop
         declare
            Dist_EoA : constant Distance_M := Distance_M (Dist_Step * 50); -- 50m to 5000m
            Dist_SvL : constant Distance_M := Dist_EoA + 200.0;
         begin
            Calculate_Envelopes
              (Params          => Params,
               Current_Speed   => 120.0,
               Distance_To_EoA => Dist_EoA,
               Distance_To_SvL => Dist_SvL,
               Target_Speed    => 0.0,
               Ceiling_Speed   => 200.0,
               Envelope        => Env);

            -- Check strict mathematical ordering: V_Ind <= V_Perm <= V_Warn <= V_SBI <= V_EBI
            Assert (Ctx, Env.Indication_Speed <= Env.Permitted_Speed,
                    "Indication speed <= Permitted speed");
            Assert (Ctx, Env.Permitted_Speed <= Env.Warning_Speed,
                    "Permitted speed <= Warning speed");
            Assert (Ctx, Env.Warning_Speed <= Env.SBI_Speed,
                    "Warning speed <= Service Brake Intervention speed");
            Assert (Ctx, Env.SBI_Speed <= Env.EBI_Speed,
                    "Service Brake Intervention speed <= Emergency Brake Intervention speed");
         end;
      end loop;

      -- 2. Property Test: High-Speed LGV Scenario Simulation Containment
      Initialize_Simulation_World (World, Scenario => Scenario_High_Speed);

      -- Accelerate train up to 300 km/h and verify containment at every step
      for Step in 1 .. 200 loop
         Step_Simulation (World, Delta_Ms => 50);
         Report := Verify_Curve_Containment (World);
         Assert (Ctx, Report.Passed,
                 "Curve containment oracle holds during high-speed step " & Natural'Image (Step));
      end loop;

   end Verify_Curve_Containment_Property;

end Aspect.Formal.Curve_Containment;
