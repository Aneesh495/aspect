package body Aspect.Interlocking.Routes is

   procedure Initialize_Route
     (Route       : out Interlocking_Route;
      Id          : Route_Id;
      Name        : String;
      Origin_Sig  : Signal_Id;
      Exit_Sig    : Signal_Id_Base := Null_Signal_Id;
      Class       : Route_Class    := Class_Main_Train)
   is
      Len : constant Natural := Natural'Min (Name'Length, 16);
   begin
      Route.Id                  := Id;
      Route.Name                := [others => ' '];
      Route.Name (1 .. Len)     := Name (Name'First .. Name'First + Len - 1);
      Route.Name_Len            := Len;
      Route.Class               := Class;
      Route.Origin_Signal       := Origin_Sig;
      Route.Exit_Signal         := Exit_Sig;
      Route.Path_Sections       := [others => Null_Section_Id];
      Route.Section_Count       := 0;
      Route.Required_Switches   := [others => (Null_Switch_Id, Switch_Normal)];
      Route.Switch_Count        := 0;
      Route.Overlap_Section     := Null_Section_Id;
      Route.Overlap_Distance    := 200.0;
      Route.Overlap_Timer_Ms    := 0;
      Route.State               := Route_Unset;
      Route.Assigned_Train      := Null_Train_Id;
      Route.Current_Section_Idx := 0;
   end Initialize_Route;

   procedure Add_Section
     (Route   : in out Interlocking_Route;
      Section : Section_Id)
   is
   begin
      if Route.Section_Count < Max_Sections_Per_Route then
         Route.Section_Count := Route.Section_Count + 1;
         Route.Path_Sections (Route.Section_Count) := Section;
      end if;
   end Add_Section;

   procedure Add_Switch_Alignment
     (Route    : in out Interlocking_Route;
      Switch   : Switch_Id;
      Position : Switch_Position)
   is
   begin
      if Route.Switch_Count < Max_Switches_Per_Route then
         Route.Switch_Count := Route.Switch_Count + 1;
         Route.Required_Switches (Route.Switch_Count) := (Switch, Position);
      end if;
   end Add_Switch_Alignment;

   procedure Set_Overlap_Protection
     (Route   : in out Interlocking_Route;
      Overlap : Section_Id;
      Dist_M  : Distance_M)
   is
   begin
      Route.Overlap_Section  := Overlap;
      Route.Overlap_Distance := Dist_M;
   end Set_Overlap_Protection;

   procedure Transition_State
     (Route     : in out Interlocking_Route;
      New_State : Route_State;
      Success   : out Boolean)
   is
   begin
      -- Emergency cancellation is valid from any operational state
      if New_State = Route_Cancelled then
         Route.State := Route_Cancelled;
         Success     := True;
         return;
      end if;

      case Route.State is
         when Route_Unset =>
            if New_State in Route_Requested | Route_Interlocked then
               Route.State := New_State;
               Success     := True;
            else
               Success := False;
            end if;

         when Route_Requested =>
            if New_State in Route_Interlocked | Route_Unset then
               Route.State := New_State;
               Success     := True;
            else
               Success := False;
            end if;

         when Route_Interlocked =>
            if New_State = Route_Cleared then
               Route.State := Route_Cleared;
               Success     := True;
            else
               Success := False;
            end if;

         when Route_Cleared =>
            if New_State in Route_Approached | Route_Occupied then
               Route.State := New_State;
               Success     := True;
            else
               Success := False;
            end if;

         when Route_Approached =>
            if New_State = Route_Occupied then
               Route.State := Route_Occupied;
               Success     := True;
            else
               Success := False;
            end if;

         when Route_Occupied =>
            if New_State in Route_Sectional_Release | Route_Released then
               Route.State := New_State;
               Success     := True;
            else
               Success := False;
            end if;

         when Route_Sectional_Release =>
            if New_State = Route_Released then
               Route.State := Route_Released;
               Success     := True;
            else
               Success := False;
            end if;

         when Route_Released =>
            if New_State = Route_Unset then
               Route.State := Route_Unset;
               Success     := True;
            else
               Success := False;
            end if;

         when Route_Cancelled =>
            if New_State = Route_Unset then
               Route.State := Route_Unset;
               Success     := True;
            else
               Success := False;
            end if;
      end case;
   end Transition_State;

end Aspect.Interlocking.Routes;
