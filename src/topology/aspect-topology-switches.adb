package body Aspect.Topology.Switches is

   procedure Initialize_Switch
     (Switch          : out Turnout_Switch;
      Id              : Switch_Id;
      Name            : String;
      Point_Section   : Section_Id;
      Facing_Section  : Section_Id;
      Normal_Section  : Section_Id;
      Reverse_Section : Section_Id;
      Speed_Norm      : Speed_Kph := 160.0;
      Speed_Rev       : Speed_Kph := 60.0)
   is
      Len : constant Natural := Natural'Min (Name'Length, 16);
   begin
      Switch.Id                      := Id;
      Switch.Name                    := [others => ' '];
      Switch.Name (1 .. Len)         := Name (Name'First .. Name'First + Len - 1);
      Switch.Name_Len                := Len;
      Switch.Point_Section           := Point_Section;
      Switch.Facing_Section          := Facing_Section;
      Switch.Normal_Section          := Normal_Section;
      Switch.Reverse_Section         := Reverse_Section;
      Switch.Speed_Limit_Normal      := Speed_Norm;
      Switch.Speed_Limit_Reverse     := Speed_Rev;
      Switch.Position                := Switch_Normal;
      Switch.Target_Position         := Switch_Normal;
      Switch.Stroke_Timer_Ms         := 0;
      Switch.Normal_Detection_Relay  := True;
      Switch.Reverse_Detection_Relay := False;
      Switch.Is_Mechanically_Locked  := False;
      Switch.Locked_By_Route         := Null_Route_Id;
      Switch.Obstacle_Stall_Fault    := False;
      Switch.Trailing_Cut_Detected   := False;
   end Initialize_Switch;

   procedure Request_Throw
     (Switch         : in out Turnout_Switch;
      Target         : Switch_Position;
      Track_Occupied : Boolean;
      Accepted       : out Boolean)
   is
   begin
      -- Target must be a legitimate discrete aligned state (Normal or Reverse)
      if Target /= Switch_Normal and Target /= Switch_Reverse then
         Accepted := False;
         return;
      end if;

      -- Interlocking safety check: Switch cannot be moved while locked by active route
      if Switch.Is_Mechanically_Locked then
         Accepted := False;
         return;
      end if;

      -- Detector locking: Switch cannot be thrown while train shunts point track circuit
      if Track_Occupied then
         Accepted := False;
         return;
      end if;

      -- If already in position with verified microswitch detection, no motor throw needed
      if Switch.Position = Target and then Has_Verified_Detection (Switch, Target) then
         Accepted := True;
         return;
      end if;

      -- Initiate physical motor transit
      Switch.Target_Position         := Target;
      Switch.Position                := Switch_In_Transit;
      Switch.Normal_Detection_Relay  := False;
      Switch.Reverse_Detection_Relay := False;
      Switch.Stroke_Timer_Ms         := Default_Throw_Duration_Ms;
      Accepted := True;
   end Request_Throw;

   procedure Update_Stroke_Timer
     (Switch   : in out Turnout_Switch;
      Delta_Ms : Positive)
   is
   begin
      if Switch.Position /= Switch_In_Transit then
         return;
      end if;

      if Switch.Stroke_Timer_Ms <= Delta_Ms then
         Switch.Stroke_Timer_Ms := 0;

         -- Check if physical obstacle (ballast rock, ice) stalled the switch blades
         if Switch.Obstacle_Stall_Fault then
            Switch.Position                := Switch_Lost_Detection;
            Switch.Normal_Detection_Relay  := False;
            Switch.Reverse_Detection_Relay := False;
         else
            -- Completed travel successfully; lock detection contacts
            Switch.Position := Switch.Target_Position;
            if Switch.Position = Switch_Normal then
               Switch.Normal_Detection_Relay  := True;
               Switch.Reverse_Detection_Relay := False;
            else
               Switch.Normal_Detection_Relay  := False;
               Switch.Reverse_Detection_Relay := True;
            end if;
         end if;
      else
         Switch.Stroke_Timer_Ms := Switch.Stroke_Timer_Ms - Delta_Ms;
      end if;
   end Update_Stroke_Timer;

   procedure Lock_For_Route
     (Switch : in out Turnout_Switch;
      Route  : Route_Id)
   is
   begin
      Switch.Is_Mechanically_Locked := True;
      Switch.Locked_By_Route        := Route;
   end Lock_For_Route;

   procedure Unlock_From_Route (Switch : in out Turnout_Switch) is
   begin
      Switch.Is_Mechanically_Locked := False;
      Switch.Locked_By_Route        := Null_Route_Id;
   end Unlock_From_Route;

   function Has_Verified_Detection
     (Switch : Turnout_Switch;
      Pos    : Switch_Position) return Boolean
   is
   begin
      if Pos = Switch_Normal then
         return Switch.Position = Switch_Normal and Switch.Normal_Detection_Relay;
      elsif Pos = Switch_Reverse then
         return Switch.Position = Switch_Reverse and Switch.Reverse_Detection_Relay;
      else
         return False;
      end if;
   end Has_Verified_Detection;

   procedure Inject_Obstacle_Stall (Switch : in out Turnout_Switch; Fault_Active : Boolean) is
   begin
      Switch.Obstacle_Stall_Fault := Fault_Active;
   end Inject_Obstacle_Stall;

   procedure Inject_Trailing_Cut (Switch : in out Turnout_Switch) is
   begin
      Switch.Trailing_Cut_Detected   := True;
      Switch.Position                := Switch_Lost_Detection;
      Switch.Normal_Detection_Relay  := False;
      Switch.Reverse_Detection_Relay := False;
   end Inject_Trailing_Cut;

end Aspect.Topology.Switches;
