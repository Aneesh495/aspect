-- Master package specification for the EN 50128 SIL 4 vital executive.
-- Implements triple-modular redundancy (2oo3 TMR), Byzantine fault tolerance,
-- deterministic cyclic executive scheduling, and independent safety barrier invariant checks.

package Aspect.Vital with
   Pure
is

   -- Maximum allowable consecutive divergence cycles before channel is permanently isolated
   Max_Consecutive_Divergences : constant Positive := 3;

   -- Maximum allowable cycle execution jitter in microseconds
   Max_Permitted_Jitter_Us     : constant Positive := 5000;

   type System_Operational_Mode is (
      Mode_Triplicated_3oo3,   -- All 3 channels healthy and participating in majority vote
      Mode_Degraded_2oo2,      -- 1 channel tripped/isolated; dual redundant consensus required
      Mode_Tripped_Fail_Safe   -- Safety barrier violated or consensus lost; system shut down
   );

end Aspect.Vital;
