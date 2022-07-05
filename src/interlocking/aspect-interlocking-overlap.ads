-- Safety overlap protection beyond destination signals.
-- Manages overrun reservation buffers, points within the overlap zone,
-- and dynamic standstill timer releases.

with Aspect.Topology.Network; use Aspect.Topology.Network;

package Aspect.Interlocking.Overlap is

   -- Standard train standstill confirmation timer before overlap can be released (30 seconds)
   Standstill_Release_Timeout_Ms : constant Positive := 30_000;

   type Overlap_Record is record
      Route_Id_Ref       : Route_Id_Base    := Null_Route_Id;
      Section_Id_Ref     : Section_Id_Base  := Null_Section_Id;
      Overlap_Length     : Distance_M       := 200.0;
      Is_Reserved        : Boolean          := False;
      Standstill_Timer_Ms: Natural          := 0;
      Train_At_Standstill: Boolean          := False;
   end record;

   type Overlap_Array is array (Route_Id) of Overlap_Record;

   procedure Initialize_Overlap_Table (Table : out Overlap_Array);

   -- Evaluates whether the overlap track section is free and unlocked
   function Can_Reserve_Overlap
     (Net     : Railway_Network;
      Section : Section_Id) return Boolean;

   -- Reserves overlap section and locks it in the track topology
   procedure Reserve_Overlap
     (Table   : in out Overlap_Array;
      Net     : in out Railway_Network;
      Route   : Route_Id;
      Section : Section_Id;
      Dist_M  : Distance_M;
      Success : out Boolean);

   -- Releases overlap reservation
   procedure Release_Overlap
     (Table   : in out Overlap_Array;
      Net     : in out Railway_Network;
      Route   : Route_Id);

   -- Updates standstill timer when train is confirmed stationary at destination signal
   procedure Update_Standstill_Timer
     (Table    : in out Overlap_Array;
      Net      : in out Railway_Network;
      Route    : Route_Id;
      At_Rest  : Boolean;
      Delta_Ms : Positive);

end Aspect.Interlocking.Overlap;
