package body Aspect.Sim.Track_Simulation is

   procedure Initialize_Registry (Reg : out Simulation_Registry) is
   begin
      Reg.Trains      := [others => <>];
      Reg.Train_Count := 0;
   end Initialize_Registry;

   procedure Add_Train
     (Reg       : in out Simulation_Registry;
      Train     : Train_Vehicle;
      Start_Km  : Track_Chainage;
      Start_Sec : Section_Id)
   is
      T_Id : constant Train_Id := Train_Id (Train.Id);
   begin
      Reg.Trains (T_Id).Id              := Train.Id;
      Reg.Trains (T_Id).Vehicle         := Train;
      Initialize_Odometry (Reg.Trains (T_Id).Odometry, Start_Km);
      Reg.Trains (T_Id).Current_Section := Start_Sec;
      Reg.Trains (T_Id).Rear_Section    := Start_Sec;
      Reg.Trains (T_Id).Is_Active       := True;

      if Natural (T_Id) > Reg.Train_Count then
         Reg.Train_Count := Natural (T_Id);
      end if;
   end Add_Train;

   procedure Update_Train_Positions
     (Reg     : in out Simulation_Registry;
      Net     : in out Railway_Network;
      Core    : in out Interlocking_Core;
      Delta_S : Float)
   is
      Dist_Traveled : Distance_M;
   begin
      for I in 1 .. Reg.Train_Count loop
         declare
            T : Simulated_Train renames Reg.Trains (Train_Id (I));
         begin
            if T.Is_Active and then T.Current_Section /= Null_Section_Id then
               declare
                  Curr_Sec_Id : constant Section_Id := Section_Id (T.Current_Section);
                  Grad        : constant Gradient_Per_Mille :=
                    Net.Sections (Curr_Sec_Id).Gradient;
                  Adh         : constant Adhesion_Factor := 1.00;
                  Is_Accel    : constant Boolean := (T.Vehicle.Throttle_Demand > 0.0);
                  Is_Braking  : constant Boolean :=
                    (T.Vehicle.Brake_Demand > 0.0 or T.Vehicle.Is_Emergency_Braking);
               begin
                  -- 1. Step train vehicle physics
                  Step_Dynamics (T.Vehicle, Grad, Adh, Delta_S, Dist_Traveled);

                  -- 2. Step sensor odometry
                  Update_Sensors
                    (Odo             => T.Odometry,
                     True_Speed      => T.Vehicle.Speed,
                     Is_Accelerating => Is_Accel,
                     Is_Braking      => Is_Braking,
                     Adhesion_Low    => False,
                     Delta_S         => Delta_S);

                  -- 3. Check front boundary crossing into downstream block
                  declare
                     Front_Km  : constant Track_Chainage := T.Odometry.True_Chainage;
                     Rear_Km   : constant Track_Chainage :=
                       (if Front_Km > Track_Chainage (T.Vehicle.Length_M)
                        then Front_Km - Track_Chainage (T.Vehicle.Length_M)
                        else 0.0);
                     Sec_End   : constant Track_Chainage := Net.Sections (Curr_Sec_Id).End_Chainage;
                  begin
                     if Front_Km >= Sec_End then
                        declare
                           Next_Sec : constant Section_Id_Base :=
                             Next_Section (Net, Curr_Sec_Id, Dir_Nominal);
                        begin
                           if Next_Sec /= Null_Section_Id and then Next_Sec /= T.Current_Section then
                              -- Shunt next section ahead
                              Handle_Train_Movement
                                (Core        => Core,
                                 Train       => Train_Id (I),
                                 Entered_Sec => Section_Id (Next_Sec),
                                 Vacated_Sec => Null_Section_Id);
                              T.Current_Section := Next_Sec;
                           end if;
                        end;
                     end if;

                     -- 4. Check rear boundary vacating upstream block
                     if T.Rear_Section /= T.Current_Section then
                        declare
                           Old_Sec_End : constant Track_Chainage :=
                             Net.Sections (Section_Id (T.Rear_Section)).End_Chainage;
                        begin
                           if Rear_Km >= Old_Sec_End then
                              -- Vacated old section completely behind rear wheelset
                              Handle_Train_Movement
                                (Core        => Core,
                                 Train       => Train_Id (I),
                                 Entered_Sec => Section_Id (T.Current_Section),
                                 Vacated_Sec => T.Rear_Section);
                              T.Rear_Section := T.Current_Section;
                           end if;
                        end;
                     end if;
                  end;
               end;
            end if;
         end;
      end loop;
   end Update_Train_Positions;

end Aspect.Sim.Track_Simulation;
