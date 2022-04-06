-- Independent formal safety invariant verification barrier.
-- Audits interlocking state against EN 50128 SIL 4 safety properties
-- before vital commands reach physical output relays.

with Aspect.Types; use Aspect.Types;
with Aspect.Interlocking.Engine; use Aspect.Interlocking.Engine;

package Aspect.Vital.Safety_Invariants is

   type Invariant_Check_Result is record
      Passed               : Boolean          := True;
      Violated_Rule_Index  : Natural          := 0;
      Faulting_Route       : Route_Id_Base    := Null_Route_Id;
      Faulting_Switch      : Switch_Id_Base   := Null_Switch_Id;
      Faulting_Section     : Section_Id_Base  := Null_Section_Id;
      Diagnostic_Code      : Natural          := 0;
   end record;

   -- Audits all 5 core railway safety invariants:
   -- 1. Route mutual exclusion
   -- 2. Flank defensive alignment
   -- 3. Point detector occupancy lock
   -- 4. Signal aspect authorization
   -- 5. Track continuity and ballast integrity
   function Audit_Safety_Invariants
     (Core : Interlocking_Core) return Invariant_Check_Result;

   -- Specific individual invariant verifications
   function Verify_Mutual_Exclusion (Core : Interlocking_Core) return Boolean;
   function Verify_Flank_Defenses (Core : Interlocking_Core) return Boolean;
   function Verify_Detector_Locks (Core : Interlocking_Core) return Boolean;
   function Verify_Aspect_Authorization (Core : Interlocking_Core) return Boolean;

end Aspect.Vital.Safety_Invariants;
