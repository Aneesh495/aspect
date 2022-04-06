with Aspect.Topology.Switches; use Aspect.Topology.Switches;
with Aspect.Topology.Signals; use Aspect.Topology.Signals;
with Aspect.Interlocking.Routes; use Aspect.Interlocking.Routes;
with Aspect.Interlocking.Locking_Table; use Aspect.Interlocking.Locking_Table;
with Aspect.Interlocking.Flank; use Aspect.Interlocking.Flank;

package body Aspect.Vital.Safety_Invariants is

   function Verify_Mutual_Exclusion (Core : Interlocking_Core) return Boolean is
   begin
      for I in 1 .. Core.Route_Count loop
         declare
            RA : constant Interlocking_Route := Core.Routes (Route_Id (I));
         begin
            if Is_Active (RA) then
               for J in (I + 1) .. Core.Route_Count loop
                  declare
                     RB : constant Interlocking_Route := Core.Routes (Route_Id (J));
                  begin
                     if Is_Active (RB) and then Are_Conflicting (Core.Locking, Route_Id (I), Route_Id (J)) then
                        return False; -- Catastrophic mutual exclusion violation!
                     end if;
                  end;
               end loop;
            end if;
         end;
      end loop;
      return True;
   end Verify_Mutual_Exclusion;

   function Verify_Flank_Defenses (Core : Interlocking_Core) return Boolean is
   begin
      for I in 1 .. Core.Route_Count loop
         declare
            R : constant Interlocking_Route := Core.Routes (Route_Id (I));
         begin
            if R.State in Route_Cleared | Route_Approached then
               if not Verify_Flank_Integrity (Core.Flank, Core.Net, Route_Id (I)) then
                  return False;
               end if;
            end if;
         end;
      end loop;
      return True;
   end Verify_Flank_Defenses;

   function Verify_Detector_Locks (Core : Interlocking_Core) return Boolean is
   begin
      for I in 1 .. Core.Net.Switch_Count loop
         declare
            Sw : constant Turnout_Switch := Core.Net.Switches (Switch_Id (I));
         begin
            if Sw.Position = Switch_In_Transit then
               if Sw.Point_Section /= Null_Section_Id then
                  if Core.Net.Sections (Sw.Point_Section).Occupancy /= State_Clear then
                     return False; -- Switch throwing under train wheels!
                  end if;
               end if;
            end if;
         end;
      end loop;
      return True;
   end Verify_Detector_Locks;

   function Verify_Aspect_Authorization (Core : Interlocking_Core) return Boolean is
   begin
      for I in 1 .. Core.Net.Signal_Count loop
         declare
            Sig : constant Railway_Signal := Core.Net.Signals (Signal_Id (I));
         begin
            if Sig.Current_Aspect /= Aspect_Stop then
               -- Must be authorized by an active cleared route
               declare
                  Authorized : Boolean := False;
               begin
                  for R_Idx in 1 .. Core.Route_Count loop
                     declare
                        R : constant Interlocking_Route := Core.Routes (Route_Id (R_Idx));
                     begin
                        if R.Origin_Signal = Sig.Id and then R.State in Route_Cleared | Route_Approached then
                           Authorized := True;
                           exit;
                        end if;
                     end;
                  end loop;

                  if not Authorized then
                     return False; -- Phantom or unauthorized green signal!
                  end if;
               end;
            end if;
         end;
      end loop;
      return True;
   end Verify_Aspect_Authorization;

   function Audit_Safety_Invariants
     (Core : Interlocking_Core) return Invariant_Check_Result
   is
      Result : Invariant_Check_Result;
   begin
      Result.Passed := True;

      -- 1. Invariant 1: Route mutual exclusion
      if not Verify_Mutual_Exclusion (Core) then
         Result.Passed              := False;
         Result.Violated_Rule_Index := 1;
         Result.Diagnostic_Code     := 101;
         return Result;
      end if;

      -- 2. Invariant 2: Flank protection
      if not Verify_Flank_Defenses (Core) then
         Result.Passed              := False;
         Result.Violated_Rule_Index := 2;
         Result.Diagnostic_Code     := 102;
         return Result;
      end if;

      -- 3. Invariant 3: Detector locking
      if not Verify_Detector_Locks (Core) then
         Result.Passed              := False;
         Result.Violated_Rule_Index := 3;
         Result.Diagnostic_Code     := 103;
         return Result;
      end if;

      -- 4. Invariant 4: Aspect authorization
      if not Verify_Aspect_Authorization (Core) then
         Result.Passed              := False;
         Result.Violated_Rule_Index := 4;
         Result.Diagnostic_Code     := 104;
         return Result;
      end if;

      return Result;
   end Audit_Safety_Invariants;

end Aspect.Vital.Safety_Invariants;
