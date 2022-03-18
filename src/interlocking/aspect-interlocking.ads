-- Master package specification for the Computer-Based Interlocking (CBI).
-- Implements EN 50128 SIL 4 vital safety logic, route reservation lifecycles,
-- geographic interlocking tables, and fail-safe interlocking state machines.

with Aspect.Types; use Aspect.Types;

package Aspect.Interlocking with
   Pure
is

   -- Interlocking cycle execution intervals
   Interlocking_Tick_Ms : constant Positive := 50;

   -- Maximum conflicting routes per route in the locking table
   Max_Conflicts_Per_Route : constant Positive := 16;
   Max_Switches_Per_Route  : constant Positive := 16;
   Max_Sections_Per_Route  : constant Positive := 32;
   Max_Flank_Protections   : constant Positive := 8;

   type Interlocking_Command_Kind is (
      Cmd_None,
      Cmd_Set_Route,
      Cmd_Cancel_Route,
      Cmd_Emergency_Stop_Route,
      Cmd_Emergency_Stop_All,
      Cmd_Manual_Switch_Throw,
      Cmd_Acknowledge_Alarm
   );

   type Interlocking_Command is record
      Kind       : Interlocking_Command_Kind := Cmd_None;
      Route      : Route_Id_Base             := Null_Route_Id;
      Sw_Id      : Switch_Id_Base            := Null_Switch_Id;
      Sw_Target  : Switch_Position           := Switch_Normal;
      Issuer_Id  : Natural                   := 0;
   end record;

   type Rejection_Reason is (
      Reject_None,
      Reject_Route_Already_Active,
      Reject_Conflicting_Route_Locked,
      Reject_Section_Occupied,
      Reject_Switch_Detector_Locked,
      Reject_Switch_Throw_Failed,
      Reject_Flank_Protection_Failed,
      Reject_Overlap_Unavailable,
      Reject_Signal_Lamp_Fault,
      Reject_Approach_Locked,
      Reject_Emergency_Active
   );

end Aspect.Interlocking;
