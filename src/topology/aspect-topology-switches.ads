-- Turnout point machines, switch throw mechanisms, and microswitch detection circuits.
-- Implements mechanical locking bars, detector occupancy locking, stroke timers,
-- and trail-through shear pin failure detection.

package Aspect.Topology.Switches is

   -- Standard point machine electric motor stroke duration (3.5 seconds)
   Default_Throw_Duration_Ms : constant Positive := 3500;

   type Turnout_Switch is record
      Id                     : Switch_Id_Base   := Null_Switch_Id;
      Name                   : String (1 .. 16) := [others => ' '];
      Name_Len               : Natural          := 0;

      -- Physical track section IDs for topological routing
      Point_Section          : Section_Id_Base  := Null_Section_Id;
      Facing_Section         : Section_Id_Base  := Null_Section_Id;
      Normal_Section         : Section_Id_Base  := Null_Section_Id;
      Reverse_Section        : Section_Id_Base  := Null_Section_Id;

      -- Divergence speed ratings
      Speed_Limit_Normal     : Speed_Kph        := 160.0;
      Speed_Limit_Reverse    : Speed_Kph        := 60.0;

      -- Operational State and Motor Drive
      Position               : Switch_Position  := Switch_Normal;
      Target_Position        : Switch_Position  := Switch_Normal;
      Stroke_Timer_Ms        : Natural          := 0;

      -- Vital Microswitch Point Detection Relays (< 3.5mm switch blade gap)
      Normal_Detection_Relay : Boolean          := True;
      Reverse_Detection_Relay: Boolean          := False;

      -- Mechanical / Electrical Locking
      Is_Mechanically_Locked : Boolean          := False;
      Locked_By_Route        : Route_Id_Base    := Null_Route_Id;

      -- Safety Hazard and Disturbance Flags
      Obstacle_Stall_Fault   : Boolean          := False;
      Trailing_Cut_Detected  : Boolean          := False;
   end record;

   type Turnout_Switch_Array is array (Switch_Id) of Turnout_Switch;

   procedure Initialize_Switch
     (Switch         : out Turnout_Switch;
      Id             : Switch_Id;
      Name           : String;
      Point_Section  : Section_Id;
      Facing_Section : Section_Id;
      Normal_Section : Section_Id;
      Reverse_Section: Section_Id;
      Speed_Norm     : Speed_Kph := 160.0;
      Speed_Rev      : Speed_Kph := 60.0);

   -- Initiates point machine motor throw to commanded target position.
   -- Fails if mechanically locked or detector track circuit is occupied.
   procedure Request_Throw
     (Switch         : in out Turnout_Switch;
      Target         : Switch_Position;
      Track_Occupied : Boolean;
      Accepted       : out Boolean);

   -- Cyclic tick processing motor transit timing and detection pickup
   procedure Update_Stroke_Timer
     (Switch    : in out Turnout_Switch;
      Delta_Ms  : Positive);

   -- Interlocking route locking
   procedure Lock_For_Route
     (Switch : in out Turnout_Switch;
      Route  : Route_Id) with
     Pre  => not Switch.Is_Mechanically_Locked,
     Post => Switch.Is_Mechanically_Locked and Switch.Locked_By_Route = Route;

   procedure Unlock_From_Route (Switch : in out Turnout_Switch) with
     Post => not Switch.Is_Mechanically_Locked and Switch.Locked_By_Route = Null_Route_Id;

   -- Vital detection queries
   function Has_Verified_Detection
     (Switch : Turnout_Switch;
      Pos    : Switch_Position) return Boolean;

   -- Fault injection routines
   procedure Inject_Obstacle_Stall (Switch : in out Turnout_Switch; Fault_Active : Boolean);
   procedure Inject_Trailing_Cut (Switch : in out Turnout_Switch);

end Aspect.Topology.Switches;
