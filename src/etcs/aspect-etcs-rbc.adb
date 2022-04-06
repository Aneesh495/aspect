with Aspect.Interlocking.Routes; use Aspect.Interlocking.Routes;

package body Aspect.ETCS.RBC is

   procedure Initialize_RBC (Centre : out Radio_Block_Centre) is
   begin
      Centre.Sessions         := [others => <>];
      Centre.Registered_Count := 0;
   end Initialize_RBC;

   procedure Register_Train_Session
     (Centre : in out Radio_Block_Centre;
      Train  : Train_Id)
   is
   begin
      Centre.Sessions (Train).Train           := Train;
      Centre.Sessions (Train).State           := Session_Active;
      Centre.Sessions (Train).MA_Needs_Update := False;
      if Natural (Train) > Centre.Registered_Count then
         Centre.Registered_Count := Natural (Train);
      end if;
   end Register_Train_Session;

   procedure Process_Position_Report
     (Centre : in out Radio_Block_Centre;
      Report : Train_Position_Report)
   is
   begin
      if Report.Train /= Null_Train_Id then
         Centre.Sessions (Report.Train).Last_Position := Report;
      end if;
   end Process_Position_Report;

   procedure Generate_Movement_Authority
     (Centre : in out Radio_Block_Centre;
      Core   : Interlocking_Core;
      Train  : Train_Id;
      Route  : Route_Id;
      Succ   : out Boolean)
   is
      R : Interlocking_Route renames Core.Routes (Route);
      Sess : RBC_Train_Session renames Centre.Sessions (Train);
      Total_Dist : Distance_M := 0.0;
   begin
      -- Authority is only generated if interlocking has locked and cleared the route
      if not (R.State in Route_Cleared | Route_Occupied | Route_Sectional_Release) then
         Succ := False;
         return;
      end if;

      -- Calculate cumulative route distance
      for I in 1 .. R.Section_Count loop
         declare
            Sec_Id : constant Section_Id_Base := R.Path_Sections (I);
         begin
            if Sec_Id /= Null_Section_Id then
               Total_Dist := Total_Dist + Core.Net.Sections (Sec_Id).Length_M;
            end if;
         end;
      end loop;

      Sess.Allocated_Route := Route;

      -- Populate Packet 12
      Sess.Last_Generated_MA.V_MAIN          := 160.0;
      Sess.Last_Generated_MA.Distance_To_EoA := Total_Dist;
      Sess.Last_Generated_MA.Distance_To_SvL := Total_Dist + R.Overlap_Distance;
      Sess.Last_Generated_MA.Release_Speed   := 25.0;
      Sess.Last_Generated_MA.Timeout_Seconds := 300;

      -- Populate Packet 21 (Gradient Profile)
      Sess.Last_Generated_P21.Step_Count := Natural'Min (R.Section_Count, Max_Gradient_Segments);
      declare
         Cum_Dist : Distance_M := 0.0;
      begin
         for I in 1 .. Sess.Last_Generated_P21.Step_Count loop
            declare
               Sec_Id : constant Section_Id_Base := R.Path_Sections (I);
            begin
               if Sec_Id /= Null_Section_Id then
                  Sess.Last_Generated_P21.Steps (I) :=
                    (Start_Distance => Cum_Dist,
                     Gradient       => Core.Net.Sections (Sec_Id).Gradient);
                  Cum_Dist := Cum_Dist + Core.Net.Sections (Sec_Id).Length_M;
               end if;
            end;
         end loop;
      end;

      -- Populate Packet 27 (Static Speed Profile)
      Sess.Last_Generated_P27.Step_Count := Natural'Min (R.Section_Count, Max_Speed_Segments);
      declare
         Cum_Dist : Distance_M := 0.0;
      begin
         for I in 1 .. Sess.Last_Generated_P27.Step_Count loop
            declare
               Sec_Id : constant Section_Id_Base := R.Path_Sections (I);
            begin
               if Sec_Id /= Null_Section_Id then
                  Sess.Last_Generated_P27.Steps (I) :=
                    (Start_Distance => Cum_Dist,
                     Speed_Limit    => Core.Net.Sections (Sec_Id).Line_Speed_Limit);
                  Cum_Dist := Cum_Dist + Core.Net.Sections (Sec_Id).Length_M;
               end if;
            end;
         end loop;
      end;

      Sess.MA_Needs_Update := True;
      Succ                 := True;
   end Generate_Movement_Authority;

   function Has_Pending_MA
     (Centre : Radio_Block_Centre;
      Train  : Train_Id) return Boolean
   is
   begin
      return Centre.Sessions (Train).MA_Needs_Update;
   end Has_Pending_MA;

end Aspect.ETCS.RBC;
