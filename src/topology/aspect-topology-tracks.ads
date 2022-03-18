-- Track circuit block sections and axle counter detection zones.
-- Implements electrical shunting, axle balancing, ballast disturbance detection,
-- and fail-safe vital occupancy state logic.

package Aspect.Topology.Tracks is

   type Detection_Technology is (
      Tech_DC_Track_Circuit,          -- Direct-current track circuit with gravity relay
      Tech_Audio_Frequency_Track,     -- Coded audio-frequency track circuit (jointless)
      Tech_Dual_Wheel_Axle_Counter    -- Axle counter head with magnetic wheel sensors
   );

   type Section_Lock_Kind is (
      Lock_None,              -- Idle and free for interlocking reservation
      Lock_Route_Reserved,    -- Reserved as part of an active train route
      Lock_Overlap_Reserved   -- Reserved as safety overrun protection buffer
   );

   type Track_Section is record
      Id                  : Section_Id_Base       := Null_Section_Id;
      Name                : String (1 .. 16)      := [others => ' '];
      Name_Len            : Natural               := 0;
      Technology          : Detection_Technology  := Tech_DC_Track_Circuit;
      Length_M            : Distance_M            := 500.0;
      Start_Chainage      : Track_Chainage        := 0.0;
      End_Chainage        : Track_Chainage        := 500.0;
      Line_Speed_Limit    : Speed_Kph             := 160.0;
      Gradient            : Gradient_Per_Mille    := 0.0;
      Curvature_Radius    : Distance_M            := 0.0; -- 0.0 represents straight tangent track

      -- Vital Electrical and Detection Relay States
      Occupancy           : Occupancy_State       := State_Clear;
      Relay_Energized     : Boolean               := True;
      Axle_In_Count       : Natural               := 0;
      Axle_Out_Count      : Natural               := 0;
      Ballast_Resistance  : Float                 := 100.0; -- Ohms (critical limit < 2.5 ohms)
      Broken_Rail_Fault   : Boolean               := False;

      -- Interlocking Lock Status
      Lock_Status         : Section_Lock_Kind     := Lock_None;
      Locked_By_Route     : Route_Id_Base         := Null_Route_Id;
      Occupying_Train     : Train_Id_Base         := Null_Train_Id;
   end record;

   type Track_Section_Array is array (Section_Id) of Track_Section;

   -- Initializes a track section with physical properties
   procedure Initialize_Section
     (Section     : out Track_Section;
      Id          : Section_Id;
      Name        : String;
      Length_M    : Distance_M;
      Start_Km    : Track_Chainage;
      Line_Speed  : Speed_Kph;
      Gradient    : Gradient_Per_Mille;
      Tech        : Detection_Technology := Tech_DC_Track_Circuit);

   -- Vital state evaluation evaluating electrical ballast and axle counts
   procedure Evaluate_Vital_Occupancy (Section : in out Track_Section);

   -- Shunts track section when train wheelset enters
   procedure Shunt_By_Train
     (Section : in out Track_Section;
      Train   : Train_Id);

   -- Clears shunt when train completely vacates section
   procedure Clear_Train_Shunt
     (Section : in out Track_Section;
      Train   : Train_Id);

   -- Axle counter pulses
   procedure Register_Axle_In (Section : in out Track_Section);
   procedure Register_Axle_Out (Section : in out Track_Section);

   -- Safety fault injections
   procedure Set_Broken_Rail (Section : in out Track_Section; Fault_Active : Boolean);
   procedure Set_Ballast_Resistance (Section : in out Track_Section; Resistance_Ohms : Float);

   -- Interlocking locking and unlocking
   procedure Lock_Section
     (Section   : in out Track_Section;
      Route     : Route_Id;
      Lock_Type : Section_Lock_Kind) with
     Pre  => Section.Lock_Status = Lock_None,
     Post => Section.Lock_Status = Lock_Type and Section.Locked_By_Route = Route;

   procedure Unlock_Section (Section : in out Track_Section) with
     Post => Section.Lock_Status = Lock_None and Section.Locked_By_Route = Null_Route_Id;

   function Is_Clear_And_Unlocked (Section : Track_Section) return Boolean is
     (Section.Occupancy = State_Clear and Section.Lock_Status = Lock_None);

end Aspect.Topology.Tracks;
