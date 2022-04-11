-- Implementation of JSON serialization and command ingestion protocol.

with Aspect.Types; use Aspect.Types;

package body Aspect.Telemetry.Protocol is

   ----------------------------------------------------------------------------
   -- Buffer Helper Routines
   ----------------------------------------------------------------------------

   procedure Append
     (Buffer : in out JSON_String_Buffer;
      Len    : in out Natural;
      Str    : String)
   is
      Rem_Cap : constant Integer := Buffer'Last - Len;
      Copy_Len: constant Natural := Natural'Min (Str'Length, Natural'Max (0, Rem_Cap));
   begin
      if Copy_Len > 0 then
         Buffer (Len + 1 .. Len + Copy_Len) := Str (Str'First .. Str'First + Copy_Len - 1);
         Len := Len + Copy_Len;
      end if;
   end Append;

   procedure Append_Int
     (Buffer : in out JSON_String_Buffer;
      Len    : in out Natural;
      Val    : Long_Long_Integer)
   is
      Img : constant String := Long_Long_Integer'Image (Val);
   begin
      if Img'Length > 0 and then Img (Img'First) = ' ' then
         Append (Buffer, Len, Img (Img'First + 1 .. Img'Last));
      else
         Append (Buffer, Len, Img);
      end if;
   end Append_Int;

   procedure Append_Float
     (Buffer   : in out JSON_String_Buffer;
      Len      : in out Natural;
      Val      : Float;
      Decimals : Natural := 2)
   is
      V_Abs : constant Float := abs Val;
      Int_Part  : constant Long_Long_Integer := Long_Long_Integer (Float'Floor (V_Abs));
      Frac_Part : constant Float := V_Abs - Float (Int_Part);
      Mult      : Float := 1.0;
   begin
      if Val < 0.0 then
         Append (Buffer, Len, "-");
      end if;

      Append_Int (Buffer, Len, Int_Part);
      Append (Buffer, Len, ".");

      for D in 1 .. Decimals loop
         Mult := Mult * 10.0;
      end loop;

      declare
         Frac_Int : constant Long_Long_Integer := Long_Long_Integer (Float'Floor (Frac_Part * Mult));
         Frac_Str : constant String := Long_Long_Integer'Image (Frac_Int);
         Start    : constant Positive := (if Frac_Str (Frac_Str'First) = ' ' then Frac_Str'First + 1 else Frac_Str'First);
         Dig_Len  : constant Natural := Frac_Str'Last - Start + 1;
      begin
         -- Pad leading fractional zeros if necessary (e.g. 0.04 -> "04")
         if Dig_Len < Decimals then
            for Pad in 1 .. (Decimals - Dig_Len) loop
               Append (Buffer, Len, "0");
            end loop;
         end if;
         Append (Buffer, Len, Frac_Str (Start .. Frac_Str'Last));
      end;
   end Append_Float;

   procedure Append_Bool
     (Buffer : in out JSON_String_Buffer;
      Len    : in out Natural;
      Val    : Boolean)
   is
   begin
      if Val then
         Append (Buffer, Len, "true");
      else
         Append (Buffer, Len, "false");
      end if;
   end Append_Bool;

   function Aspect_To_String (A : Signal_Aspect) return String is
   begin
      case A is
         when Aspect_Stop =>
            return "STOP";
         when Aspect_Caution =>
            return "CAUTION";
         when Aspect_Preliminary_Caution =>
            return "PRELIMINARY_CAUTION";
         when Aspect_Clear =>
            return "CLEAR";
         when Aspect_Shunt =>
            return "SHUNT";
         when Aspect_Dark =>
            return "DARK";
      end case;
   end Aspect_To_String;

   function Switch_Pos_To_String (P : Switch_Position) return String is
   begin
      case P is
         when Switch_Normal =>
            return "NORMAL";
         when Switch_Reverse =>
            return "REVERSE";
         when Switch_In_Transit =>
            return "IN_TRANSIT";
         when Switch_Lost_Detection =>
            return "LOST_DETECTION";
      end case;
   end Switch_Pos_To_String;

   function Route_State_To_String (S : Route_State) return String is
   begin
      case S is
         when Route_Unset =>
            return "UNSET";
         when Route_Requested =>
            return "REQUESTED";
         when Route_Interlocked =>
            return "INTERLOCKED";
         when Route_Cleared =>
            return "CLEARED";
         when Route_Approached =>
            return "APPROACHED";
         when Route_Occupied =>
            return "OCCUPIED";
         when Route_Sectional_Release =>
            return "SECTIONAL_RELEASE";
         when Route_Released =>
            return "RELEASED";
         when Route_Cancelled =>
            return "CANCELLED";
      end case;
   end Route_State_To_String;

   ----------------------------------------------------------------------------
   -- Snapshot_To_JSON
   ----------------------------------------------------------------------------
   procedure Snapshot_To_JSON
     (Snapshot : Telemetry_Snapshot;
      Buffer   : out JSON_String_Buffer;
      Length   : out Natural)
   is
      Len : Natural := 0;
   begin
      Buffer := [others => ' '];

      Append (Buffer, Len, "{""type"":""telemetry_snapshot""");
      Append (Buffer, Len, ",""timestamp_ms"":");
      Append_Int (Buffer, Len, Long_Long_Integer (Snapshot.Timestamp_Ms));
      Append (Buffer, Len, ",""step_number"":");
      Append_Int (Buffer, Len, Long_Long_Integer (Snapshot.Step_Number));

      -- Sections Array
      Append (Buffer, Len, ",""sections"":[");
      for I in 1 .. Snapshot.Section_Count loop
         if I > 1 then
            Append (Buffer, Len, ",");
         end if;
         declare
            Sec : constant Track_Telemetry := Snapshot.Sections (I);
         begin
            Append (Buffer, Len, "{""id"":");
            Append_Int (Buffer, Len, Long_Long_Integer (Sec.Id));
            Append (Buffer, Len, ",""occupied"":");
            Append_Bool (Buffer, Len, Sec.Is_Occupied);
            Append (Buffer, Len, ",""locked"":");
            Append_Bool (Buffer, Len, Sec.Is_Locked);
            Append (Buffer, Len, ",""ballast_ohms"":");
            Append_Float (Buffer, Len, Sec.Ballast_Ohms, 1);
            Append (Buffer, Len, ",""axle_count"":");
            Append_Int (Buffer, Len, Long_Long_Integer (Sec.Axle_Count));
            Append (Buffer, Len, "}");
         end;
      end loop;
      Append (Buffer, Len, "]");

      -- Switches Array
      Append (Buffer, Len, ",""switches"":[");
      for I in 1 .. Snapshot.Switch_Count loop
         if I > 1 then
            Append (Buffer, Len, ",");
         end if;
         declare
            Sw : constant Switch_Telemetry := Snapshot.Switches (I);
         begin
            Append (Buffer, Len, "{""id"":");
            Append_Int (Buffer, Len, Long_Long_Integer (Sw.Id));
            Append (Buffer, Len, ",""position"":""");
            Append (Buffer, Len, Switch_Pos_To_String (Sw.Position));
            Append (Buffer, Len, """,""blade_gap_mm"":");
            Append_Int (Buffer, Len, Long_Long_Integer (Sw.Blade_Gap_Mm));
            Append (Buffer, Len, ",""locked"":");
            Append_Bool (Buffer, Len, Sw.Is_Locked);
            Append (Buffer, Len, ",""motor_stalled"":");
            Append_Bool (Buffer, Len, Sw.Motor_Stalled);
            Append (Buffer, Len, ",""trail_through"":");
            Append_Bool (Buffer, Len, Sw.Trail_Through);
            Append (Buffer, Len, "}");
         end;
      end loop;
      Append (Buffer, Len, "]");

      -- Signals Array
      Append (Buffer, Len, ",""signals"":[");
      for I in 1 .. Snapshot.Signal_Count loop
         if I > 1 then
            Append (Buffer, Len, ",");
         end if;
         declare
            Sig : constant Signal_Telemetry := Snapshot.Signals (I);
         begin
            Append (Buffer, Len, "{""id"":");
            Append_Int (Buffer, Len, Long_Long_Integer (Sig.Id));
            Append (Buffer, Len, ",""aspect"":""");
            Append (Buffer, Len, Aspect_To_String (Sig.Aspect));
            Append (Buffer, Len, """,""current_ma"":");
            Append_Float (Buffer, Len, Sig.Current_Ma, 1);
            Append (Buffer, Len, ",""lamp_fault"":");
            Append_Bool (Buffer, Len, Sig.Lamp_Fault);
            Append (Buffer, Len, "}");
         end;
      end loop;
      Append (Buffer, Len, "]");

      -- Routes Array
      Append (Buffer, Len, ",""routes"":[");
      for I in 1 .. Snapshot.Route_Count loop
         if I > 1 then
            Append (Buffer, Len, ",");
         end if;
         declare
            R : constant Route_Telemetry := Snapshot.Routes (I);
         begin
            Append (Buffer, Len, "{""id"":");
            Append_Int (Buffer, Len, Long_Long_Integer (R.Id));
            Append (Buffer, Len, ",""state"":""");
            Append (Buffer, Len, Route_State_To_String (R.State));
            Append (Buffer, Len, """,""entry_sig"":");
            Append_Int (Buffer, Len, Long_Long_Integer (R.Entry_Sig));
            Append (Buffer, Len, """,""exit_sig"":");
            Append_Int (Buffer, Len, Long_Long_Integer (R.Exit_Sig));
            Append (Buffer, Len, "}");
         end;
      end loop;
      Append (Buffer, Len, "]");

      -- Trains Array
      Append (Buffer, Len, ",""trains"":[");
      for I in 1 .. Snapshot.Train_Count loop
         if I > 1 then
            Append (Buffer, Len, ",");
         end if;
         declare
            T : constant Train_Telemetry := Snapshot.Trains (I);
         begin
            Append (Buffer, Len, "{""id"":");
            Append_Int (Buffer, Len, Long_Long_Integer (T.Id));
            Append (Buffer, Len, ",""chainage_km"":");
            Append_Float (Buffer, Len, Float (T.Chainage_Km), 3);
            Append (Buffer, Len, ",""speed_kph"":");
            Append_Float (Buffer, Len, Float (T.Current_Speed), 1);
            Append (Buffer, Len, ",""permitted_kph"":");
            Append_Float (Buffer, Len, Float (T.Permitted_Speed), 1);
            Append (Buffer, Len, ",""warning_kph"":");
            Append_Float (Buffer, Len, Float (T.Warning_Speed), 1);
            Append (Buffer, Len, ",""sbi_kph"":");
            Append_Float (Buffer, Len, Float (T.SBI_Speed), 1);
            Append (Buffer, Len, ",""ebi_kph"":");
            Append_Float (Buffer, Len, Float (T.EBI_Speed), 1);
            Append (Buffer, Len, ",""throttle_pct"":");
            Append_Float (Buffer, Len, Float (T.Throttle_Pct), 1);
            Append (Buffer, Len, ",""brake_pct"":");
            Append_Float (Buffer, Len, Float (T.Brake_Pct), 1);
            Append (Buffer, Len, ",""emergency_brake"":");
            Append_Bool (Buffer, Len, T.Emergency_Brake);
            Append (Buffer, Len, ",""wheel_slip"":");
            Append_Bool (Buffer, Len, T.Wheel_Slip);
            Append (Buffer, Len, ",""section"":");
            Append_Int (Buffer, Len, Long_Long_Integer (T.Section));
            Append (Buffer, Len, "}");
         end;
      end loop;
      Append (Buffer, Len, "]");

      -- Voter Status
      Append (Buffer, Len, ",""voter"":{""cycle_count"":");
      Append_Int (Buffer, Len, Long_Long_Integer (Snapshot.Voter.Cycle_Count));
      Append (Buffer, Len, ",""last_passed"":");
      Append_Bool (Buffer, Len, Snapshot.Voter.Last_Passed);
      Append (Buffer, Len, ",""divergences"":");
      Append_Int (Buffer, Len, Long_Long_Integer (Snapshot.Voter.Divergences));
      Append (Buffer, Len, ",""tripped_cycles"":");
      Append_Int (Buffer, Len, Long_Long_Integer (Snapshot.Voter.Tripped_Cycles));
      Append (Buffer, Len, ",""is_degraded"":");
      Append_Bool (Buffer, Len, Snapshot.Voter.Is_Degraded);
      Append (Buffer, Len, "}}");

      Length := Len;
   end Snapshot_To_JSON;

   ----------------------------------------------------------------------------
   -- Parse_Command_JSON
   ----------------------------------------------------------------------------
   procedure Parse_Command_JSON
     (Payload : String;
      Cmd     : out Interlocking_Command;
      Success : out Boolean)
   is
      function Find_Substring (Haystack : String; Needle : String) return Natural is
      begin
         if Needle'Length = 0 or else Haystack'Length < Needle'Length then
            return 0;
         end if;
         for I in Haystack'First .. Haystack'Last - Needle'Length + 1 loop
            if Haystack (I .. I + Needle'Length - 1) = Needle then
               return I;
            end if;
         end loop;
         return 0;
      end Find_Substring;

      function Extract_Number (From_Idx : Natural) return Natural is
         Idx : Natural := From_Idx;
         Val : Natural := 0;
         Found_Digit : Boolean := False;
      begin
         while Idx <= Payload'Last and then (Payload (Idx) = ' ' or else Payload (Idx) = ':') loop
            Idx := Idx + 1;
         end loop;

         while Idx <= Payload'Last and then Payload (Idx) in '0' .. '9' loop
            Found_Digit := True;
            Val := Val * 10 + (Character'Pos (Payload (Idx)) - Character'Pos ('0'));
            Idx := Idx + 1;
         end loop;

         if Found_Digit then
            return Val;
         else
            return 0;
         end if;
      end Extract_Number;

   begin
      Cmd := (Kind => Cmd_None, Route => Null_Route_Id, Sw_Id => Null_Switch_Id,
              Sw_Target => Switch_Normal, Issuer_Id => 1);
      Success := False;

      if Find_Substring (Payload, """set_route""") > 0 then
         Cmd.Kind := Cmd_Set_Route;
         declare
            R_Idx : constant Natural := Find_Substring (Payload, """route""");
         begin
            if R_Idx > 0 then
               Cmd.Route := Route_Id (Extract_Number (R_Idx + 7));
               Success := True;
            end if;
         end;

      elsif Find_Substring (Payload, """cancel_route""") > 0 then
         Cmd.Kind := Cmd_Cancel_Route;
         declare
            R_Idx : constant Natural := Find_Substring (Payload, """route""");
         begin
            if R_Idx > 0 then
               Cmd.Route := Route_Id (Extract_Number (R_Idx + 7));
               Success := True;
            end if;
         end;

      elsif Find_Substring (Payload, """emergency_stop""") > 0 then
         Cmd.Kind := Cmd_Emergency_Stop_All;
         Success  := True;

      elsif Find_Substring (Payload, """throw_switch""") > 0 then
         Cmd.Kind := Cmd_Manual_Switch_Throw;
         declare
            Sw_Idx  : constant Natural := Find_Substring (Payload, """switch""");
            Pos_Idx : constant Natural := Find_Substring (Payload, """position""");
         begin
            if Sw_Idx > 0 then
               Cmd.Sw_Id := Switch_Id (Extract_Number (Sw_Idx + 8));
               if Pos_Idx > 0 and then Find_Substring (Payload (Pos_Idx .. Payload'Last), "REVERSE") > 0 then
                  Cmd.Sw_Target := Switch_Reverse;
               else
                  Cmd.Sw_Target := Switch_Normal;
               end if;
               Success := True;
            end if;
         end;
      end if;

   end Parse_Command_JSON;

end Aspect.Telemetry.Protocol;
