package body Aspect.CRC is

   ----------------------------------------------------------------------------
   -- ETCS Subset-036 10-bit Balise CRC
   ----------------------------------------------------------------------------

   function Calculate_CRC10
     (Data : Byte_Array;
      Bits : Positive) return CRC10_Type
   is
      -- Polynomial: x^10 + x^9 + x^5 + x^4 + x + 1 (binary 11000110011 = 0x633)
      Poly     : constant Unsigned_16 := 16#0233#; -- without leading bit x^10
      Register : Unsigned_16 := 0;
      Bit_Idx  : Natural := 0;
      Byte_Idx : Natural;
      Bit_Val  : Unsigned_16;
      MSB      : Unsigned_16;
   begin
      while Bit_Idx < Bits loop
         Byte_Idx := Data'First + (Bit_Idx / 8);
         if Byte_Idx > Data'Last then
            exit;
         end if;
         
         -- Extract bit MSB-first within the byte
         Bit_Val := Unsigned_16 (Shift_Right (Data (Byte_Idx), 7 - (Bit_Idx mod 8)) and 1);
         
         MSB := Shift_Right (Register, 9) and 1;
         Register := Shift_Left (Register and 16#01FF#, 1) or Bit_Val;
         
         if MSB /= 0 then
            Register := Register xor Poly;
         end if;
         
         Bit_Idx := Bit_Idx + 1;
      end loop;
      
      return CRC10_Type (Register and 16#03FF#);
   end Calculate_CRC10;

   ----------------------------------------------------------------------------
   -- CRC-16-CCITT Implementation
   ----------------------------------------------------------------------------

   function Calculate_CRC16_CCITT
     (Data : Byte_Array;
      Init : Unsigned_16 := 16#FFFF#) return Unsigned_16
   is
      Crc : Unsigned_16 := Init;
      B   : Unsigned_16;
   begin
      for I in Data'Range loop
         B := Unsigned_16 (Data (I));
         Crc := Crc xor Shift_Left (B, 8);
         for Bit in 1 .. 8 loop
            if (Crc and 16#8000#) /= 0 then
               Crc := Shift_Left (Crc, 1) xor 16#1021#;
            else
               Crc := Shift_Left (Crc, 1);
            end if;
         end loop;
      end loop;
      return Crc;
   end Calculate_CRC16_CCITT;

   ----------------------------------------------------------------------------
   -- CRC-32-IEEE Implementation
   ----------------------------------------------------------------------------

   function Calculate_CRC32_IEEE
     (Data : Byte_Array;
      Init : Unsigned_32 := 16#FFFF_FFFF#) return Unsigned_32
   is
      Crc : Unsigned_32 := Init;
      B   : Unsigned_32;
   begin
      for I in Data'Range loop
         B := Unsigned_32 (Data (I));
         Crc := Crc xor B;
         for Bit in 1 .. 8 loop
            if (Crc and 1) /= 0 then
               Crc := Shift_Right (Crc, 1) xor 16#EDB8_8320#;
            else
               Crc := Shift_Right (Crc, 1);
            end if;
         end loop;
      end loop;
      return Crc xor 16#FFFF_FFFF#;
   end Calculate_CRC32_IEEE;

   ----------------------------------------------------------------------------
   -- Castagnoli CRC-32C Implementation
   ----------------------------------------------------------------------------

   function Calculate_CRC32C
     (Data : Byte_Array;
      Init : Unsigned_32 := 16#FFFF_FFFF#) return Unsigned_32
   is
      Crc : Unsigned_32 := Init;
      B   : Unsigned_32;
   begin
      for I in Data'Range loop
         B := Unsigned_32 (Data (I));
         Crc := Crc xor B;
         for Bit in 1 .. 8 loop
            if (Crc and 1) /= 0 then
               Crc := Shift_Right (Crc, 1) xor 16#82F6_3B78#;
            else
               Crc := Shift_Right (Crc, 1);
            end if;
         end loop;
      end loop;
      return Crc xor 16#FFFF_FFFF#;
   end Calculate_CRC32C;

   ----------------------------------------------------------------------------
   -- Verification Helpers
   ----------------------------------------------------------------------------

   function Verify_CRC16
     (Data              : Byte_Array;
      Expected_Checksum : Unsigned_16) return Boolean
   is
   begin
      return Calculate_CRC16_CCITT (Data) = Expected_Checksum;
   end Verify_CRC16;

   function Verify_CRC32
     (Data              : Byte_Array;
      Expected_Checksum : Unsigned_32) return Boolean
   is
   begin
      return Calculate_CRC32_IEEE (Data) = Expected_Checksum;
   end Verify_CRC32;

end Aspect.CRC;
