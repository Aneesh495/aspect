package body Aspect.Topology is

   function Coordinate_Distance
     (From_Coord : Geo_Coordinate;
      To_Coord   : Geo_Coordinate) return Distance_M
   is
      D : constant Float := abs (Float (To_Coord.Chainage) - Float (From_Coord.Chainage));
   begin
      if D > 100_000.0 then
         return 100_000.0;
      else
         return Distance_M (D);
      end if;
   end Coordinate_Distance;

end Aspect.Topology;
