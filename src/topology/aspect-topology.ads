-- Master package specification for geographic track topology.
-- Defines track coordinate geometry, node descriptors, and spatial structures
-- used by the Computer-Based Interlocking and ETCS track models.

with Aspect.Types; use Aspect.Types;

package Aspect.Topology with
   Pure
is

   ----------------------------------------------------------------------------
   -- Spatial Coordinates and Track Kilometrage
   ----------------------------------------------------------------------------

   type Track_Chainage is digits 9 range 0.0 .. 1_000_000.0; -- Chainage in meters
   type Elevation_M is digits 7 range -500.0 .. 5000.0;       -- Elevation above sea level

   type Geo_Coordinate is record
      Chainage  : Track_Chainage := 0.0;
      Elevation : Elevation_M    := 0.0;
   end record;

   -- Topological node types representing boundaries between physical rail assets
   type Node_Type is (
      Node_Block_Joint,      -- Insulated block joint separating track circuits
      Node_Turnout_Toe,      -- Facing point entrance of a switch
      Node_Turnout_Heel_Norm,-- Trailing point heel of switch normal leg
      Node_Turnout_Heel_Rev, -- Trailing point heel of switch reverse leg
      Node_Buffer_Stop,      -- Physical terminus / end of line
      Node_Station_Boundary  -- Station limit or interlocking perimeter
   );

   type Topology_Node is record
      Id        : Natural   := 0;
      Kind      : Node_Type := Node_Block_Joint;
      Location  : Geo_Coordinate;
   end record;

   -- Computes chainage distance between two geographic coordinates
   function Coordinate_Distance
     (From_Coord : Geo_Coordinate;
      To_Coord   : Geo_Coordinate) return Distance_M with
     Post => Coordinate_Distance'Result >= 0.0;

end Aspect.Topology;
