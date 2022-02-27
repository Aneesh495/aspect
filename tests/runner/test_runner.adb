-- Main test runner executing all Aspect verification and unit test suites.

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Command_Line;
with Aspect.Tests.Core;

procedure Test_Runner is
   Overall_Passed : Boolean := True;
begin
   Put_Line ("============================================================");
   Put_Line ("  ASPECT RAILWAY SAFETY VERIFICATION SUITE");
   Put_Line ("  Standards: EN 50128 SIL 4 / ERA ETCS Subset-026");
   Put_Line ("============================================================");
   New_Line;

   -- Core mathematical and checksum verification
   Aspect.Tests.Core.Run_Core_Tests (Overall_Passed);

   New_Line;
   Put_Line ("============================================================");
   if Overall_Passed then
      Put_Line ("  ALL VERIFICATION SUITES PASSED SUCCESSFULLY.");
      Put_Line ("============================================================");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Put_Line ("  VERIFICATION FAILED: REGRESSION DETECTED.");
      Put_Line ("============================================================");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Test_Runner;
