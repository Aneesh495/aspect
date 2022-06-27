-- Implementation of formal verification oracles.

with Aspect.Types; use Aspect.Types;
with Aspect.Topology.Switches; use Aspect.Topology.Switches;
with Aspect.Interlocking.Routes; use Aspect.Interlocking.Routes;
with Aspect.Interlocking.Flank; use Aspect.Interlocking.Flank;
with Aspect.Interlocking.Engine; use Aspect.Interlocking.Engine;
with Aspect.ETCS.Braking_Curves; use Aspect.ETCS.Braking_Curves;
with Aspect.ETCS.Packets; use Aspect.ETCS.Packets;
with Aspect.Sim.Track_Simulation; use Aspect.Sim.Track_Simulation;
with Aspect.Vital.Cyclic_Executive; use Aspect.Vital.Cyclic_Executive;

package body Aspect.Formal.Oracles is

   procedure Set_Detail (Report : in out Oracle_Report; Msg : String) is
      Copy_Len : constant Natural := Natural'Min (Msg'Length, 64);
   begin
      Report.Detail := [others => ' '];
      Report.Detail (1 .. Copy_Len) := Msg (Msg'First .. Msg'First + Copy_Len - 1);
      Report.Detail_Len := Copy_Len;
   end Set_Detail;

   function Verify_Zero_Collision
     (World : World_Context) return Oracle_Report
   is
      Report : Oracle_Report := (Passed => True, Violations => 0, others => <>);
      Count  : constant Natural := World.Registry.Train_Count;
   begin
      if Count < 2 then
         Set_Detail (Report, "Trivial zero-collision: fewer than 2 active trains");
         return Report;
      end if;

      for I in 1 .. Count loop
         for J in I + 1 .. Count loop
            declare
               T1 : constant Simulated_Train := World.Registry.Trains (Train_Id (I));
               T2 : constant Simulated_Train := World.Registry.Trains (Train_Id (J));
            begin
               if T1.Is_Active and then T2.Is_Active then
                  if T1.Current_Section = T2.Current_Section and then
                     T1.Current_Section /= Null_Section_Id
                  then
                     declare
                        Sep_M : constant Float :=
                          abs (Float (T1.Odometry.True_Chainage) - Float (T2.Odometry.True_Chainage)) * 1000.0;
                        Min_Safe_M : constant Float :=
                          (Float (T1.Vehicle.Length_M) + Float (T2.Vehicle.Length_M)) * 0.5;
                     begin
                        if Sep_M < Min_Safe_M then
                           Report.Passed := False;
                           Report.Violations := Report.Violations + 1;
                           Set_Detail (Report, "Collision detected between Train " &
                                       Natural'Image (I) & " and Train " & Natural'Image (J));
                           return Report;
                        end if;
                     end;
                  end if;
               end if;
            end;
         end loop;
      end loop;

      Set_Detail (Report, "All trains spatially disjoint across track blocks");
      return Report;
   end Verify_Zero_Collision;

   function Verify_Detector_Locking
     (World : World_Context) return Oracle_Report
   is
      Report : Oracle_Report := (Passed => True, Violations => 0, others => <>);
   begin
      for I in 1 .. World.Net.Switch_Count loop
         declare
            Sw     : constant Turnout_Switch := World.Net.Switches (Switch_Id (I));
            Sec_Id : constant Section_Id_Base := Sw.Point_Section;
         begin
            if Sec_Id /= Null_Section_Id and then
               World.Net.Sections (Section_Id (Sec_Id)).Occupancy /= State_Clear
            then
               -- When point section is occupied, switch must not be in transit or moving
               if Sw.Position = Switch_In_Transit or else
                  Sw.Target_Position /= Sw.Position or else
                  Sw.Stroke_Timer_Ms > 0
               then
                  Report.Passed := False;
                  Report.Violations := Report.Violations + 1;
                  Set_Detail (Report, "Switch " & Natural'Image (I) &
                              " moving under track section occupancy");
                  return Report;
               end if;
            end if;
         end;
      end loop;

      Set_Detail (Report, "Point detector locking strictly enforced on all turnouts");
      return Report;
   end Verify_Detector_Locking;

   function Verify_Flank_Integrity
     (World : World_Context) return Oracle_Report
   is
      Report   : Oracle_Report := (Passed => True, Violations => 0, others => <>);
      Core_Ref : constant Interlocking_Core := Get_Voted_Core (World.Supervisor);
   begin
      for I in 1 .. Core_Ref.Route_Count loop
         declare
            R : constant Interlocking_Route := Core_Ref.Routes (Route_Id (I));
         begin
            if R.State in Route_Interlocked | Route_Cleared then
               if not Aspect.Interlocking.Flank.Verify_Flank_Integrity
                        (Table => Core_Ref.Flank,
                         Net   => World.Net,
                         Route => Route_Id (I))
               then
                  Report.Passed := False;
                  Report.Violations := Report.Violations + 1;
                  Set_Detail (Report, "Flank integrity check failed for Route " & Natural'Image (I));
                  return Report;
               end if;
            end if;
         end;
      end loop;

      Set_Detail (Report, "Flank protection barrier fully verified");
      return Report;
   end Verify_Flank_Integrity;

   function Verify_Curve_Containment
     (World : World_Context) return Oracle_Report
   is
      Report : Oracle_Report := (Passed => True, Violations => 0, others => <>);
   begin
      for I in 1 .. World.Registry.Train_Count loop
         declare
            T : constant Simulated_Train := World.Registry.Trains (Train_Id (I));
         begin
            if T.Is_Active then
               declare
                  Speed  : constant Speed_Kph := Mps_To_Kph (T.Vehicle.Speed);
                  Env    : Supervision_Envelope;
                  Params : Train_Brake_Parameters;
                  MA     : constant Packet_12_Movement_Authority :=
                    World.RBC.Sessions (Train_Id (I)).Last_Generated_MA;
               begin
                  Params.Nominal_Emergency_A := 1.20;
                  Params.Nominal_Service_A   := 0.85;

                  Calculate_Envelopes
                    (Params          => Params,
                     Current_Speed   => Speed,
                     Distance_To_EoA => MA.Distance_To_EoA,
                     Distance_To_SvL => MA.Distance_To_SvL,
                     Target_Speed    => 0.0,
                     Ceiling_Speed   => MA.V_MAIN,
                     Envelope        => Env);

                  if Speed > Env.EBI_Speed + 0.1 then
                     Report.Passed := False;
                     Report.Violations := Report.Violations + 1;
                     Set_Detail (Report, "Train " & Natural'Image (I) & " exceeded EBI envelope: " &
                                 Float'Image (Float (Speed)) & " > " & Float'Image (Float (Env.EBI_Speed)));
                     return Report;
                  end if;
               end;
            end if;
         end;
      end loop;

      Set_Detail (Report, "All trains strictly enclosed by EBI supervision curves");
      return Report;
   end Verify_Curve_Containment;

end Aspect.Formal.Oracles;
