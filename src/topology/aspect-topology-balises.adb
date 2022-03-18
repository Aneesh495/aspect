package body Aspect.Topology.Balises is

   procedure Initialize_Balise
     (Balise       : out Eurobalise;
      Id           : Balise_Id;
      Group_Id     : Natural;
      Pos_In_Group : Positive;
      Total_In_Grp : Positive;
      Kind         : Balise_Kind;
      Section      : Section_Id;
      Chainage     : Track_Chainage;
      Direction    : Direction_Type := Dir_Nominal)
   is
   begin
      Balise.Id                  := Id;
      Balise.Group_Id            := Group_Id;
      Balise.Position_In_Group   := Pos_In_Group;
      Balise.Total_In_Group      := Total_In_Grp;
      Balise.Kind                := Kind;
      Balise.Track_Section       := Section;
      Balise.Chainage            := Chainage;
      Balise.Direction_Valid     := Direction;
      Balise.Telegram_Payload    := [others => 0];
      Balise.Telegram_Bit_Length := 832;
      Balise.Telegram_CRC        := 0;
      Balise.Is_Transmitting     := True;
   end Initialize_Balise;

   procedure Load_Telegram
     (Balise     : in out Eurobalise;
      Payload    : Balise_Telegram_Data;
      Bit_Length : Positive := 832)
   is
      Raw_Bytes : Byte_Array (1 .. Standard_Telegram_Bytes);
   begin
      Balise.Telegram_Payload    := Payload;
      Balise.Telegram_Bit_Length := Bit_Length;

      for I in 1 .. Standard_Telegram_Bytes loop
         Raw_Bytes (I) := Payload (I);
      end loop;

      Balise.Telegram_CRC := Calculate_CRC10 (Raw_Bytes, Bit_Length);
   end Load_Telegram;

   procedure Update_LEU_Telegram
     (Balise      : in out Eurobalise;
      New_Payload : Balise_Telegram_Data;
      Bit_Length  : Positive := 832)
   is
   begin
      if Balise.Kind = Balise_Controllable then
         Load_Telegram (Balise, New_Payload, Bit_Length);
      end if;
   end Update_LEU_Telegram;

   procedure Interrogate_Balise
     (Balise  : Eurobalise;
      Payload : out Balise_Telegram_Data;
      CRC_OK  : out Boolean)
   is
      Raw_Bytes : Byte_Array (1 .. Standard_Telegram_Bytes);
      Check_CRC : CRC10_Type;
   begin
      Payload := Balise.Telegram_Payload;

      if not Balise.Is_Transmitting then
         CRC_OK := False;
         return;
      end if;

      for I in 1 .. Standard_Telegram_Bytes loop
         Raw_Bytes (I) := Payload (I);
      end loop;

      Check_CRC := Calculate_CRC10 (Raw_Bytes, Balise.Telegram_Bit_Length);
      CRC_OK    := (Check_CRC = Balise.Telegram_CRC);
   end Interrogate_Balise;

end Aspect.Topology.Balises;
