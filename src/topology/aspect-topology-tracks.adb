package body Aspect.Topology.Tracks is

   procedure Initialize_Section
     (Section     : out Track_Section;
      Id          : Section_Id;
      Name        : String;
      Length_M    : Distance_M;
      Start_Km    : Track_Chainage;
      Line_Speed  : Speed_Kph;
      Gradient    : Gradient_Per_Mille;
      Tech        : Detection_Technology := Tech_DC_Track_Circuit)
   is
      Len : constant Natural := Natural'Min (Name'Length, 16);
   begin
      Section.Id                 := Id;
      Section.Name               := [others => ' '];
      Section.Name (1 .. Len)    := Name (Name'First .. Name'First + Len - 1);
      Section.Name_Len           := Len;
      Section.Technology         := Tech;
      Section.Length_M           := Length_M;
      Section.Start_Chainage     := Start_Km;
      Section.End_Chainage       := Start_Km + Track_Chainage (Length_M);
      Section.Line_Speed_Limit   := Line_Speed;
      Section.Gradient           := Gradient;
      Section.Curvature_Radius   := 0.0;
      Section.Occupancy          := State_Clear;
      Section.Relay_Energized    := True;
      Section.Axle_In_Count      := 0;
      Section.Axle_Out_Count     := 0;
      Section.Ballast_Resistance := 100.0;
      Section.Broken_Rail_Fault  := False;
      Section.Lock_Status        := Lock_None;
      Section.Locked_By_Route    := Null_Route_Id;
      Section.Occupying_Train    := Null_Train_Id;
   end Initialize_Section;

   procedure Evaluate_Vital_Occupancy (Section : in out Track_Section) is
   begin
      -- First check broken rail physical discontinuity
      if Section.Broken_Rail_Fault then
         Section.Occupancy       := State_Disturbed;
         Section.Relay_Energized := False;
         return;
      end if;

      -- Check ballast electrical resistance leakage (water saturation or ballast dirt)
      if Section.Technology = Tech_DC_Track_Circuit
        and then Section.Ballast_Resistance < 2.5
      then
         Section.Occupancy       := State_Disturbed;
         Section.Relay_Energized := False;
         return;
      end if;

      -- Check axle counter balance
      if Section.Technology = Tech_Dual_Wheel_Axle_Counter then
         if Section.Axle_In_Count /= Section.Axle_Out_Count then
            Section.Occupancy       := State_Occupied;
            Section.Relay_Energized := False;
            return;
         end if;
      end if;

      -- Check wheelset electrical shunting
      if Section.Occupying_Train /= Null_Train_Id then
         Section.Occupancy       := State_Occupied;
         Section.Relay_Energized := False;
         return;
      end if;

      -- Section is clean, undamaged, and unoccupied: relay is picked up
      Section.Occupancy       := State_Clear;
      Section.Relay_Energized := True;
   end Evaluate_Vital_Occupancy;

   procedure Shunt_By_Train
     (Section : in out Track_Section;
      Train   : Train_Id)
   is
   begin
      Section.Occupying_Train := Train;
      Evaluate_Vital_Occupancy (Section);
   end Shunt_By_Train;

   procedure Clear_Train_Shunt
     (Section : in out Track_Section;
      Train   : Train_Id)
   is
   begin
      if Section.Occupying_Train = Train then
         Section.Occupying_Train := Null_Train_Id;
      end if;
      Evaluate_Vital_Occupancy (Section);
   end Clear_Train_Shunt;

   procedure Register_Axle_In (Section : in out Track_Section) is
   begin
      Section.Axle_In_Count := Section.Axle_In_Count + 1;
      Evaluate_Vital_Occupancy (Section);
   end Register_Axle_In;

   procedure Register_Axle_Out (Section : in out Track_Section) is
   begin
      Section.Axle_Out_Count := Section.Axle_Out_Count + 1;
      Evaluate_Vital_Occupancy (Section);
   end Register_Axle_Out;

   procedure Set_Broken_Rail (Section : in out Track_Section; Fault_Active : Boolean) is
   begin
      Section.Broken_Rail_Fault := Fault_Active;
      Evaluate_Vital_Occupancy (Section);
   end Set_Broken_Rail;

   procedure Set_Ballast_Resistance (Section : in out Track_Section; Resistance_Ohms : Float) is
   begin
      Section.Ballast_Resistance := Resistance_Ohms;
      Evaluate_Vital_Occupancy (Section);
   end Set_Ballast_Resistance;

   procedure Lock_Section
     (Section   : in out Track_Section;
      Route     : Route_Id;
      Lock_Type : Section_Lock_Kind)
   is
   begin
      Section.Lock_Status     := Lock_Type;
      Section.Locked_By_Route := Route;
   end Lock_Section;

   procedure Unlock_Section (Section : in out Track_Section) is
   begin
      Section.Lock_Status     := Lock_None;
      Section.Locked_By_Route := Null_Route_Id;
   end Unlock_Section;

end Aspect.Topology.Tracks;
