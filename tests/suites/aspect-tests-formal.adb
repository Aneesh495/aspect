-- Implementation of formal verification aggregated test suite.

with Aspect.Tests.Framework; use Aspect.Tests.Framework;
with Aspect.Formal.Collision; use Aspect.Formal.Collision;
with Aspect.Formal.Switch_Locking; use Aspect.Formal.Switch_Locking;
with Aspect.Formal.Flank_Integrity; use Aspect.Formal.Flank_Integrity;
with Aspect.Formal.Curve_Containment; use Aspect.Formal.Curve_Containment;
with Aspect.Formal.TMR_Byzantine; use Aspect.Formal.TMR_Byzantine;

package body Aspect.Tests.Formal is

   procedure Run_Formal_Tests (Overall_Passed : in out Boolean) is
      Ctx : Test_Context;
   begin
      Init_Context (Ctx, "Aspect.Formal (SIL 4 Invariants, Collision, Flank, Curves, 2oo3 TMR)");

      Verify_Collision_Property (Ctx);
      Verify_Switch_Locking_Property (Ctx);
      Verify_Flank_Property (Ctx);
      Verify_Curve_Containment_Property (Ctx);
      Verify_TMR_Byzantine_Property (Ctx);

      if not Summarize (Ctx) then
         Overall_Passed := False;
      end if;
   end Run_Formal_Tests;

end Aspect.Tests.Formal;
