with Aspect.Topology.Switches; use Aspect.Topology.Switches;

package body Aspect.Interlocking.Detector is

   function Can_Throw_Switch
     (Net   : Railway_Network;
      Sw_Id : Switch_Id) return Boolean
   is
      Sw : constant Turnout_Switch := Net.Switches (Sw_Id);
   begin
      -- Mechanical / Electrical route lock violation
      if Sw.Is_Mechanically_Locked then
         return False;
      end if;

      -- Detector locking: point track circuit must be clear and undisturbed
      if Sw.Point_Section /= Null_Section_Id then
         if Net.Sections (Sw.Point_Section).Occupancy /= State_Clear then
            return False;
         end if;
      end if;

      return True;
   end Can_Throw_Switch;

   function Verify_Route_Switch_Clearance
     (Net      : Railway_Network;
      Switches : Switch_Requirement_Array;
      Count    : Natural) return Boolean
   is
   begin
      for I in 1 .. Count loop
         declare
            Req   : constant Switch_Alignment := Switches (I);
            Sw_Id : constant Switch_Id_Base   := Req.Switch;
         begin
            if Sw_Id = Null_Switch_Id then
               return False;
            end if;

            declare
               Sw : constant Turnout_Switch := Net.Switches (Sw_Id);
            begin
               -- Switch must match required alignment with verified microswitch detection
               if not Has_Verified_Detection (Sw, Req.Position) then
                  return False;
               end if;

               -- Point zone track section must be clear
               if Sw.Point_Section /= Null_Section_Id then
                  if Net.Sections (Sw.Point_Section).Occupancy /= State_Clear then
                     return False;
                  end if;
               end if;
            end;
         end;
      end loop;

      return True;
   end Verify_Route_Switch_Clearance;

end Aspect.Interlocking.Detector;
