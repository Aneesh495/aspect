-- Approach locking safety engine.
-- Enforces run-approach safety timers preventing instant route cancellation
-- when an oncoming train has already entered the signal sighting envelope.

with Aspect.Types; use Aspect.Types;
with Aspect.Topology.Network; use Aspect.Topology.Network;
with Aspect.Interlocking.Routes; use Aspect.Interlocking.Routes;

package Aspect.Interlocking.Approach is

   type Cancellation_Status is (
      Cancel_Immediate,         -- Approach unoccupied; route released immediately
      Cancel_Approach_Timer,    -- Train approaching; timer active; points remain locked
      Cancel_Rejected           -- Route not active or train already occupying route
   );

   type Approach_Lock_Record is record
      Route_Ref        : Route_Id_Base := Null_Route_Id;
      Timer_Active     : Boolean       := False;
      Timer_Remaining  : Natural       := 0;
   end record;

   type Approach_Table is array (Route_Id) of Approach_Lock_Record;

   procedure Initialize_Approach_Table (Table : out Approach_Table);

   -- Evaluates dispatcher cancellation request against approach occupancy
   procedure Request_Cancellation
     (Table   : in out Approach_Table;
      Net     : in out Railway_Network;
      Route   : in out Interlocking_Route;
      Status  : out Cancellation_Status);

   -- Cyclic tick updating countdown timers
   procedure Update_Approach_Timers
     (Table    : in out Approach_Table;
      Net      : in out Railway_Network;
      Routes   : in out Route_Array;
      Delta_Ms : Positive);

   function Is_Under_Approach_Lock
     (Table : Approach_Table;
      Route : Route_Id) return Boolean;

end Aspect.Interlocking.Approach;
