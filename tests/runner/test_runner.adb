-- Main test runner executing all Aspect verification and unit test suites.

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Command_Line;
with Aspect.Tests.Core;
with Aspect.Tests.Topology;
with Aspect.Tests.Interlocking;
with Aspect.Tests.ETCS;
with Aspect.Tests.Vital;
with Aspect.Tests.Sim;

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

   -- Track topology and physical infrastructure verification
   Aspect.Tests.Topology.Run_Topology_Tests (Overall_Passed);

   -- Computer-Based Interlocking (CBI) verification
   Aspect.Tests.Interlocking.Run_Interlocking_Tests (Overall_Passed);

   -- ETCS Level 2 and Subset-026 verification
   Aspect.Tests.ETCS.Run_ETCS_Tests (Overall_Passed);

   -- EN 50128 SIL 4 Vital TMR and Safety Invariant verification
   Aspect.Tests.Vital.Run_Vital_Tests (Overall_Passed);

   -- Simulation, vehicle dynamics, odometry, and closed-loop world step
   Aspect.Tests.Sim.Run_Sim_Tests (Overall_Passed);

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
