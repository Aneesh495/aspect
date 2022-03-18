package body Aspect.Interlocking.Locking_Table is

   procedure Initialize_Table (Table : out Interlocking_Table) is
   begin
      Table.Matrix      := [others => (Conflicts => [others => Null_Route_Id], Conflict_Count => 0)];
      Table.Route_Count := 0;
   end Initialize_Table;

   procedure Register_Conflict
     (Table   : in out Interlocking_Table;
      Route_A : Route_Id;
      Route_B : Route_Id)
   is
      procedure Add_Single_Edge (From_R, To_R : Route_Id) is
         Entry_Rec : Route_Conflict_Entry renames Table.Matrix (From_R);
      begin
         -- Check if already present
         for I in 1 .. Entry_Rec.Conflict_Count loop
            if Entry_Rec.Conflicts (I) = To_R then
               return;
            end if;
         end loop;

         if Entry_Rec.Conflict_Count < Max_Conflicts_Per_Route then
            Entry_Rec.Conflict_Count := Entry_Rec.Conflict_Count + 1;
            Entry_Rec.Conflicts (Entry_Rec.Conflict_Count) := To_R;
         end if;
      end Add_Single_Edge;
   begin
      if Route_A = Route_B then
         return;
      end if;
      Add_Single_Edge (Route_A, Route_B);
      Add_Single_Edge (Route_B, Route_A);
   end Register_Conflict;

   procedure Synthesize_Conflicts
     (Table  : in out Interlocking_Table;
      Routes : Route_Array;
      Count  : Natural)
   is
   begin
      Table.Route_Count := Count;

      for I in 1 .. Count loop
         for J in (I + 1) .. Count loop
            declare
               RA : Interlocking_Route renames Routes (Route_Id (I));
               RB : Interlocking_Route renames Routes (Route_Id (J));
               Conflict_Found : Boolean := False;
            begin
               -- 1. Check shared track section conflicts
               for Sec_A in 1 .. RA.Section_Count loop
                  for Sec_B in 1 .. RB.Section_Count loop
                     if RA.Path_Sections (Sec_A) = RB.Path_Sections (Sec_B) then
                        Conflict_Found := True;
                        exit;
                     end if;
                  end loop;
                  exit when Conflict_Found;
               end loop;

               -- 2. Check switch contention (same switch required in opposite positions)
               if not Conflict_Found then
                  for Sw_A in 1 .. RA.Switch_Count loop
                     for Sw_B in 1 .. RB.Switch_Count loop
                        if RA.Required_Switches (Sw_A).Switch = RB.Required_Switches (Sw_B).Switch
                          and then RA.Required_Switches (Sw_A).Position /= RB.Required_Switches (Sw_B).Position
                        then
                           Conflict_Found := True;
                           exit;
                        end if;
                     end loop;
                     exit when Conflict_Found;
                  end loop;
               end if;

               -- 3. Check overlap collision with route paths
               if not Conflict_Found then
                  if RA.Overlap_Section /= Null_Section_Id then
                     for Sec_B in 1 .. RB.Section_Count loop
                        if RA.Overlap_Section = RB.Path_Sections (Sec_B) then
                           Conflict_Found := True;
                           exit;
                        end if;
                     end loop;
                  end if;

                  if not Conflict_Found and then RB.Overlap_Section /= Null_Section_Id then
                     for Sec_A in 1 .. RA.Section_Count loop
                        if RB.Overlap_Section = RA.Path_Sections (Sec_A) then
                           Conflict_Found := True;
                           exit;
                        end if;
                     end loop;
                  end if;
               end if;

               if Conflict_Found then
                  Register_Conflict (Table, Route_Id (I), Route_Id (J));
               end if;
            end;
         end loop;
      end loop;
   end Synthesize_Conflicts;

   function Has_Active_Conflict
     (Table        : Interlocking_Table;
      Routes       : Route_Array;
      Target_Route : Route_Id) return Boolean
   is
      Entry_Rec : constant Route_Conflict_Entry := Table.Matrix (Target_Route);
   begin
      for I in 1 .. Entry_Rec.Conflict_Count loop
         declare
            Conf_Id : constant Route_Id_Base := Entry_Rec.Conflicts (I);
         begin
            if Conf_Id /= Null_Route_Id and then Is_Active (Routes (Conf_Id)) then
               return True;
            end if;
         end;
      end loop;
      return False;
   end Has_Active_Conflict;

   function Are_Conflicting
     (Table   : Interlocking_Table;
      Route_A : Route_Id;
      Route_B : Route_Id) return Boolean
   is
      Entry_Rec : constant Route_Conflict_Entry := Table.Matrix (Route_A);
   begin
      for I in 1 .. Entry_Rec.Conflict_Count loop
         if Entry_Rec.Conflicts (I) = Route_B then
            return True;
         end if;
      end loop;
      return False;
   end Are_Conflicting;

end Aspect.Interlocking.Locking_Table;
