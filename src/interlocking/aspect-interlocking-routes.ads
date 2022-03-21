-- Interlocking route definitions, switch alignment requirements,
-- and route lifecycle state transitions.

with Aspect.Types; use Aspect.Types;

package Aspect.Interlocking.Routes is

   type Switch_Alignment is record
      Switch   : Switch_Id_Base := Null_Switch_Id;
      Position : Switch_Position := Switch_Normal;
   end record;

   type Switch_Requirement_Array is array (1 .. Max_Switches_Per_Route) of Switch_Alignment;
   type Section_Id_Array is array (1 .. Max_Sections_Per_Route) of Section_Id_Base;

   type Interlocking_Route is record
      Id                  : Route_Id_Base            := Null_Route_Id;
      Name                : String (1 .. 16)         := [others => ' '];
      Name_Len            : Natural                  := 0;
      Class               : Route_Class              := Class_Main_Train;

      -- Boundary Signals
      Origin_Signal       : Signal_Id_Base           := Null_Signal_Id;
      Exit_Signal         : Signal_Id_Base           := Null_Signal_Id;

      -- Route Path Sections
      Path_Sections       : Section_Id_Array         := [others => Null_Section_Id];
      Section_Count       : Natural                  := 0;

      -- Turnout Switch Alignments
      Required_Switches   : Switch_Requirement_Array := [others => <>];
      Switch_Count        : Natural                  := 0;

      -- Overlap Protection beyond Exit Signal
      Overlap_Section     : Section_Id_Base          := Null_Section_Id;
      Overlap_Distance    : Distance_M               := 200.0;
      Overlap_Timer_Ms    : Natural                  := 0;

      -- Lifecycle State
      State               : Route_State              := Route_Unset;
      Assigned_Train      : Train_Id_Base            := Null_Train_Id;
      Current_Section_Idx : Natural                  := 0;
   end record;

   type Route_Array is array (Route_Id) of Interlocking_Route;

   procedure Initialize_Route
     (Route       : out Interlocking_Route;
      Id          : Route_Id;
      Name        : String;
      Origin_Sig  : Signal_Id;
      Exit_Sig    : Signal_Id_Base := Null_Signal_Id;
      Class       : Route_Class    := Class_Main_Train);

   procedure Add_Section
     (Route   : in out Interlocking_Route;
      Section : Section_Id);

   procedure Add_Switch_Alignment
     (Route    : in out Interlocking_Route;
      Switch   : Switch_Id;
      Position : Switch_Position);

   procedure Set_Overlap_Protection
     (Route   : in out Interlocking_Route;
      Overlap : Section_Id;
      Dist_M  : Distance_M);

   -- Validates and executes state transitions
   procedure Transition_State
     (Route     : in out Interlocking_Route;
      New_State : Route_State;
      Success   : out Boolean);

   function Is_Active (Route : Interlocking_Route) return Boolean is
     (Route.State in Route_Requested | Route_Interlocked | Route_Cleared |
                     Route_Approached | Route_Occupied | Route_Sectional_Release);

end Aspect.Interlocking.Routes;
