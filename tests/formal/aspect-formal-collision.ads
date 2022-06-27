-- Property-based verification test for the EN 50128 SIL 4 Zero-Collision Invariant.
-- Proves that randomized dispatcher commands and multi-train movements never cause
-- physical spatial overlap between train consists.

with Aspect.Tests.Framework; use Aspect.Tests.Framework;

package Aspect.Formal.Collision is

   -- Executes 10,000 randomized dispatch cycles verifying zero collision events
   procedure Verify_Collision_Property (Ctx : in out Test_Context);

end Aspect.Formal.Collision;
