-- Geographic interlocking matrix and conflicting route exclusion table.
-- Automatically analyzes topological overlaps, opposing movements,
-- and switch contention to enforce mutual exclusion invariants.

with Aspect.Types; use Aspect.Types;
with Aspect.Interlocking.Routes; use Aspect.Interlocking.Routes;

package Aspect.Interlocking.Locking_Table is

   type Conflict_List is array (1 .. Max_Conflicts_Per_Route) of Route_Id_Base;

   type Route_Conflict_Entry is record
      Conflicts      : Conflict_List := [others => Null_Route_Id];
      Conflict_Count : Natural       := 0;
   end record;

   type Locking_Matrix is array (Route_Id) of Route_Conflict_Entry;

   type Interlocking_Table is record
      Matrix      : Locking_Matrix := [others => <>];
      Route_Count : Natural        := 0;
   end record;

   procedure Initialize_Table (Table : out Interlocking_Table);

   -- Registers a bidirectional mutual exclusion between Route A and Route B
   procedure Register_Conflict
     (Table   : in out Interlocking_Table;
      Route_A : Route_Id;
      Route_B : Route_Id);

   -- Automatically computes conflicting routes by inspecting track sections,
   -- switch positions, and opposing running directions
   procedure Synthesize_Conflicts
     (Table  : in out Interlocking_Table;
      Routes : Route_Array;
      Count  : Natural);

   -- Checks whether any route conflicting with Target_Route is currently active
   function Has_Active_Conflict
     (Table        : Interlocking_Table;
      Routes       : Route_Array;
      Target_Route : Route_Id) return Boolean;

   function Are_Conflicting
     (Table   : Interlocking_Table;
      Route_A : Route_Id;
      Route_B : Route_Id) return Boolean;

end Aspect.Interlocking.Locking_Table;
