-- Cyclic Redundancy Check (CRC) algorithms for vital railway telemetry.
-- Implements ETCS Subset-036 CRC-10, Lineside Vital Bus CRC-16-CCITT,
-- and EURORADIO CRC-32 (IEEE and Castagnoli CRC-32C).

with Interfaces; use Interfaces;

package Aspect.CRC with
   Pure
is

   type Byte_Array is array (Natural range <>) of Unsigned_8;

   -- ETCS Subset-036 Balise Telegram 10-bit CRC
   -- Generator polynomial: x^10 + x^9 + x^5 + x^4 + x + 1 (0x633)
   subtype CRC10_Type is Unsigned_16 range 0 .. 1023;

   function Calculate_CRC10
     (Data : Byte_Array;
      Bits : Positive) return CRC10_Type;

   -- CRC-16-CCITT for lineside object controller communication
   -- Generator polynomial: x^16 + x^12 + x^5 + 1 (0x1021)
   function Calculate_CRC16_CCITT
     (Data : Byte_Array;
      Init : Unsigned_16 := 16#FFFF#) return Unsigned_16;

   -- IEEE 802.3 standard 32-bit CRC
   -- Generator polynomial: 0xEDB88320
   function Calculate_CRC32_IEEE
     (Data : Byte_Array;
      Init : Unsigned_32 := 16#FFFF_FFFF#) return Unsigned_32;

   -- Castagnoli CRC-32C used in EURORADIO vital safety frames
   -- Generator polynomial: 0x82F63B78
   function Calculate_CRC32C
     (Data : Byte_Array;
      Init : Unsigned_32 := 16#FFFF_FFFF#) return Unsigned_32;

   -- Verifies whether data appended with CRC matches expected checksum
   function Verify_CRC16
     (Data             : Byte_Array;
      Expected_Checksum: Unsigned_16) return Boolean;

   function Verify_CRC32
     (Data             : Byte_Array;
      Expected_Checksum: Unsigned_32) return Boolean;

end Aspect.CRC;
