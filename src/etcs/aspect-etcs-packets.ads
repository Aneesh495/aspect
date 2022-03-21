-- ETCS Subset-026 Chapter 7 bitstream packets for track-to-train transmission.
-- Implements encoding and decoding for Packet 3 (National Values), Packet 5 (Linking),
-- Packet 12 (Movement Authority), Packet 21 (Gradient), and Packet 27 (Static Speed).

with Aspect.Types; use Aspect.Types;
with Aspect.ETCS; use Aspect.ETCS;
with Aspect.CRC; use Aspect.CRC;
with Interfaces; use Interfaces;

package Aspect.ETCS.Packets is

   Max_Gradient_Segments : constant Positive := 16;
   Max_Speed_Segments    : constant Positive := 16;
   Max_Linking_Balises   : constant Positive := 8;

   ----------------------------------------------------------------------------
   -- Packet 3: National Values
   ----------------------------------------------------------------------------
   type Packet_3_National_Values is record
      V_NVSTSR   : Speed_Kph  := 40.0;   -- Shunting speed limit
      V_NVONSIGHT: Speed_Kph  := 30.0;   -- On-Sight speed limit
      V_NVUNFIT  : Speed_Kph  := 100.0;  -- Unfitted line speed limit
      V_NVREL    : Speed_Kph  := 25.0;   -- Standard release speed
      D_NVROLL   : Distance_M := 2.0;    -- Roll-away distance threshold
      T_NVCONTACT: Positive   := 30;     -- Radio supervisory timeout (seconds)
   end record;

   ----------------------------------------------------------------------------
   -- Packet 5: Balise Linking Information
   ----------------------------------------------------------------------------
   type Linking_Entry is record
      Distance_To_Next : Distance_M := 1000.0;
      Next_Group_Id    : Natural    := 0;
      Reaction_On_Miss : Positive   := 1; -- 1: Apply Service Brake, 2: Apply Emergency Brake
   end record;

   type Linking_List is array (1 .. Max_Linking_Balises) of Linking_Entry;

   type Packet_5_Linking is record
      Entries     : Linking_List := [others => <>];
      Entry_Count : Natural      := 0;
   end record;

   ----------------------------------------------------------------------------
   -- Packet 12: Movement Authority (Level 2/3)
   ----------------------------------------------------------------------------
   type Packet_12_Movement_Authority is record
      V_MAIN          : Speed_Kph  := 160.0; -- Maximum line speed under MA
      Distance_To_EoA : Distance_M := 5000.0;-- Distance to End of Authority
      Distance_To_SvL : Distance_M := 5200.0;-- Distance to Supervised Location
      Release_Speed   : Speed_Kph  := 25.0;  -- Release speed for approaching EoA
      Timeout_Seconds : Positive   := 300;   -- MA validity duration
   end record;

   ----------------------------------------------------------------------------
   -- Packet 21: Gradient Profile
   ----------------------------------------------------------------------------
   type Gradient_Step is record
      Start_Distance : Distance_M         := 0.0;
      Gradient       : Gradient_Per_Mille := 0.0;
   end record;

   type Gradient_Step_List is array (1 .. Max_Gradient_Segments) of Gradient_Step;

   type Packet_21_Gradient_Profile is record
      Steps      : Gradient_Step_List := [others => <>];
      Step_Count : Natural            := 0;
   end record;

   ----------------------------------------------------------------------------
   -- Packet 27: International Static Speed Profile (SSP)
   ----------------------------------------------------------------------------
   type Speed_Step is record
      Start_Distance : Distance_M := 0.0;
      Speed_Limit    : Speed_Kph  := 160.0;
   end record;

   type Speed_Step_List is array (1 .. Max_Speed_Segments) of Speed_Step;

   type Packet_27_Static_Speed_Profile is record
      Steps      : Speed_Step_List := [others => <>];
      Step_Count : Natural         := 0;
   end record;

   ----------------------------------------------------------------------------
   -- Binary Serialization and Parsing
   ----------------------------------------------------------------------------

   -- Encodes Packet 12 into byte stream for Euroradio transmission
   procedure Encode_Packet_12
     (P       : Packet_12_Movement_Authority;
      Buffer  : out Byte_Array;
      Written : out Natural);

   -- Decodes Packet 12 from byte stream
   procedure Decode_Packet_12
     (Buffer  : Byte_Array;
      P       : out Packet_12_Movement_Authority;
      Success : out Boolean);

   -- Encodes Packet 21 into byte stream
   procedure Encode_Packet_21
     (P       : Packet_21_Gradient_Profile;
      Buffer  : out Byte_Array;
      Written : out Natural);

   -- Decodes Packet 21 from byte stream
   procedure Decode_Packet_21
     (Buffer  : Byte_Array;
      P       : out Packet_21_Gradient_Profile;
      Success : out Boolean);

   -- Encodes Packet 27 into byte stream
   procedure Encode_Packet_27
     (P       : Packet_27_Static_Speed_Profile;
      Buffer  : out Byte_Array;
      Written : out Natural);

   -- Decodes Packet 27 from byte stream
   procedure Decode_Packet_27
     (Buffer  : Byte_Array;
      P       : out Packet_27_Static_Speed_Profile;
      Success : out Boolean);

end Aspect.ETCS.Packets;
