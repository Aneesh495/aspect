with Aspect.Topology.Tracks; use Aspect.Topology.Tracks;

package body Aspect.Interlocking.Overlap is

   procedure Initialize_Overlap_Table (Table : out Overlap_Array) is
   begin
      Table := [others => (Route_Id_Ref        => Null_Route_Id,
                           Section_Id_Ref      => Null_Section_Id,
                           Overlap_Length      => 200.0,
                           Is_Reserved         => False,
                           Standstill_Timer_Ms => 0,
                           Train_At_Standstill => False)];
   end Initialize_Overlap_Table;

   function Can_Reserve_Overlap
     (Net     : Railway_Network;
      Section : Section_Id) return Boolean
   is
   begin
      return Net.Sections (Section).Occupancy = State_Clear
        and then Net.Sections (Section).Lock_Status = Lock_None;
   end Can_Reserve_Overlap;

   procedure Reserve_Overlap
     (Table   : in out Overlap_Array;
      Net     : in out Railway_Network;
      Route   : Route_Id;
      Section : Section_Id;
      Dist_M  : Distance_M;
      Success : out Boolean)
   is
   begin
      if not Can_Reserve_Overlap (Net, Section) then
         Success := False;
         return;
      end if;

      Table (Route).Route_Id_Ref        := Route;
      Table (Route).Section_Id_Ref      := Section;
      Table (Route).Overlap_Length      := Dist_M;
      Table (Route).Is_Reserved         := True;
      Table (Route).Standstill_Timer_Ms := 0;
      Table (Route).Train_At_Standstill := False;

      Lock_Section (Net.Sections (Section), Route, Lock_Overlap_Reserved);
      Success := True;
   end Reserve_Overlap;

   procedure Release_Overlap
     (Table : in out Overlap_Array;
      Net   : in out Railway_Network;
      Route : Route_Id)
   is
      Sec_Id : constant Section_Id_Base := Table (Route).Section_Id_Ref;
   begin
      if Table (Route).Is_Reserved and then Sec_Id /= Null_Section_Id then
         if Net.Sections (Sec_Id).Locked_By_Route = Route then
            Unlock_Section (Net.Sections (Sec_Id));
         end if;
         Table (Route).Is_Reserved         := False;
         Table (Route).Standstill_Timer_Ms := 0;
         Table (Route).Train_At_Standstill := False;
      end if;
   end Release_Overlap;

   procedure Update_Standstill_Timer
     (Table    : in out Overlap_Array;
      Net      : in out Railway_Network;
      Route    : Route_Id;
      At_Rest  : Boolean;
      Delta_Ms : Positive)
   is
      Rec : Overlap_Record renames Table (Route);
   begin
      if not Rec.Is_Reserved then
         return;
      end if;

      if At_Rest then
         Rec.Train_At_Standstill := True;
         Rec.Standstill_Timer_Ms := Rec.Standstill_Timer_Ms + Delta_Ms;
         if Rec.Standstill_Timer_Ms >= Standstill_Release_Timeout_Ms then
            Release_Overlap (Table, Net, Route);
         end if;
      else
         Rec.Train_At_Standstill := False;
         Rec.Standstill_Timer_Ms := 0;
      end if;
   end Update_Standstill_Timer;

end Aspect.Interlocking.Overlap;
