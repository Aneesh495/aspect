-- Railway lineside color-light signals, multi-aspect cascading, and lamp monitoring.
-- Implements 4-aspect signaling (Clear, Preliminary Caution, Caution, Stop),
-- approach locking timers, and fail-safe filament current sensing.

with Aspect.Types; use Aspect.Types;
with Aspect.Topology; use Aspect.Topology;

package Aspect.Topology.Signals is

   -- Standard approach locking release timeout (120 seconds in milliseconds)
   Default_Approach_Timeout_Ms : constant Positive := 120_000;

   type Railway_Signal is record
      Id                      : Signal_Id_Base   := Null_Signal_Id;
      Name                    : String (1 .. 16) := [others => ' '];
      Name_Len                : Natural          := 0;
      Category                : Signal_Category  := Category_Main;

      -- Topological Placement
      Track_Section           : Section_Id_Base  := Null_Section_Id;
      Approach_Section        : Section_Id_Base  := Null_Section_Id;
      Next_Signal             : Signal_Id_Base   := Null_Signal_Id;
      Chainage                : Track_Chainage   := 0.0;
      Governed_Direction      : Direction_Type   := Dir_Nominal;

      -- Aspect Display State
      Current_Aspect          : Signal_Aspect    := Aspect_Stop;
      Commanded_Aspect        : Signal_Aspect    := Aspect_Stop;

      -- Electrical Health and Filament Monitoring
      Lamp_Health_Relay       : Boolean          := True;
      Filament_Burnout_Fault  : Boolean          := False;

      -- Approach Locking Timer Mechanics
      Approach_Locked         : Boolean          := False;
      Approach_Timer_Ms       : Natural          := 0;
   end record;

   type Railway_Signal_Array is array (Signal_Id) of Railway_Signal;

   procedure Initialize_Signal
     (Signal        : out Railway_Signal;
      Id            : Signal_Id;
      Name          : String;
      Category      : Signal_Category;
      Section       : Section_Id;
      Approach_Sec  : Section_Id;
      Next_Sig      : Signal_Id_Base;
      Chainage      : Track_Chainage;
      Direction     : Direction_Type := Dir_Nominal);

   -- Commands signal to target aspect, verifying electrical lamp integrity
   procedure Set_Aspect
     (Signal : in out Railway_Signal;
      Aspect : Signal_Aspect);

   -- Computes multi-aspect cascade (Stop -> Caution -> Preliminary Caution -> Clear)
   function Compute_Cascade_Aspect
     (Next_Aspect : Signal_Aspect;
      Path_Clear  : Boolean) return Signal_Aspect;

   -- Instantaneous fail-safe trip to danger (Red)
   procedure Drop_To_Danger (Signal : in out Railway_Signal) with
     Post => Signal.Current_Aspect = Aspect_Stop;

   -- Cyclic tick updating approach locking countdown timer
   procedure Update_Approach_Timer
     (Signal          : in out Railway_Signal;
      Approach_Occupied: Boolean;
      Delta_Ms        : Positive);

   -- Fault injection
   procedure Inject_Lamp_Burnout (Signal : in out Railway_Signal; Fault_Active : Boolean);

end Aspect.Topology.Signals;
