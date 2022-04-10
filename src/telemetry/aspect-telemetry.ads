-- Real-time telemetry snapshot definitions for railway interlocking and ETCS supervision.
-- Provides deterministic capture of vital states, track circuits, point positions,
-- signal aspects, train odometry, and 2oo3 voter agreement metrics.

with Aspect.Types; use Aspect.Types;
with Aspect.Topology; use Aspect.Topology;
with Aspect.Sim.World; use Aspect.Sim.World;

package Aspect.Telemetry is

   Max_Telemetry_Sections : constant := 16;
   Max_Telemetry_Switches : constant := 8;
   Max_Telemetry_Signals  : constant := 16;
   Max_Telemetry_Routes   : constant := 8;
   Max_Telemetry_Trains   : constant := 4;

   type Track_Telemetry is record
      Id           : Section_Id_Base := Null_Section_Id;
      Is_Occupied  : Boolean         := False;
      Is_Locked    : Boolean         := False;
      Ballast_Ohms : Float           := 500.0;
      Axle_Count   : Natural         := 0;
   end record;

   type Track_Telemetry_Array is array (1 .. Max_Telemetry_Sections) of Track_Telemetry;

   type Switch_Telemetry is record
      Id            : Switch_Id_Base  := Null_Switch_Id;
      Position      : Switch_Position := Switch_Normal;
      Blade_Gap_Mm  : Millimeter      := 0;
      Is_Locked     : Boolean         := False;
      Motor_Stalled : Boolean         := False;
      Trail_Through : Boolean         := False;
   end record;

   type Switch_Telemetry_Array is array (1 .. Max_Telemetry_Switches) of Switch_Telemetry;

   type Signal_Telemetry is record
      Id           : Signal_Id_Base := Null_Signal_Id;
      Aspect       : Signal_Aspect  := Aspect_Stop;
      Current_Ma   : Float          := 250.0;
      Lamp_Fault   : Boolean        := False;
   end record;

   type Signal_Telemetry_Array is array (1 .. Max_Telemetry_Signals) of Signal_Telemetry;

   type Route_Telemetry is record
      Id          : Route_Id_Base   := Null_Route_Id;
      State       : Route_State     := Route_Unset;
      Entry_Sig   : Signal_Id_Base  := Null_Signal_Id;
      Exit_Sig    : Signal_Id_Base  := Null_Signal_Id;
      Train       : Train_Id_Base   := Null_Train_Id;
   end record;

   type Route_Telemetry_Array is array (1 .. Max_Telemetry_Routes) of Route_Telemetry;

   type Train_Telemetry is record
      Id               : Train_Id_Base         := Null_Train_Id;
      Chainage_Km      : Track_Chainage        := 0.0;
      Current_Speed    : Aspect.Types.Speed_Kph:= 0.0;
      Permitted_Speed  : Aspect.Types.Speed_Kph:= 0.0;
      Warning_Speed    : Aspect.Types.Speed_Kph:= 0.0;
      SBI_Speed        : Aspect.Types.Speed_Kph:= 0.0;
      EBI_Speed        : Aspect.Types.Speed_Kph:= 0.0;
      Throttle_Pct     : Percent               := 0.0;
      Brake_Pct        : Percent               := 0.0;
      Emergency_Brake  : Boolean               := False;
      Wheel_Slip       : Boolean               := False;
      Section          : Section_Id_Base       := Null_Section_Id;
   end record;

   type Train_Telemetry_Array is array (1 .. Max_Telemetry_Trains) of Train_Telemetry;

   type Voter_Telemetry is record
      Cycle_Count     : Natural         := 0;
      Last_Passed     : Boolean         := True;
      Divergences     : Natural         := 0;
      Tripped_Cycles  : Natural         := 0;
      Is_Degraded     : Boolean         := False;
   end record;

   type Telemetry_Snapshot is record
      Timestamp_Ms : Natural := 0;
      Step_Number  : Natural := 0;

      Section_Count: Natural := 0;
      Sections     : Track_Telemetry_Array := [others => <>];

      Switch_Count : Natural := 0;
      Switches     : Switch_Telemetry_Array := [others => <>];

      Signal_Count : Natural := 0;
      Signals      : Signal_Telemetry_Array := [others => <>];

      Route_Count  : Natural := 0;
      Routes       : Route_Telemetry_Array := [others => <>];

      Train_Count  : Natural := 0;
      Trains       : Train_Telemetry_Array := [others => <>];

      Voter        : Voter_Telemetry;
   end record;

   -- Captures an instantaneous snapshot of the simulation world state
   procedure Capture_Snapshot
     (World    : World_Context;
      Snapshot : out Telemetry_Snapshot);

end Aspect.Telemetry;
