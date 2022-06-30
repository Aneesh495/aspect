-- Property-based verification test for the Flank Protection Invariant.
-- Proves that converging turnouts and opposing signals are defensively locked
-- to guarantee zero fouling of active interlocked routes.

with Aspect.Tests.Framework; use Aspect.Tests.Framework;

package Aspect.Formal.Flank_Integrity is

   -- Verifies that flank protection rules unconditionally isolate converging tracks
   procedure Verify_Flank_Property (Ctx : in out Test_Context);

end Aspect.Formal.Flank_Integrity;
