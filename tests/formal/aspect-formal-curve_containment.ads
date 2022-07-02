-- Property-based verification test for the ETCS Subset-026 Braking Curve Containment Invariant.
-- Proves that the speed supervision hierarchy strictly enforces v_Ind <= v_Perm <= v_Warn <= v_SBI <= v_EBI
-- and that emergency brake intervention trips before the Supervised Location (SvL) is encroached.

with Aspect.Tests.Framework; use Aspect.Tests.Framework;

package Aspect.Formal.Curve_Containment is

   -- Verifies that the braking curve hierarchy and containment hold under all operating conditions
   procedure Verify_Curve_Containment_Property (Ctx : in out Test_Context);

end Aspect.Formal.Curve_Containment;
