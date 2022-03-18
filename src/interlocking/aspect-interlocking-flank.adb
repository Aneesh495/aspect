package body Aspect.Interlocking.Flank is

   procedure Initialize_Flank_Table (Table : out Flank_Table) is
   begin
      Table := [others => (Defenses => [others => <>], Defense_Count => 0)];
   end Initialize_Flank_Table;

   procedure Add_Flank_Defense
     (Table              : in out Flank_Table;
      Route              : Route_Id;
      Protective_Switch  : Switch_Id;
      Diverting_Position : Switch_Position;
      Protective_Signal  : Signal_Id_Base := Null_Signal_Id;
      Fouling_Section    : Section_Id_Base := Null_Section_Id)
   is
      Profile : Route_Flank_Profile renames Table (Route);
   begin
      if Profile.Defense_Count < Max_Flank_Protections then
         Profile.Defense_Count := Profile.Defense_Count + 1;
         Profile.Defenses (Profile.Defense_Count) :=
           (Protective_Switch  => Protective_Switch,
            Diverting_Position => Diverting_Position,
            Protective_Signal  => Protective_Signal,
            Fouling_Section    => Fouling_Section);
      end if;
   end Add_Flank_Defense;

   function Verify_Flank_Integrity
     (Table : Flank_Table;
      Net   : Railway_Network;
      Route : Route_Id) return Boolean
   is
      Profile : constant Route_Flank_Profile := Table (Route);
   begin
      for I in 1 .. Profile.Defense_Count loop
         declare
            Def : constant Flank_Defense := Profile.Defenses (I);
         begin
            -- 1. Verify protective switch is aligned and has verified electrical detection
            if Def.Protective_Switch /= Null_Switch_Id then
               declare
                  Sw : constant Turnout_Switch := Net.Switches (Def.Protective_Switch);
               begin
                  if not Has_Verified_Detection (Sw, Def.Diverting_Position) then
                     return False;
                  end if;
               end;
            end if;

            -- 2. Verify fouling point track circuit is unoccupied
            if Def.Fouling_Section /= Null_Section_Id then
               if Net.Sections (Def.Fouling_Section).Occupancy /= State_Clear then
                  return False;
               end if;
            end if;

            -- 3. Verify opposing shunt signal is clamped to Stop
            if Def.Protective_Signal /= Null_Signal_Id then
               if Net.Signals (Def.Protective_Signal).Current_Aspect /= Aspect_Stop then
                  return False;
               end if;
            end if;
         end;
      end loop;

      return True;
   end Verify_Flank_Integrity;

   procedure Lock_Flank_Defenses
     (Table   : Flank_Table;
      Net     : in out Railway_Network;
      Route   : Route_Id;
      Success : out Boolean)
   is
      Profile : constant Route_Flank_Profile := Table (Route);
   begin
      -- First verify all defenses can be established
      for I in 1 .. Profile.Defense_Count loop
         declare
            Def : constant Flank_Defense := Profile.Defenses (I);
         begin
            if Def.Protective_Switch /= Null_Switch_Id then
               declare
                  Sw : constant Turnout_Switch := Net.Switches (Def.Protective_Switch);
               begin
                  -- If already locked by another route in conflicting position, fail
                  if Sw.Is_Mechanically_Locked and then Sw.Position /= Def.Diverting_Position then
                     Success := False;
                     return;
                  end if;
               end;
            end if;
         end;
      end loop;

      -- Apply locks and signal clamps
      for I in 1 .. Profile.Defense_Count loop
         declare
            Def : constant Flank_Defense := Profile.Defenses (I);
         begin
            if Def.Protective_Switch /= Null_Switch_Id then
               Lock_For_Route (Net.Switches (Def.Protective_Switch), Route);
            end if;

            if Def.Protective_Signal /= Null_Signal_Id then
               Drop_To_Danger (Net.Signals (Def.Protective_Signal));
            end if;
         end;
      end loop;

      Success := True;
   end Lock_Flank_Defenses;

   procedure Unlock_Flank_Defenses
     (Table : Flank_Table;
      Net   : in out Railway_Network;
      Route : Route_Id)
   is
      Profile : constant Route_Flank_Profile := Table (Route);
   begin
      for I in 1 .. Profile.Defense_Count loop
         declare
            Def : constant Flank_Defense := Profile.Defenses (I);
         begin
            if Def.Protective_Switch /= Null_Switch_Id then
               if Net.Switches (Def.Protective_Switch).Locked_By_Route = Route then
                  Unlock_From_Route (Net.Switches (Def.Protective_Switch));
               end if;
            end if;
         end;
      end loop;
   end Unlock_Flank_Defenses;

end Aspect.Interlocking.Flank;
