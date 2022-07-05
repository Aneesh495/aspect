-- Central Computer-Based Interlocking (CBI) execution kernel.
-- Orchestrates route setting, conflicting route exclusion, detector locking,
-- flank protection, overlap reservation, signal clearing, and sectional route release.

with Aspect.Topology.Network; use Aspect.Topology.Network;
with Aspect.Interlocking.Routes; use Aspect.Interlocking.Routes;
with Aspect.Interlocking.Locking_Table; use Aspect.Interlocking.Locking_Table;
with Aspect.Interlocking.Flank; use Aspect.Interlocking.Flank;
with Aspect.Interlocking.Overlap; use Aspect.Interlocking.Overlap;
with Aspect.Interlocking.Approach; use Aspect.Interlocking.Approach;

package Aspect.Interlocking.Engine is

   type Interlocking_Core is record
      Net                 : Railway_Network;
      Routes              : Route_Array          := [others => <>];
      Route_Count         : Natural              := 0;
      Locking             : Interlocking_Table;
      Flank               : Flank_Table;
      Overlaps            : Overlap_Array;
      Approaches          : Approach_Table;

      -- Safety and Supervisory State
      Cycle_Count         : Tick_Count           := 0;
      Emergency_Stop_All  : Boolean              := False;
   end record;

   procedure Initialize_Core
     (Core : out Interlocking_Core;
      Net  : Railway_Network);

   procedure Register_Route
     (Core  : in out Interlocking_Core;
      Route : Interlocking_Route);

   -- Compiles route dependencies and populates geographic locking table
   procedure Finalize_Configuration (Core : in out Interlocking_Core);

   -- Processes dispatcher commands (Set Route, Cancel, Emergency Stop)
   procedure Execute_Command
     (Core    : in out Interlocking_Core;
      Cmd     : Interlocking_Command;
      Success : out Boolean;
      Reason  : out Rejection_Reason);

   -- Deterministic cyclic executive minor tick (e.g. 50ms)
   procedure Step_Cycle
     (Core     : in out Interlocking_Core;
      Delta_Ms : Positive);

   -- Ingests train entry into track section and processes sectional route release
   procedure Handle_Train_Movement
     (Core        : in out Interlocking_Core;
      Train       : Train_Id;
      Entered_Sec : Section_Id;
      Vacated_Sec : Section_Id_Base := Null_Section_Id);

   -- Global fail-safe emergency stop clamp
   procedure Trigger_Emergency_Stop (Core : in out Interlocking_Core);
   procedure Reset_Emergency_Stop (Core : in out Interlocking_Core);

   function Is_Route_Clear_For_Train
     (Core  : Interlocking_Core;
      Route : Route_Id) return Boolean;

end Aspect.Interlocking.Engine;
