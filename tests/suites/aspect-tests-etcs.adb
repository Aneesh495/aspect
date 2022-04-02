with Aspect.Types; use Aspect.Types;
with Aspect.ETCS; use Aspect.ETCS;
with Aspect.ETCS.Packets; use Aspect.ETCS.Packets;
with Aspect.ETCS.Braking_Curves; use Aspect.ETCS.Braking_Curves;
with Aspect.ETCS.Movement_Authority; use Aspect.ETCS.Movement_Authority;
with Aspect.ETCS.Euroradio; use Aspect.ETCS.Euroradio;
with Aspect.ETCS.DMI_Model; use Aspect.ETCS.DMI_Model;
with Aspect.Tests.Framework; use Aspect.Tests.Framework;
with Aspect.CRC; use Aspect.CRC;
with Interfaces; use Interfaces;

package body Aspect.Tests.ETCS is

   procedure Run_ETCS_Tests (Overall_Passed : in out Boolean) is
      Ctx : Test_Context;
   begin
      Init_Context (Ctx, "Aspect.ETCS (Packets, Braking Curves, MA, Euroradio, DMI)");

      -------------------------------------------------------------------------
      -- Test 1: Packet 12 Movement Authority Serialization Round-Trip
      -------------------------------------------------------------------------
      declare
         P_Orig : Packet_12_Movement_Authority;
         P_Dec  : Packet_12_Movement_Authority;
         Buf    : Byte_Array (1 .. 32);
         W      : Natural;
         Succ   : Boolean;
      begin
         P_Orig.V_MAIN          := 160.0;
         P_Orig.Distance_To_EoA := 4500.0;
         P_Orig.Distance_To_SvL := 4700.0;
         P_Orig.Release_Speed   := 30.0;
         P_Orig.Timeout_Seconds := 240;

         Encode_Packet_12 (P_Orig, Buf, W);
         Assert_Equal_Int (Ctx, 15, Long_Long_Integer (W), "Packet 12 encoded byte length is 15");

         Decode_Packet_12 (Buf (1 .. W), P_Dec, Succ);
         Assert (Ctx, Succ, "Packet 12 decoded successfully");
         Assert_Within_Float (Ctx, 160.0, Float (P_Dec.V_MAIN), 0.1, "Decoded V_MAIN matches");
         Assert_Within_Float (Ctx, 4500.0, Float (P_Dec.Distance_To_EoA), 0.1, "Decoded EoA distance matches");
         Assert_Within_Float (Ctx, 4700.0, Float (P_Dec.Distance_To_SvL), 0.1, "Decoded SvL distance matches");
         Assert_Within_Float (Ctx, 30.0, Float (P_Dec.Release_Speed), 0.1, "Decoded release speed matches");
      end;

      -------------------------------------------------------------------------
      -- Test 2: Packet 21 & 27 Serialization Round-Trip
      -------------------------------------------------------------------------
      declare
         P21_Orig, P21_Dec : Packet_21_Gradient_Profile;
         P27_Orig, P27_Dec : Packet_27_Static_Speed_Profile;
         Buf21 : Byte_Array (1 .. 64);
         Buf27 : Byte_Array (1 .. 64);
         W21, W27 : Natural;
         Succ21, Succ27 : Boolean;
      begin
         P21_Orig.Step_Count := 2;
         P21_Orig.Steps (1)  := (Start_Distance => 0.0, Gradient => 5.0);
         P21_Orig.Steps (2)  := (Start_Distance => 1000.0, Gradient => -10.0);

         Encode_Packet_21 (P21_Orig, Buf21, W21);
         Decode_Packet_21 (Buf21 (1 .. W21), P21_Dec, Succ21);
         Assert (Ctx, Succ21, "Packet 21 decoded successfully");
         Assert_Equal_Int (Ctx, 2, Long_Long_Integer (P21_Dec.Step_Count), "P21 step count matches");
         Assert_Within_Float (Ctx, 5.0, Float (P21_Dec.Steps (1).Gradient), 0.1, "P21 step 1 gradient matches");
         Assert_Within_Float (Ctx, -10.0, Float (P21_Dec.Steps (2).Gradient), 0.1, "P21 step 2 gradient matches");

         P27_Orig.Step_Count := 1;
         P27_Orig.Steps (1)  := (Start_Distance => 0.0, Speed_Limit => 140.0);
         Encode_Packet_27 (P27_Orig, Buf27, W27);
         Decode_Packet_27 (Buf27 (1 .. W27), P27_Dec, Succ27);
         Assert (Ctx, Succ27, "Packet 27 decoded successfully");
         Assert_Within_Float (Ctx, 140.0, Float (P27_Dec.Steps (1).Speed_Limit), 0.1, "P27 speed limit matches");
      end;

      -------------------------------------------------------------------------
      -- Test 3: ERA Subset-026 Chapter 3.13 Braking Curve Hierarchy
      -------------------------------------------------------------------------
      declare
         Params : Train_Brake_Parameters;
         Env    : Supervision_Envelope;
      begin
         Params.Nominal_Emergency_A := 1.20;
         Params.Nominal_Service_A   := 0.85;
         Params.Adhesion            := 1.00;
         Params.Rotating_Mass       := 10.0;
         Params.Gradient            := 0.0;

         -- Calculate envelopes 800m before target Stop (EoA = 800m, SvL = 1000m)
         Calculate_Envelopes
           (Params          => Params,
            Current_Speed   => 100.0,
            Distance_To_EoA => 800.0,
            Distance_To_SvL => 1000.0,
            Target_Speed    => 0.0,
            Ceiling_Speed   => 160.0,
            Envelope        => Env);

         -- Strict Subset-026 safety hierarchy invariant:
         -- Indication <= Permitted <= Warning <= SBI <= EBI
         Assert (Ctx, Env.Indication_Speed <= Env.Permitted_Speed,
                 "Subset-026 Invariant: Indication <= Permitted");
         Assert (Ctx, Env.Permitted_Speed <= Env.Warning_Speed,
                 "Subset-026 Invariant: Permitted <= Warning");
         Assert (Ctx, Env.Warning_Speed <= Env.SBI_Speed,
                 "Subset-026 Invariant: Warning <= Service Brake Intervention");
         Assert (Ctx, Env.SBI_Speed <= Env.EBI_Speed,
                 "Subset-026 Invariant: SBI <= Emergency Brake Intervention");

         -- Supervision status evaluation:
         -- Current speed 100 km/h: evaluate where it falls relative to Permitted
         Assert (Ctx, Env.Current_Status in Status_Normal | Status_Indication | Status_Overspeed_Warning,
                 "Speed evaluation returns legitimate operational status");

         -- Test emergency trip status when speed exceeds EBI
         Assert (Ctx, Evaluate_State (Env.EBI_Speed + 5.0, Env) = Status_Emergency_Trip,
                 "Speed exceeding EBI triggers Status_Emergency_Trip");
      end;

      -------------------------------------------------------------------------
      -- Test 4: Movement Authority Lifecycle & Overrun Tripping
      -------------------------------------------------------------------------
      declare
         P12  : Packet_12_Movement_Authority;
         P21  : Packet_21_Gradient_Profile;
         P27  : Packet_27_Static_Speed_Profile;
         Auth : Active_Authority;
      begin
         P12.Distance_To_EoA := 2000.0;
         P12.Distance_To_SvL := 2200.0;
         P12.Timeout_Seconds := 300;

         Initialize_Authority (Auth, P12, P21, P27, Start_Km => 10_000.0);
         Assert (Ctx, Auth.Status = MA_Valid, "Initial MA status is MA_Valid");
         Assert_Within_Float (Ctx, 2000.0, Float (Auth.Remaining_EoA_M), 0.1, "Remaining EoA is 2000m");

         -- Advance train to 11,600m (400m before EoA: within 500m threshold)
         Update_Position (Auth, New_Chainage => 11_600.0, Current_Speed => 60.0);
         Assert (Ctx, Auth.Status = MA_Approaching_EoA, "MA status transitions to MA_Approaching_EoA");
         Assert_Within_Float (Ctx, 400.0, Float (Auth.Remaining_EoA_M), 0.1, "Remaining EoA is 400m");

         -- Overrun test: Train overruns EoA (12,050m > 12,000m EoA)
         Update_Position (Auth, New_Chainage => 12_050.0, Current_Speed => 20.0);
         Assert (Ctx, Auth.Status = MA_Overrun_Tripped, "Overrunning EoA trips MA_Overrun_Tripped");
      end;

      -------------------------------------------------------------------------
      -- Test 5: Euroradio Authenticated Frames & Replay Protection
      -------------------------------------------------------------------------
      declare
         Chan_Tx, Chan_Rx : Euroradio_Channel;
         Frame            : Euroradio_Frame;
         Payload_Tx       : constant Byte_Array := [1, 2, 3, 4, 5, 6, 7, 8];
         Payload_Rx       : Byte_Array (1 .. 16);
         Rx_Len           : Natural;
         Valid            : Boolean;
      begin
         Initialize_Channel (Chan_Tx, Session_Id => 42, Timeout_S => 30);
         Initialize_Channel (Chan_Rx, Session_Id => 42, Timeout_S => 30);

         Construct_Frame (Chan_Tx, Payload_Tx, 8, Timestamp => 1000, Frame => Frame);
         Assert_Equal_Int (Ctx, 1, Long_Long_Integer (Frame.Header.Sequence_Number),
                           "First Euroradio frame sequence number is 1");

         -- Ingest valid frame
         Ingest_Frame (Chan_Rx, Frame, Payload_Rx, Rx_Len, Valid);
         Assert (Ctx, Valid, "Euroradio frame accepted with valid CRC-32C and sequence");
         Assert_Equal_Int (Ctx, 8, Long_Long_Integer (Rx_Len), "Payload length is 8");
         Assert_Equal_Int (Ctx, 1, Long_Long_Integer (Payload_Rx (1)), "Payload byte 1 matches");

         -- Replay attack defense: Re-sending the same frame must be rejected!
         Ingest_Frame (Chan_Rx, Frame, Payload_Rx, Rx_Len, Valid);
         Assert (Ctx, not Valid, "Euroradio strictly rejects replayed frame sequence number");
      end;

      -------------------------------------------------------------------------
      -- Test 6: Driver Machine Interface (DMI) Speedometer Mapping
      -------------------------------------------------------------------------
      declare
         DMI : DMI_State;
         Env : Supervision_Envelope;
      begin
         Env.Permitted_Speed    := 160.0;
         Env.Target_Speed       := 80.0;
         Env.Distance_To_Target := 500.0;
         Env.Current_Status     := Status_Normal;

         Update_DMI (DMI, Current_Speed => 120.0, Envelope => Env, Level => Level_2, Mode => Mode_FS);
         Assert_Within_Float (Ctx, 90.0, DMI.Speedometer_Angle, 0.1,
                              "120 km/h speedometer angle is 90 degrees");
         Assert_Within_Float (Ctx, 120.0, DMI.Permitted_Angle, 0.1,
                              "160 km/h permitted hook angle is 120 degrees");
         Assert_Equal_Int (Ctx, Long_Long_Integer (Gauge_Color'Pos (Color_Grey)),
                           Long_Long_Integer (Gauge_Color'Pos (DMI.Needle_Color)),
                           "Normal speed displays Grey needle");
         Assert (Ctx, not DMI.Acoustic_Alarm, "No acoustic alarm under normal speed");
      end;

      if not Summarize (Ctx) then
         Overall_Passed := False;
      end if;
   end Run_ETCS_Tests;

end Aspect.Tests.ETCS;
