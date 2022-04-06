with Aspect.Vital.Voter; use Aspect.Vital.Voter;
with Aspect.Vital.Safety_Invariants; use Aspect.Vital.Safety_Invariants;

package body Aspect.Vital.Cyclic_Executive is

   procedure Initialize_Supervisor
     (Supervisor   : out Vital_Supervisor;
      Initial_Core : Interlocking_Core)
   is
   begin
      Initialize_Channels (Supervisor.Channels, Initial_Core);
      Supervisor.Metrics   := (others => <>);
      Supervisor.Is_Halted := False;
   end Initialize_Supervisor;

   procedure Dispatch_Command
     (Supervisor : in out Vital_Supervisor;
      Cmd        : Interlocking_Command)
   is
      Dummy_Succ : Boolean;
      Dummy_Reas : Rejection_Reason;
   begin
      for C in Channel_Id loop
         if Is_Channel_Usable (Supervisor.Channels, C) then
            Execute_Command
              (Supervisor.Channels (C).Core_State,
               Cmd,
               Dummy_Succ,
               Dummy_Reas);
         end if;
      end loop;
   end Dispatch_Command;

   procedure Execute_Minor_Cycle
     (Supervisor : in out Vital_Supervisor;
      Delta_Ms   : Positive := Minor_Cycle_Ms)
   is
   begin
      if Supervisor.Is_Halted then
         return;
      end if;

      Supervisor.Metrics.Total_Cycles_Executed :=
        Supervisor.Metrics.Total_Cycles_Executed + 1;

      -- 1. Step cycle across all active redundant channels
      for C in Channel_Id loop
         if Is_Channel_Usable (Supervisor.Channels, C) then
            Step_Cycle (Supervisor.Channels (C).Core_State, Delta_Ms);
         end if;
      end loop;

      -- 2. Vote on signal aspects across channels
      declare
         Sig_Count : constant Natural :=
           Supervisor.Channels (Channel_A).Core_State.Net.Signal_Count;
      begin
         for S in 1 .. Sig_Count loop
            declare
               Sig_Id    : constant Signal_Id := Signal_Id (S);
               Asp_A     : constant Signal_Aspect :=
                 Supervisor.Channels (Channel_A).Core_State.Net.Signals (Sig_Id).Current_Aspect;
               Asp_B     : constant Signal_Aspect :=
                 Supervisor.Channels (Channel_B).Core_State.Net.Signals (Sig_Id).Current_Aspect;
               Asp_C     : constant Signal_Aspect :=
                 Supervisor.Channels (Channel_C).Core_State.Net.Signals (Sig_Id).Current_Aspect;
               Voted_Asp : Signal_Aspect;
               Outcome   : Voting_Outcome;
            begin
               Vote_Signal_Aspect
                 (Supervisor.Channels, Asp_A, Asp_B, Asp_C, Voted_Asp, Outcome);

               if Outcome.Has_Divergence then
                  Supervisor.Metrics.Divergence_Events :=
                    Supervisor.Metrics.Divergence_Events + 1;
               end if;

               if Outcome.Verdict = Verdict_Tripped_Fail_Safe then
                  -- Disagreement on vital signal output: trip system immediately
                  Supervisor.Metrics.Tripped_Cycles :=
                    Supervisor.Metrics.Tripped_Cycles + 1;
                  for C in Channel_Id loop
                     Trigger_Emergency_Stop (Supervisor.Channels (C).Core_State);
                  end loop;
               else
                  -- Apply consensus aspect to all active channels
                  for C in Channel_Id loop
                     if Is_Channel_Usable (Supervisor.Channels, C) then
                        Supervisor.Channels (C).Core_State.Net.Signals (Sig_Id).Current_Aspect :=
                          Voted_Asp;
                     end if;
                  end loop;
               end if;
            end;
         end loop;
      end;

      -- 3. Execute independent formal safety invariant audit
      declare
         Voted_State : constant Interlocking_Core := Get_Voted_Core (Supervisor);
         Audit_Res   : constant Invariant_Check_Result :=
           Audit_Safety_Invariants (Voted_State);
      begin
         Supervisor.Metrics.Last_Invariant_Passed := Audit_Res.Passed;
         if not Audit_Res.Passed then
            -- Safety barrier tripped! Clamp all channels to danger
            Supervisor.Metrics.Tripped_Cycles := Supervisor.Metrics.Tripped_Cycles + 1;
            for C in Channel_Id loop
               Trigger_Emergency_Stop (Supervisor.Channels (C).Core_State);
            end loop;
         end if;
      end;
   end Execute_Minor_Cycle;

   function Get_Voted_Core
     (Supervisor : Vital_Supervisor) return Interlocking_Core
   is
   begin
      -- Return state from first healthy usable channel
      for C in Channel_Id loop
         if Is_Channel_Usable (Supervisor.Channels, C) then
            return Supervisor.Channels (C).Core_State;
         end if;
      end loop;
      return Supervisor.Channels (Channel_A).Core_State;
   end Get_Voted_Core;

end Aspect.Vital.Cyclic_Executive;
