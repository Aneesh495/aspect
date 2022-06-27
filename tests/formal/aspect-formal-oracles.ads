-- Formal verification oracle interfaces for EN 50128 SIL 4 safety properties.
-- Evaluates mathematical invariants across topological track states, point detector
-- locking, flank protection, ETCS braking curves, and 2oo3 Byzantine voter arbitration.

with Aspect.Sim.World; use Aspect.Sim.World;

package Aspect.Formal.Oracles is

   type Oracle_Report is record
      Passed     : Boolean          := True;
      Violations : Natural          := 0;
      Detail     : String (1 .. 64) := [others => ' '];
      Detail_Len : Natural          := 0;
   end record;

   -- Invariant 1: Zero Collision Property
   -- Verifies that no two distinct train consists occupy overlapping spatial extents
   function Verify_Zero_Collision
     (World : World_Context) return Oracle_Report;

   -- Invariant 2: Point Detector Locking Property
   -- Verifies that no turnout switch point machine moves or changes alignment under wheelset occupancy
   function Verify_Detector_Locking
     (World : World_Context) return Oracle_Report;

   -- Invariant 3: Flank Protection Property
   -- Verifies that every converging path toward an active route is locked in a diverting defensive position
   function Verify_Flank_Integrity
     (World : World_Context) return Oracle_Report;

   -- Invariant 4: Speed Curve Containment Property
   -- Verifies that train velocity never exceeds the Emergency Brake Intervention (EBI) ceiling
   function Verify_Curve_Containment
     (World : World_Context) return Oracle_Report;

end Aspect.Formal.Oracles;
