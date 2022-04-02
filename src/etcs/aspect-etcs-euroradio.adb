package body Aspect.ETCS.Euroradio is

   procedure Initialize_Channel
     (Chan       : out Euroradio_Channel;
      Session_Id : Unsigned_16;
      Timeout_S  : Positive := 30)
   is
   begin
      Chan.Session_Id        := Session_Id;
      Chan.Expected_Next_Seq := 1;
      Chan.Last_Rx_Timestamp := 0;
      Chan.Watchdog_Timer_S  := Timeout_S;
      Chan.Status            := Link_Up;
   end Initialize_Channel;

   procedure Construct_Frame
     (Chan      : in out Euroradio_Channel;
      Payload   : Byte_Array;
      Length    : Positive;
      Timestamp : Unsigned_32;
      Frame     : out Euroradio_Frame)
   is
      Len : constant Natural := Natural'Min (Length, Max_Radio_Frame_Bytes);
   begin
      Frame.Header.Protocol_Version := 1;
      Frame.Header.Session_Id       := Chan.Session_Id;
      Frame.Header.Sequence_Number  := Chan.Expected_Next_Seq;
      Frame.Header.Timestamp_Ms     := Timestamp;
      Frame.Header.Payload_Length   := Unsigned_16 (Len);

      Chan.Expected_Next_Seq := Chan.Expected_Next_Seq + 1;

      Frame.Payload := [others => 0];
      for I in 1 .. Len loop
         Frame.Payload (I) := Payload (Payload'First + I - 1);
      end loop;

      -- Compute CRC-32C over header and active payload bytes
      declare
         Header_Bytes : Byte_Array (1 .. 13);
         Total_Bytes  : Byte_Array (1 .. 13 + Len);
      begin
         Header_Bytes (1) := Frame.Header.Protocol_Version;
         Header_Bytes (2) := Unsigned_8 (Shift_Right (Frame.Header.Session_Id, 8) and 16#FF#);
         Header_Bytes (3) := Unsigned_8 (Frame.Header.Session_Id and 16#FF#);

         Header_Bytes (4) := Unsigned_8 (Shift_Right (Frame.Header.Sequence_Number, 24) and 16#FF#);
         Header_Bytes (5) := Unsigned_8 (Shift_Right (Frame.Header.Sequence_Number, 16) and 16#FF#);
         Header_Bytes (6) := Unsigned_8 (Shift_Right (Frame.Header.Sequence_Number, 8) and 16#FF#);
         Header_Bytes (7) := Unsigned_8 (Frame.Header.Sequence_Number and 16#FF#);

         Header_Bytes (8) := Unsigned_8 (Shift_Right (Frame.Header.Timestamp_Ms, 24) and 16#FF#);
         Header_Bytes (9) := Unsigned_8 (Shift_Right (Frame.Header.Timestamp_Ms, 16) and 16#FF#);
         Header_Bytes (10):= Unsigned_8 (Shift_Right (Frame.Header.Timestamp_Ms, 8) and 16#FF#);
         Header_Bytes (11):= Unsigned_8 (Frame.Header.Timestamp_Ms and 16#FF#);

         Header_Bytes (12):= Unsigned_8 (Shift_Right (Frame.Header.Payload_Length, 8) and 16#FF#);
         Header_Bytes (13):= Unsigned_8 (Frame.Header.Payload_Length and 16#FF#);

         for I in 1 .. 13 loop
            Total_Bytes (I) := Header_Bytes (I);
         end loop;

         for I in 1 .. Len loop
            Total_Bytes (13 + I) := Frame.Payload (I);
         end loop;

         Frame.Checksum := Calculate_CRC32C (Total_Bytes);
      end;
   end Construct_Frame;

   procedure Ingest_Frame
     (Chan    : in out Euroradio_Channel;
      Frame   : Euroradio_Frame;
      Payload : out Byte_Array;
      Length  : out Natural;
      Valid   : out Boolean)
   is
      Len : constant Natural := Natural (Frame.Header.Payload_Length);
   begin
      Length := 0;
      Valid  := False;

      if Len > Max_Radio_Frame_Bytes or else Payload'Length < Len then
         return;
      end if;

      -- Check session identifier
      if Frame.Header.Session_Id /= Chan.Session_Id then
         return;
      end if;

      -- Replay attack / out-of-order defense: sequence number must be monotonically increasing
      if Frame.Header.Sequence_Number < Chan.Expected_Next_Seq then
         return;
      end if;

      -- Verify CRC-32C checksum
      declare
         Header_Bytes : Byte_Array (1 .. 13);
         Total_Bytes  : Byte_Array (1 .. 13 + Len);
         Calc_CRC     : Unsigned_32;
      begin
         Header_Bytes (1) := Frame.Header.Protocol_Version;
         Header_Bytes (2) := Unsigned_8 (Shift_Right (Frame.Header.Session_Id, 8) and 16#FF#);
         Header_Bytes (3) := Unsigned_8 (Frame.Header.Session_Id and 16#FF#);

         Header_Bytes (4) := Unsigned_8 (Shift_Right (Frame.Header.Sequence_Number, 24) and 16#FF#);
         Header_Bytes (5) := Unsigned_8 (Shift_Right (Frame.Header.Sequence_Number, 16) and 16#FF#);
         Header_Bytes (6) := Unsigned_8 (Shift_Right (Frame.Header.Sequence_Number, 8) and 16#FF#);
         Header_Bytes (7) := Unsigned_8 (Frame.Header.Sequence_Number and 16#FF#);

         Header_Bytes (8) := Unsigned_8 (Shift_Right (Frame.Header.Timestamp_Ms, 24) and 16#FF#);
         Header_Bytes (9) := Unsigned_8 (Shift_Right (Frame.Header.Timestamp_Ms, 16) and 16#FF#);
         Header_Bytes (10):= Unsigned_8 (Shift_Right (Frame.Header.Timestamp_Ms, 8) and 16#FF#);
         Header_Bytes (11):= Unsigned_8 (Frame.Header.Timestamp_Ms and 16#FF#);

         Header_Bytes (12):= Unsigned_8 (Shift_Right (Frame.Header.Payload_Length, 8) and 16#FF#);
         Header_Bytes (13):= Unsigned_8 (Frame.Header.Payload_Length and 16#FF#);

         for I in 1 .. 13 loop
            Total_Bytes (I) := Header_Bytes (I);
         end loop;

         for I in 1 .. Len loop
            Total_Bytes (13 + I) := Frame.Payload (I);
         end loop;

         Calc_CRC := Calculate_CRC32C (Total_Bytes);
         if Calc_CRC /= Frame.Checksum then
            return;
         end if;
      end;

      -- Frame is authenticated and valid
      Chan.Expected_Next_Seq := Frame.Header.Sequence_Number + 1;
      Chan.Last_Rx_Timestamp := Frame.Header.Timestamp_Ms;
      Chan.Watchdog_Timer_S  := 30; -- Reset watchdog
      Chan.Status            := Link_Up;

      for I in 1 .. Len loop
         Payload (Payload'First + I - 1) := Frame.Payload (I);
      end loop;

      Length := Len;
      Valid  := True;
   end Ingest_Frame;

   procedure Update_Watchdog
     (Chan    : in out Euroradio_Channel;
      Delta_S : Positive)
   is
   begin
      if Chan.Watchdog_Timer_S <= Delta_S then
         Chan.Watchdog_Timer_S := 0;
         Chan.Status           := Link_Timeout_Tripped;
      else
         Chan.Watchdog_Timer_S := Chan.Watchdog_Timer_S - Delta_S;
      end if;
   end Update_Watchdog;

end Aspect.ETCS.Euroradio;
