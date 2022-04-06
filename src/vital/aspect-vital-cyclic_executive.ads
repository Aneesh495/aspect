-- Deterministic Ravenscar-compliant cyclic executive.
-- Orchestrates 50ms minor cycles and 200ms major cycles across triplicated channels,
-- synchronizing inputs, arbitrating 2oo3 voting, and executing safety barrier invariants.

with Aspect.Types; use Aspect.Types;
with Aspect.Interlocking; use Aspect.Interlocking;
with Aspect.Vital.Channels; use Aspect.Vital.Channels;
with Aspect.Interlocking.Engine; use Aspect.Interlocking.Engine;

package Aspect.Vital.Cyclic_Executive is

   type Executive_Metrics is record
      Total_Cycles_Executed : Tick_Count := 0;
      Tripped_Cycles        : Natural    := 0;
      Divergence_Events     : Natural    := 0;
      Last_Invariant_Passed : Boolean    := True;
   end record;

   type Vital_Supervisor is record
      Channels  : Triplicated_Channels;
      Metrics   : Executive_Metrics;
      Is_Halted : Boolean := False;
   end record;

   procedure Initialize_Supervisor
     (Supervisor   : out Vital_Supervisor;
      Initial_Core : Interlocking_Core);

   -- Executes a single deterministic 50ms minor cycle across all channels
   procedure Execute_Minor_Cycle
     (Supervisor : in out Vital_Supervisor;
      Delta_Ms   : Positive := Minor_Cycle_Ms);

   -- Ingests dispatcher command and fans out to all active channels
   procedure Dispatch_Command
     (Supervisor : in out Vital_Supervisor;
      Cmd        : Interlocking_Command);

   -- Retrieves voted consensus state from the healthy majority
   function Get_Voted_Core
     (Supervisor : Vital_Supervisor) return Interlocking_Core;

end Aspect.Vital.Cyclic_Executive;
