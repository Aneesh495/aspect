-- Detector locking and point zone vital safety interlocks.
-- Enforces physical hardware invariants preventing switch movement under moving wheels
-- or during electrical track circuit disturbances.

with Aspect.Topology.Network; use Aspect.Topology.Network;
with Aspect.Interlocking.Routes; use Aspect.Interlocking.Routes;

package Aspect.Interlocking.Detector is

   -- Evaluates whether a switch is permitted to move.
   -- Returns False if:
   -- 1. Point track circuit is occupied or disturbed.
   -- 2. Switch is mechanically locked by an active route.
   -- 3. Any adjacent fouling point is shunted.
   function Can_Throw_Switch
     (Net     : Railway_Network;
      Sw_Id   : Switch_Id) return Boolean;

   -- Verifies all switches required by a route have verified detection and detector clearance
   function Verify_Route_Switch_Clearance
     (Net            : Railway_Network;
      Switches       : Switch_Requirement_Array;
      Count          : Natural) return Boolean;

end Aspect.Interlocking.Detector;
