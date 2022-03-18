-- Master geographic railway network graph.
-- Coordinates track blocks, turnout switch connections, lineside signals,
-- and balise transmission points with path validation and adjacency routing.

with Aspect.Topology.Tracks; use Aspect.Topology.Tracks;
with Aspect.Topology.Switches; use Aspect.Topology.Switches;
with Aspect.Topology.Signals; use Aspect.Topology.Signals;
with Aspect.Topology.Balises; use Aspect.Topology.Balises;

package Aspect.Topology.Network is

   type Section_List is array (Positive range <>) of Section_Id;

   -- Adjacency record linking a track section to adjacent sections in nominal/reverse directions
   type Section_Adjacency is record
      Nominal_Next : Section_Id_Base := Null_Section_Id;
      Reverse_Next : Section_Id_Base := Null_Section_Id;
      Switch_Bound : Switch_Id_Base  := Null_Switch_Id; -- Switch located at boundary, if any
   end record;

   type Adjacency_Map is array (Section_Id) of Section_Adjacency;

   type Railway_Network is record
      Section_Count : Natural := 0;
      Switch_Count  : Natural := 0;
      Signal_Count  : Natural := 0;
      Balise_Count  : Natural := 0;

      Sections      : Track_Section_Array  := [others => <>];
      Switches      : Turnout_Switch_Array := [others => <>];
      Signals       : Railway_Signal_Array := [others => <>];
      Balises       : Eurobalise_Array     := [others => <>];

      Adjacency     : Adjacency_Map        := [others => <>];
   end record;

   procedure Initialize_Network (Net : out Railway_Network);

   procedure Register_Section
     (Net     : in out Railway_Network;
      Section : Track_Section);

   procedure Register_Switch
     (Net    : in out Railway_Network;
      Switch : Turnout_Switch);

   procedure Register_Signal
     (Net    : in out Railway_Network;
      Signal : Railway_Signal);

   procedure Register_Balise
     (Net    : in out Railway_Network;
      Balise : Eurobalise);

   -- Registers direct adjacency between two linear track blocks
   procedure Link_Sections
     (Net      : in out Railway_Network;
      From_Sec : Section_Id;
      To_Sec   : Section_Id;
      Dir      : Direction_Type := Dir_Nominal);

   -- Returns the next downstream track section given current position, direction,
   -- and active turnout switch alignments:
   function Next_Section
     (Net      : Railway_Network;
      Current  : Section_Id;
      Dir      : Direction_Type) return Section_Id_Base;

   -- Computes cumulative physical distance along a contiguous sequence of sections
   function Compute_Path_Distance
     (Net      : Railway_Network;
      Path     : Section_List) return Distance_M with
     Post => Compute_Path_Distance'Result >= 0.0;

   -- Computes the minimum civil line speed restriction across a list of sections
   function Minimum_Speed_Along_Path
     (Net      : Railway_Network;
      Path     : Section_List) return Speed_Kph;

   -- Validates topological integrity (no orphaned references or dangling IDs)
   function Verify_Integrity (Net : Railway_Network) return Boolean;

end Aspect.Topology.Network;
