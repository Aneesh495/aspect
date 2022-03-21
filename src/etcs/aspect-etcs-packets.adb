package body Aspect.ETCS.Packets is

   ----------------------------------------------------------------------------
   -- Packet 12 Encoding / Decoding
   ----------------------------------------------------------------------------

   procedure Encode_Packet_12
     (P       : Packet_12_Movement_Authority;
      Buffer  : out Byte_Array;
      Written : out Natural)
   is
      V_Main_Int : constant Unsigned_16 := Unsigned_16 (Float (P.V_MAIN));
      EoA_Int    : constant Unsigned_32 := Unsigned_32 (Float (P.Distance_To_EoA));
      SvL_Int    : constant Unsigned_32 := Unsigned_32 (Float (P.Distance_To_SvL));
      V_Rel_Int  : constant Unsigned_16 := Unsigned_16 (Float (P.Release_Speed));
      T_Out_Int  : constant Unsigned_16 := Unsigned_16 (P.Timeout_Seconds);
   begin
      if Buffer'Length < 15 then
         Written := 0;
         return;
      end if;

      declare
         Base : constant Natural := Buffer'First;
      begin
         Buffer (Base)     := Unsigned_8 (Packet_Movement_Authority); -- NID_PACKET = 12
         Buffer (Base + 1) := Unsigned_8 (Shift_Right (V_Main_Int, 8) and 16#FF#);
         Buffer (Base + 2) := Unsigned_8 (V_Main_Int and 16#FF#);

         Buffer (Base + 3) := Unsigned_8 (Shift_Right (EoA_Int, 24) and 16#FF#);
         Buffer (Base + 4) := Unsigned_8 (Shift_Right (EoA_Int, 16) and 16#FF#);
         Buffer (Base + 5) := Unsigned_8 (Shift_Right (EoA_Int, 8) and 16#FF#);
         Buffer (Base + 6) := Unsigned_8 (EoA_Int and 16#FF#);

         Buffer (Base + 7) := Unsigned_8 (Shift_Right (SvL_Int, 24) and 16#FF#);
         Buffer (Base + 8) := Unsigned_8 (Shift_Right (SvL_Int, 16) and 16#FF#);
         Buffer (Base + 9) := Unsigned_8 (Shift_Right (SvL_Int, 8) and 16#FF#);
         Buffer (Base + 10):= Unsigned_8 (SvL_Int and 16#FF#);

         Buffer (Base + 11):= Unsigned_8 (Shift_Right (V_Rel_Int, 8) and 16#FF#);
         Buffer (Base + 12):= Unsigned_8 (V_Rel_Int and 16#FF#);

         Buffer (Base + 13):= Unsigned_8 (Shift_Right (T_Out_Int, 8) and 16#FF#);
         Buffer (Base + 14):= Unsigned_8 (T_Out_Int and 16#FF#);

         Written := 15;
      end;
   end Encode_Packet_12;

   procedure Decode_Packet_12
     (Buffer  : Byte_Array;
      P       : out Packet_12_Movement_Authority;
      Success : out Boolean)
   is
   begin
      if Buffer'Length < 15 then
         Success := False;
         return;
      end if;

      declare
         Base      : constant Natural := Buffer'First;
         NID       : constant Unsigned_8 := Buffer (Base);
         V_Main_Raw: Unsigned_16;
         EoA_Raw   : Unsigned_32;
         SvL_Raw   : Unsigned_32;
         V_Rel_Raw : Unsigned_16;
         T_Out_Raw : Unsigned_16;
      begin
         if NID /= Unsigned_8 (Packet_Movement_Authority) then
            Success := False;
            return;
         end if;

         V_Main_Raw := Shift_Left (Unsigned_16 (Buffer (Base + 1)), 8) or Unsigned_16 (Buffer (Base + 2));

         EoA_Raw := Shift_Left (Unsigned_32 (Buffer (Base + 3)), 24)
                 or Shift_Left (Unsigned_32 (Buffer (Base + 4)), 16)
                 or Shift_Left (Unsigned_32 (Buffer (Base + 5)), 8)
                 or Unsigned_32 (Buffer (Base + 6));

         SvL_Raw := Shift_Left (Unsigned_32 (Buffer (Base + 7)), 24)
                 or Shift_Left (Unsigned_32 (Buffer (Base + 8)), 16)
                 or Shift_Left (Unsigned_32 (Buffer (Base + 9)), 8)
                 or Unsigned_32 (Buffer (Base + 10));

         V_Rel_Raw := Shift_Left (Unsigned_16 (Buffer (Base + 11)), 8) or Unsigned_16 (Buffer (Base + 12));
         T_Out_Raw := Shift_Left (Unsigned_16 (Buffer (Base + 13)), 8) or Unsigned_16 (Buffer (Base + 14));

         P.V_MAIN          := Speed_Kph (Float (V_Main_Raw));
         P.Distance_To_EoA := Distance_M (Float (EoA_Raw));
         P.Distance_To_SvL := Distance_M (Float (SvL_Raw));
         P.Release_Speed   := Speed_Kph (Float (V_Rel_Raw));
         P.Timeout_Seconds := Positive (T_Out_Raw);

         Success := True;
      end;
   end Decode_Packet_12;

   ----------------------------------------------------------------------------
   -- Packet 21 Encoding / Decoding
   ----------------------------------------------------------------------------

   procedure Encode_Packet_21
     (P       : Packet_21_Gradient_Profile;
      Buffer  : out Byte_Array;
      Written : out Natural)
   is
      Pos : Natural := Buffer'First;
   begin
      if Buffer'Length < 2 + (P.Step_Count * 6) then
         Written := 0;
         return;
      end if;

      Buffer (Pos)     := Unsigned_8 (Packet_Gradient_Profile);
      Buffer (Pos + 1) := Unsigned_8 (P.Step_Count);
      Pos := Pos + 2;

      for I in 1 .. P.Step_Count loop
         declare
            D_Int : constant Unsigned_32 := Unsigned_32 (Float (P.Steps (I).Start_Distance));
            G_Int : constant Integer_16  := Integer_16 (Float (P.Steps (I).Gradient));
         begin
            Buffer (Pos)     := Unsigned_8 (Shift_Right (D_Int, 24) and 16#FF#);
            Buffer (Pos + 1) := Unsigned_8 (Shift_Right (D_Int, 16) and 16#FF#);
            Buffer (Pos + 2) := Unsigned_8 (Shift_Right (D_Int, 8) and 16#FF#);
            Buffer (Pos + 3) := Unsigned_8 (D_Int and 16#FF#);

            Buffer (Pos + 4) := Unsigned_8 (Shift_Right (Unsigned_16 (G_Int), 8) and 16#FF#);
            Buffer (Pos + 5) := Unsigned_8 (Unsigned_16 (G_Int) and 16#FF#);
            Pos := Pos + 6;
         end;
      end loop;

      Written := Pos - Buffer'First;
   end Encode_Packet_21;

   procedure Decode_Packet_21
     (Buffer  : Byte_Array;
      P       : out Packet_21_Gradient_Profile;
      Success : out Boolean)
   is
   begin
      if Buffer'Length < 2 then
         Success := False;
         return;
      end if;

      declare
         Pos   : Natural := Buffer'First;
         NID   : constant Unsigned_8 := Buffer (Pos);
         Count : constant Natural    := Natural (Buffer (Pos + 1));
      begin
         if NID /= Unsigned_8 (Packet_Gradient_Profile) then
            Success := False;
            return;
         end if;

         if Buffer'Length < 2 + (Count * 6) then
            Success := False;
            return;
         end if;

         P.Step_Count := Count;
         Pos := Pos + 2;

         for I in 1 .. Count loop
            declare
               D_Raw : constant Unsigned_32 :=
                 Shift_Left (Unsigned_32 (Buffer (Pos)), 24)
                 or Shift_Left (Unsigned_32 (Buffer (Pos + 1)), 16)
                 or Shift_Left (Unsigned_32 (Buffer (Pos + 2)), 8)
                 or Unsigned_32 (Buffer (Pos + 3));

               G_Raw : constant Integer_16 :=
                 Integer_16 (Shift_Left (Unsigned_16 (Buffer (Pos + 4)), 8)
                             or Unsigned_16 (Buffer (Pos + 5)));
            begin
               P.Steps (I).Start_Distance := Distance_M (Float (D_Raw));
               P.Steps (I).Gradient       := Gradient_Per_Mille (Float (G_Raw));
               Pos := Pos + 6;
            end;
         end loop;

         Success := True;
      end;
   end Decode_Packet_21;

   ----------------------------------------------------------------------------
   -- Packet 27 Encoding / Decoding
   ----------------------------------------------------------------------------

   procedure Encode_Packet_27
     (P       : Packet_27_Static_Speed_Profile;
      Buffer  : out Byte_Array;
      Written : out Natural)
   is
      Pos : Natural := Buffer'First;
   begin
      if Buffer'Length < 2 + (P.Step_Count * 6) then
         Written := 0;
         return;
      end if;

      Buffer (Pos)     := Unsigned_8 (Packet_Static_Speed_Profile);
      Buffer (Pos + 1) := Unsigned_8 (P.Step_Count);
      Pos := Pos + 2;

      for I in 1 .. P.Step_Count loop
         declare
            D_Int : constant Unsigned_32 := Unsigned_32 (Float (P.Steps (I).Start_Distance));
            V_Int : constant Unsigned_16 := Unsigned_16 (Float (P.Steps (I).Speed_Limit));
         begin
            Buffer (Pos)     := Unsigned_8 (Shift_Right (D_Int, 24) and 16#FF#);
            Buffer (Pos + 1) := Unsigned_8 (Shift_Right (D_Int, 16) and 16#FF#);
            Buffer (Pos + 2) := Unsigned_8 (Shift_Right (D_Int, 8) and 16#FF#);
            Buffer (Pos + 3) := Unsigned_8 (D_Int and 16#FF#);

            Buffer (Pos + 4) := Unsigned_8 (Shift_Right (V_Int, 8) and 16#FF#);
            Buffer (Pos + 5) := Unsigned_8 (V_Int and 16#FF#);
            Pos := Pos + 6;
         end;
      end loop;

      Written := Pos - Buffer'First;
   end Encode_Packet_27;

   procedure Decode_Packet_27
     (Buffer  : Byte_Array;
      P       : out Packet_27_Static_Speed_Profile;
      Success : out Boolean)
   is
   begin
      if Buffer'Length < 2 then
         Success := False;
         return;
      end if;

      declare
         Pos   : Natural := Buffer'First;
         NID   : constant Unsigned_8 := Buffer (Pos);
         Count : constant Natural    := Natural (Buffer (Pos + 1));
      begin
         if NID /= Unsigned_8 (Packet_Static_Speed_Profile) then
            Success := False;
            return;
         end if;

         if Buffer'Length < 2 + (Count * 6) then
            Success := False;
            return;
         end if;

         P.Step_Count := Count;
         Pos := Pos + 2;

         for I in 1 .. Count loop
            declare
               D_Raw : constant Unsigned_32 :=
                 Shift_Left (Unsigned_32 (Buffer (Pos)), 24)
                 or Shift_Left (Unsigned_32 (Buffer (Pos + 1)), 16)
                 or Shift_Left (Unsigned_32 (Buffer (Pos + 2)), 8)
                 or Unsigned_32 (Buffer (Pos + 3));

               V_Raw : constant Unsigned_16 :=
                 Shift_Left (Unsigned_16 (Buffer (Pos + 4)), 8)
                 or Unsigned_16 (Buffer (Pos + 5));
            begin
               P.Steps (I).Start_Distance := Distance_M (Float (D_Raw));
               P.Steps (I).Speed_Limit    := Speed_Kph (Float (V_Raw));
               Pos := Pos + 6;
            end;
         end loop;

         Success := True;
      end;
   end Decode_Packet_27;

end Aspect.ETCS.Packets;
