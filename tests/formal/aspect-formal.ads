-- Root package for formal verification oracles and property-based test rigs.
-- Standards: EN 50128 SIL 4 / CENELEC software safety integrity level 4.

package Aspect.Formal with
   Pure
is

   -- Maximum allowable random test dispatches in fuzzing and property tests
   Default_Formal_Iterations : constant Positive := 10_000;

end Aspect.Formal;
