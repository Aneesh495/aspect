-- Master package specification for European Train Control System (ETCS) Level 2.
-- Conforms to ERA ETCS Subset-026 System Requirements Specification (v3.6.0).
-- Defines standard variables, bit qualifiers, distance scales, and packet headers.

with Aspect.Types; use Aspect.Types;
with Interfaces; use Interfaces;

package Aspect.ETCS with
   Pure
is

   -- Subset-026 standard specification release identifier
   ETCS_SRS_Version : constant String := "3.6.0";

   ----------------------------------------------------------------------------
   -- Standard Qualifiers (Subset-026 Chapter 7)
   ----------------------------------------------------------------------------

   -- Q_DIR: Direction qualifier of information relative to balise group / train orientation
   type Q_DIR_Type is (
      Q_DIR_Reverse,  -- Valid only in reverse direction
      Q_DIR_Nominal,  -- Valid only in nominal direction
      Q_DIR_Both      -- Valid in both running directions
   );

   -- Q_SCALE: Scale factor for distances and lengths
   type Q_SCALE_Type is (
      Q_SCALE_10cm,   -- 1 unit = 0.1 meters
      Q_SCALE_1m,     -- 1 unit = 1.0 meters
      Q_SCALE_10m     -- 1 unit = 10.0 meters
   );

   -- Converts raw integer scaled value to physical Distance_M
   function Scale_To_Distance
     (Raw_Value : Natural;
      Scale     : Q_SCALE_Type) return Distance_M;

   -- Packet identification numbers (NID_PACKET, 8-bit unsigned)
   type NID_PACKET_Type is new Unsigned_8;

   Packet_Virtual_Balise_Cover : constant NID_PACKET_Type := 0;
   Packet_National_Values      : constant NID_PACKET_Type := 3;
   Packet_Linking              : constant NID_PACKET_Type := 5;
   Packet_Movement_Authority   : constant NID_PACKET_Type := 12;
   Packet_Gradient_Profile     : constant NID_PACKET_Type := 21;
   Packet_Static_Speed_Profile : constant NID_PACKET_Type := 27;
   Packet_Level_Transition     : constant NID_PACKET_Type := 41;
   Packet_End_Of_Information   : constant NID_PACKET_Type := 255;

end Aspect.ETCS;
