-- Property-based verification test for the Point Detector Locking Invariant.
-- Proves that turnout point machines are strictly immobilized whenever their
-- host track section is occupied by a train or reserved by an active route.

with Aspect.Tests.Framework; use Aspect.Tests.Framework;

package Aspect.Formal.Switch_Locking is

   -- Verifies that point machine throws are unconditionally rejected under occupancy
   procedure Verify_Switch_Locking_Property (Ctx : in out Test_Context);

end Aspect.Formal.Switch_Locking;
