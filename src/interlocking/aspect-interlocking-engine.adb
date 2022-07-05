with Aspect.Topology.Tracks; use Aspect.Topology.Tracks;
with Aspect.Topology.Switches; use Aspect.Topology.Switches;
with Aspect.Topology.Signals; use Aspect.Topology.Signals;
with Aspect.Interlocking.Detector; use Aspect.Interlocking.Detector;

package body Aspect.Interlocking.Engine is

   procedure Initialize_Core
     (Core : out Interlocking_Core;
      Net  : Railway_Network)
   is
   begin
      Core.Net                := Net;
      Core.Routes             := [others => <>];
      Core.Route_Count        := 0;
      Core.Cycle_Count        := 0;
      Core.Emergency_Stop_All := False;
      Initialize_Table (Core.Locking);
      Initialize_Flank_Table (Core.Flank);
      Initialize_Overlap_Table (Core.Overlaps);
      Initialize_Approach_Table (Core.Approaches);
   end Initialize_Core;

   procedure Register_Route
     (Core  : in out Interlocking_Core;
      Route : Interlocking_Route)
   is
   begin
      if Natural (Route.Id) > Core.Route_Count then
         Core.Route_Count := Natural (Route.Id);
      end if;
      Core.Routes (Route.Id) := Route;
   end Register_Route;

   procedure Finalize_Configuration (Core : in out Interlocking_Core) is
   begin
      Synthesize_Conflicts (Core.Locking, Core.Routes, Core.Route_Count);
   end Finalize_Configuration;

   procedure Execute_Command
     (Core    : in out Interlocking_Core;
      Cmd     : Interlocking_Command;
      Success : out Boolean;
      Reason  : out Rejection_Reason)
   is
   begin
      Success := False;
      Reason  := Reject_None;

      if Core.Emergency_Stop_All and then Cmd.Kind /= Cmd_Acknowledge_Alarm then
         Reason := Reject_Emergency_Active;
         return;
      end if;

      case Cmd.Kind is
         when Cmd_None =>
            Success := True;

         when Cmd_Set_Route =>
            declare
               R_Id : constant Route_Id_Base := Cmd.Route;
            begin
               if R_Id = Null_Route_Id or else Natural (R_Id) > Core.Route_Count then
                  Reason := Reject_Route_Already_Active;
                  return;
               end if;

               declare
                  R : Interlocking_Route renames Core.Routes (R_Id);
                  Succ : Boolean;
               begin
                  if R.State /= Route_Unset then
                     Reason := Reject_Route_Already_Active;
                     return;
                  end if;

                  -- Check conflicting route mutual exclusion
                  if Has_Active_Conflict (Core.Locking, Core.Routes, R_Id) then
                     Reason := Reject_Conflicting_Route_Locked;
                     return;
                  end if;

                  -- Check path track section clearance and unreserved status
                  for I in 1 .. R.Section_Count loop
                     declare
                        Sec_Id : constant Section_Id_Base := R.Path_Sections (I);
                     begin
                        if Sec_Id = Null_Section_Id
                          or else not Is_Clear_And_Unlocked (Core.Net.Sections (Sec_Id))
                        then
                           Reason := Reject_Section_Occupied;
                           return;
                        end if;
                     end;
                  end loop;

                  -- Check overlap availability
                  if R.Overlap_Section /= Null_Section_Id then
                     if not Can_Reserve_Overlap (Core.Net, R.Overlap_Section) then
                        Reason := Reject_Overlap_Unavailable;
                        return;
                     end if;
                  end if;

                  -- Check switch detector locking
                  for I in 1 .. R.Switch_Count loop
                     declare
                        Sw_Req : constant Switch_Alignment := R.Required_Switches (I);
                     begin
                        if not Can_Throw_Switch (Core.Net, Sw_Req.Switch) then
                           Reason := Reject_Switch_Detector_Locked;
                           return;
                        end if;
                     end;
                  end loop;

                  -- Command all switch throws
                  declare
                     All_Switches_Aligned : Boolean := True;
                     Throw_Accepted       : Boolean;
                  begin
                     for I in 1 .. R.Switch_Count loop
                        declare
                           Sw_Req : constant Switch_Alignment := R.Required_Switches (I);
                           Sw     : Turnout_Switch renames Core.Net.Switches (Sw_Req.Switch);
                        begin
                           Request_Throw (Sw, Sw_Req.Position,
                                          Track_Occupied => False,
                                          Accepted       => Throw_Accepted);
                           if not Throw_Accepted then
                              Reason := Reject_Switch_Throw_Failed;
                              return;
                           end if;

                           if Sw.Position /= Sw_Req.Position then
                              All_Switches_Aligned := False;
                           end if;
                        end;
                     end loop;

                     -- Reserve overlap
                     if R.Overlap_Section /= Null_Section_Id then
                        Reserve_Overlap (Core.Overlaps, Core.Net, R_Id,
                                         R.Overlap_Section, R.Overlap_Distance, Succ);
                        if not Succ then
                           Reason := Reject_Overlap_Unavailable;
                           return;
                        end if;
                     end if;

                     -- Lock route path sections
                     for I in 1 .. R.Section_Count loop
                        Lock_Section (Core.Net.Sections (R.Path_Sections (I)),
                                      R_Id, Lock_Route_Reserved);
                     end loop;

                     if All_Switches_Aligned then
                        -- Lock switches for route
                        for I in 1 .. R.Switch_Count loop
                           Lock_For_Route (Core.Net.Switches (R.Required_Switches (I).Switch), R_Id);
                        end loop;

                        -- Lock flank defenses
                        Lock_Flank_Defenses (Core.Flank, Core.Net, R_Id, Succ);
                        if not Succ then
                           Reason := Reject_Flank_Protection_Failed;
                           return;
                        end if;

                        Transition_State (R, Route_Interlocked, Succ);
                        Transition_State (R, Route_Cleared, Succ);

                        -- Clear origin signal to proceed aspect
                        if R.Origin_Signal /= Null_Signal_Id then
                           Set_Aspect (Core.Net.Signals (R.Origin_Signal), Aspect_Clear);
                        end if;
                     else
                        -- Switches in transit; wait for stroke timers to finish
                        Transition_State (R, Route_Requested, Succ);
                     end if;

                     Success := True;
                  end;
               end;
            end;

         when Cmd_Cancel_Route =>
            declare
               R_Id : constant Route_Id_Base := Cmd.Route;
            begin
               if R_Id /= Null_Route_Id and then Natural (R_Id) <= Core.Route_Count then
                  declare
                     R      : Interlocking_Route renames Core.Routes (R_Id);
                     Status : Cancellation_Status;
                  begin
                     Request_Cancellation (Core.Approaches, Core.Net, R, Status);
                     if Status = Cancel_Immediate then
                        -- Unlock resources immediately
                        for I in 1 .. R.Section_Count loop
                           Unlock_Section (Core.Net.Sections (R.Path_Sections (I)));
                        end loop;
                        for I in 1 .. R.Switch_Count loop
                           Unlock_From_Route (Core.Net.Switches (R.Required_Switches (I).Switch));
                        end loop;
                        Unlock_Flank_Defenses (Core.Flank, Core.Net, R_Id);
                        Release_Overlap (Core.Overlaps, Core.Net, R_Id);
                        Success := True;
                     elsif Status = Cancel_Approach_Timer then
                        Success := True; -- Cancellation queued under approach lock
                     else
                        Reason := Reject_Approach_Locked;
                     end if;
                  end;
               end if;
            end;

         when Cmd_Emergency_Stop_Route =>
            declare
               R_Id : constant Route_Id_Base := Cmd.Route;
            begin
               if R_Id /= Null_Route_Id and then Natural (R_Id) <= Core.Route_Count then
                  declare
                     R : Interlocking_Route renames Core.Routes (R_Id);
                  begin
                     if R.Origin_Signal /= Null_Signal_Id then
                        Drop_To_Danger (Core.Net.Signals (R.Origin_Signal));
                     end if;
                     Success := True;
                  end;
               end if;
            end;

         when Cmd_Emergency_Stop_All =>
            Trigger_Emergency_Stop (Core);
            Success := True;

         when Cmd_Manual_Switch_Throw =>
            declare
               Sw_Id : constant Switch_Id_Base := Cmd.Sw_Id;
            begin
               if Sw_Id /= Null_Switch_Id and then Natural (Sw_Id) <= Core.Net.Switch_Count then
                  declare
                     Sw       : Turnout_Switch renames Core.Net.Switches (Sw_Id);
                     Occupied : constant Boolean :=
                       (Sw.Point_Section /= Null_Section_Id and then
                        Natural (Sw.Point_Section) <= Core.Net.Section_Count and then
                        Core.Net.Sections (Section_Id (Sw.Point_Section)).Occupancy /= State_Clear);
                     Succ     : Boolean;
                  begin
                     Request_Throw (Sw, Cmd.Sw_Target,
                                    Track_Occupied => Occupied,
                                    Accepted       => Succ);
                     Success := Succ;
                     if not Succ then
                        Reason := Reject_Switch_Detector_Locked;
                     end if;
                  end;
               end if;
            end;

         when Cmd_Acknowledge_Alarm =>
            Reset_Emergency_Stop (Core);
            Success := True;
      end case;
   end Execute_Command;

   procedure Step_Cycle
     (Core     : in out Interlocking_Core;
      Delta_Ms : Positive)
   is
      Succ : Boolean;
   begin
      Core.Cycle_Count := Core.Cycle_Count + 1;

      -- 1. Advance switch point machine stroke timers
      for I in 1 .. Core.Net.Switch_Count loop
         Update_Stroke_Timer (Core.Net.Switches (Switch_Id (I)), Delta_Ms);
      end loop;

      -- 2. Process routes in Route_Requested awaiting switch transit completion
      for I in 1 .. Core.Route_Count loop
         declare
            R : Interlocking_Route renames Core.Routes (Route_Id (I));
         begin
            if R.State = Route_Requested then
               declare
                  All_Aligned : Boolean := True;
               begin
                  for S_Idx in 1 .. R.Switch_Count loop
                     declare
                        Req : constant Switch_Alignment := R.Required_Switches (S_Idx);
                        Sw  : constant Turnout_Switch   := Core.Net.Switches (Req.Switch);
                     begin
                        if not Has_Verified_Detection (Sw, Req.Position) then
                           All_Aligned := False;
                           exit;
                        end if;
                     end;
                  end loop;

                  if All_Aligned then
                     for S_Idx in 1 .. R.Switch_Count loop
                        Lock_For_Route (Core.Net.Switches (R.Required_Switches (S_Idx).Switch), Route_Id (I));
                     end loop;

                     Lock_Flank_Defenses (Core.Flank, Core.Net, Route_Id (I), Succ);
                     Transition_State (R, Route_Interlocked, Succ);
                     Transition_State (R, Route_Cleared, Succ);

                     if R.Origin_Signal /= Null_Signal_Id then
                        Set_Aspect (Core.Net.Signals (R.Origin_Signal), Aspect_Clear);
                     end if;
                  end if;
               end;
            end if;

            -- 3. Invariant check: If route is Cleared, ensure all switches maintain detection and flanks hold
            if R.State = Route_Cleared then
               declare
                  Integrity_Lost : Boolean := False;
               begin
                  for S_Idx in 1 .. R.Switch_Count loop
                     declare
                        Req : constant Switch_Alignment := R.Required_Switches (S_Idx);
                        Sw  : constant Turnout_Switch   := Core.Net.Switches (Req.Switch);
                     begin
                        if not Has_Verified_Detection (Sw, Req.Position) then
                           Integrity_Lost := True;
                           exit;
                        end if;
                     end;
                  end loop;

                  if not Verify_Flank_Integrity (Core.Flank, Core.Net, Route_Id (I)) then
                     Integrity_Lost := True;
                  end if;

                  if Integrity_Lost and then R.Origin_Signal /= Null_Signal_Id then
                     -- Trip signal to danger immediately
                     Drop_To_Danger (Core.Net.Signals (R.Origin_Signal));
                  end if;
               end;
            end if;
         end;
      end loop;

      -- 4. Update approach locking countdown timers
      Update_Approach_Timers (Core.Approaches, Core.Net, Core.Routes, Delta_Ms);

      -- Clean up any routes that finished approach cancellation
      for I in 1 .. Core.Route_Count loop
         declare
            R : Interlocking_Route renames Core.Routes (Route_Id (I));
         begin
            if R.State = Route_Cancelled then
               for Sec_Idx in 1 .. R.Section_Count loop
                  Unlock_Section (Core.Net.Sections (R.Path_Sections (Sec_Idx)));
               end loop;
               for Sw_Idx in 1 .. R.Switch_Count loop
                  Unlock_From_Route (Core.Net.Switches (R.Required_Switches (Sw_Idx).Switch));
               end loop;
               Unlock_Flank_Defenses (Core.Flank, Core.Net, Route_Id (I));
               Release_Overlap (Core.Overlaps, Core.Net, Route_Id (I));
               Transition_State (R, Route_Unset, Succ);
            end if;
         end;
      end loop;
   end Step_Cycle;

   procedure Handle_Train_Movement
     (Core        : in out Interlocking_Core;
      Train       : Train_Id;
      Entered_Sec : Section_Id;
      Vacated_Sec : Section_Id_Base := Null_Section_Id)
   is
      Succ : Boolean;
   begin
      -- Shunt entered section
      Shunt_By_Train (Core.Net.Sections (Entered_Sec), Train);

      -- Clear vacated section if specified
      if Vacated_Sec /= Null_Section_Id then
         Clear_Train_Shunt (Core.Net.Sections (Vacated_Sec), Train);
      end if;

      -- Check all active routes for train progression
      for I in 1 .. Core.Route_Count loop
         declare
            R : Interlocking_Route renames Core.Routes (Route_Id (I));
         begin
            if Is_Active (R) then
               -- Check if train entered first route section
               if R.State in Route_Cleared | Route_Approached then
                  if R.Section_Count > 0 and then R.Path_Sections (1) = Entered_Sec then
                     Transition_State (R, Route_Occupied, Succ);
                     R.Assigned_Train      := Train;
                     R.Current_Section_Idx := 1;
                     -- Drop origin signal to Stop behind train
                     if R.Origin_Signal /= Null_Signal_Id then
                        Drop_To_Danger (Core.Net.Signals (R.Origin_Signal));
                     end if;
                  end if;
               elsif R.State in Route_Occupied | Route_Sectional_Release then
                  -- Process sectional route release behind the train
                  if Vacated_Sec /= Null_Section_Id then
                     for Sec_Idx in 1 .. R.Section_Count loop
                        if R.Path_Sections (Sec_Idx) = Vacated_Sec then
                           -- Unlock the vacated track section for following trains
                           Unlock_Section (Core.Net.Sections (Vacated_Sec));
                           Transition_State (R, Route_Sectional_Release, Succ);
                        end if;
                     end loop;

                     -- Check if train vacated the final section of the route
                     if R.Path_Sections (R.Section_Count) = Vacated_Sec then
                        -- Entire route traversed; release remaining route locks
                        for Sw_Idx in 1 .. R.Switch_Count loop
                           Unlock_From_Route (Core.Net.Switches (R.Required_Switches (Sw_Idx).Switch));
                        end loop;
                        Unlock_Flank_Defenses (Core.Flank, Core.Net, Route_Id (I));
                        Transition_State (R, Route_Released, Succ);
                        Transition_State (R, Route_Unset, Succ);
                        R.Assigned_Train := Null_Train_Id;
                     end if;
                  end if;
               end if;
            end if;
         end;
      end loop;
   end Handle_Train_Movement;

   procedure Trigger_Emergency_Stop (Core : in out Interlocking_Core) is
   begin
      Core.Emergency_Stop_All := True;
      for I in 1 .. Core.Net.Signal_Count loop
         Drop_To_Danger (Core.Net.Signals (Signal_Id (I)));
      end loop;
   end Trigger_Emergency_Stop;

   procedure Reset_Emergency_Stop (Core : in out Interlocking_Core) is
   begin
      Core.Emergency_Stop_All := False;
   end Reset_Emergency_Stop;

   function Is_Route_Clear_For_Train
     (Core  : Interlocking_Core;
      Route : Route_Id) return Boolean
   is
   begin
      return Core.Routes (Route).State = Route_Cleared;
   end Is_Route_Clear_For_Train;

end Aspect.Interlocking.Engine;
