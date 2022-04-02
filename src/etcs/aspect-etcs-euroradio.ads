-- Euroradio safe communication protocol conforming to ETCS Subset-037 / Subset-057.
-- Provides message sequence integrity, timestamp freshness validation,
-- CRC-32C cryptographic frame verification, and radio link watchdogs.

with Aspect.CRC; use Aspect.CRC;

package Aspect.ETCS.Euroradio is

   Max_Radio_Frame_Bytes : constant Positive := 512;

   type Radio_Frame_Data is array (1 .. Max_Radio_Frame_Bytes) of Unsigned_8;

   type Euroradio_Header is record
      Protocol_Version : Unsigned_8  := 1;
      Session_Id       : Unsigned_16 := 0;
      Sequence_Number  : Unsigned_32 := 0;
      Timestamp_Ms     : Unsigned_32 := 0;
      Payload_Length   : Unsigned_16 := 0;
   end record;

   type Euroradio_Frame is record
      Header   : Euroradio_Header;
      Payload  : Radio_Frame_Data := [others => 0];
      Checksum : Unsigned_32      := 0;
   end record;

   type Link_Status is (
      Link_Up,
      Link_Degraded,
      Link_Timeout_Tripped
   );

   type Euroradio_Channel is record
      Session_Id         : Unsigned_16 := 0;
      Expected_Next_Seq  : Unsigned_32 := 1;
      Last_Rx_Timestamp  : Unsigned_32 := 0;
      Watchdog_Timer_S   : Natural     := 30;
      Status             : Link_Status := Link_Up;
   end record;

   procedure Initialize_Channel
     (Chan       : out Euroradio_Channel;
      Session_Id : Unsigned_16;
      Timeout_S  : Positive := 30);

   -- Serializes and signs frame with CRC-32C checksum
   procedure Construct_Frame
     (Chan      : in out Euroradio_Channel;
      Payload   : Byte_Array;
      Length    : Positive;
      Timestamp : Unsigned_32;
      Frame     : out Euroradio_Frame);

   -- Parses and verifies incoming Euroradio frame
   procedure Ingest_Frame
     (Chan    : in out Euroradio_Channel;
      Frame   : Euroradio_Frame;
      Payload : out Byte_Array;
      Length  : out Natural;
      Valid   : out Boolean);

   -- Periodic watchdog tick
   procedure Update_Watchdog
     (Chan    : in out Euroradio_Channel;
      Delta_S : Positive);

end Aspect.ETCS.Euroradio;
