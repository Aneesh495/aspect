-- Property-based verification test for 2oo3 TMR Byzantine Fault Tolerance.
-- Proves that single-channel bit-flips, corrupted relay values, and timing divergence
-- are masked by majority consensus, trigger automated FDIR channel isolation,
-- and gracefully degrade to fail-safe shutdown upon consensus loss.

with Aspect.Tests.Framework; use Aspect.Tests.Framework;

package Aspect.Formal.TMR_Byzantine is

   -- Verifies 2oo3 voting majority masking, FDIR isolation, and fail-safe clamping
   procedure Verify_TMR_Byzantine_Property (Ctx : in out Test_Context);

end Aspect.Formal.TMR_Byzantine;
