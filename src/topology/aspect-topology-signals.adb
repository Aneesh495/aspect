package body Aspect.Topology.Signals is

   procedure Initialize_Signal
     (Signal        : out Railway_Signal;
      Id            : Signal_Id;
      Name          : String;
      Category      : Signal_Category;
      Section       : Section_Id;
      Approach_Sec  : Section_Id;
      Next_Sig      : Signal_Id_Base;
      Chainage      : Track_Chainage;
      Direction     : Direction_Type := Dir_Nominal)
   is
      Len : constant Natural := Natural'Min (Name'Length, 16);
   begin
      Signal.Id                     := Id;
      Signal.Name                   := [others => ' '];
      Signal.Name (1 .. Len)        := Name (Name'First .. Name'First + Len - 1);
      Signal.Name_Len               := Len;
      Signal.Category               := Category;
      Signal.Track_Section          := Section;
      Signal.Approach_Section       := Approach_Sec;
      Signal.Next_Signal            := Next_Sig;
      Signal.Chainage               := Chainage;
      Signal.Governed_Direction     := Direction;
      Signal.Current_Aspect         := Aspect_Stop;
      Signal.Commanded_Aspect       := Aspect_Stop;
      Signal.Lamp_Health_Relay      := True;
      Signal.Filament_Burnout_Fault := False;
      Signal.Approach_Locked        := False;
      Signal.Approach_Timer_Ms      := 0;
   end Initialize_Signal;

   procedure Set_Aspect
     (Signal : in out Railway_Signal;
      Aspect : Signal_Aspect)
   is
   begin
      Signal.Commanded_Aspect := Aspect;

      -- Check filament burnout: if lamp fails, drop to safe restrictive aspect
      if Signal.Filament_Burnout_Fault then
         Signal.Current_Aspect    := Aspect_Stop;
         Signal.Lamp_Health_Relay := False;
      else
         Signal.Current_Aspect    := Aspect;
         Signal.Lamp_Health_Relay := True;
      end if;
   end Set_Aspect;

   function Compute_Cascade_Aspect
     (Next_Aspect : Signal_Aspect;
      Path_Clear  : Boolean) return Signal_Aspect
   is
   begin
      if not Path_Clear then
         return Aspect_Stop;
      end if;

      case Next_Aspect is
         when Aspect_Stop =>
            return Aspect_Caution; -- Yellow: prepare to stop at next signal

         when Aspect_Caution =>
            return Aspect_Preliminary_Caution; -- Double Yellow: expect Caution ahead

         when Aspect_Preliminary_Caution | Aspect_Clear =>
            return Aspect_Clear; -- Green: line clear for at least two blocks

         when Aspect_Shunt =>
            return Aspect_Caution;

         when Aspect_Dark =>
            return Aspect_Caution; -- Restrictive advance warning if next signal is dark
      end case;
   end Compute_Cascade_Aspect;

   procedure Drop_To_Danger (Signal : in out Railway_Signal) is
   begin
      Signal.Commanded_Aspect := Aspect_Stop;
      Signal.Current_Aspect   := Aspect_Stop;
   end Drop_To_Danger;

   procedure Update_Approach_Timer
     (Signal           : in out Railway_Signal;
      Approach_Occupied : Boolean;
      Delta_Ms         : Positive)
   is
   begin
      -- If signal displays proceed (not Stop) and a train is approaching, lock it
      if Signal.Current_Aspect /= Aspect_Stop and then Approach_Occupied then
         Signal.Approach_Locked := True;
      end if;

      -- Decrement timer if active
      if Signal.Approach_Timer_Ms > 0 then
         if Signal.Approach_Timer_Ms <= Delta_Ms then
            Signal.Approach_Timer_Ms := 0;
            Signal.Approach_Locked   := False;
         else
            Signal.Approach_Timer_Ms := Signal.Approach_Timer_Ms - Delta_Ms;
         end if;
      end if;
   end Update_Approach_Timer;

   procedure Inject_Lamp_Burnout (Signal : in out Railway_Signal; Fault_Active : Boolean) is
   begin
      Signal.Filament_Burnout_Fault := Fault_Active;
      if Fault_Active then
         Signal.Current_Aspect    := Aspect_Stop;
         Signal.Lamp_Health_Relay := False;
      else
         Signal.Lamp_Health_Relay := True;
         Signal.Current_Aspect    := Signal.Commanded_Aspect;
      end if;
   end Inject_Lamp_Burnout;

end Aspect.Topology.Signals;
