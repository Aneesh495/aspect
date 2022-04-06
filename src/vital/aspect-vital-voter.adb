package body Aspect.Vital.Voter is

   procedure Vote_Boolean
     (Channels  : in out Triplicated_Channels;
      Val_A     : Boolean;
      Val_B     : Boolean;
      Val_C     : Boolean;
      Fail_Safe : Boolean;
      Voted_Val : out Boolean;
      Outcome   : out Voting_Outcome)
   is
      Mode : constant System_Operational_Mode := Determine_Operational_Mode (Channels);
   begin
      Outcome.Has_Divergence := False;

      case Mode is
         when Mode_Triplicated_3oo3 =>
            if Val_A = Val_B and then Val_B = Val_C then
               Voted_Val := Val_A;
               Outcome.Verdict := Verdict_Unanimous_3oo3;
               Record_Consensus (Channels, Channel_A);
               Record_Consensus (Channels, Channel_B);
               Record_Consensus (Channels, Channel_C);
            elsif Val_A = Val_B then
               Voted_Val := Val_A;
               Outcome.Verdict        := Verdict_Majority_2oo3;
               Outcome.Faulty_Channel := Channel_C;
               Outcome.Has_Divergence := True;
               Record_Consensus (Channels, Channel_A);
               Record_Consensus (Channels, Channel_B);
               Record_Divergence (Channels, Channel_C);
            elsif Val_A = Val_C then
               Voted_Val := Val_A;
               Outcome.Verdict        := Verdict_Majority_2oo3;
               Outcome.Faulty_Channel := Channel_B;
               Outcome.Has_Divergence := True;
               Record_Consensus (Channels, Channel_A);
               Record_Consensus (Channels, Channel_C);
               Record_Divergence (Channels, Channel_B);
            elsif Val_B = Val_C then
               Voted_Val := Val_B;
               Outcome.Verdict        := Verdict_Majority_2oo3;
               Outcome.Faulty_Channel := Channel_A;
               Outcome.Has_Divergence := True;
               Record_Consensus (Channels, Channel_B);
               Record_Consensus (Channels, Channel_C);
               Record_Divergence (Channels, Channel_A);
            else
               -- Complete Byzantine breakdown; clamp to safe state
               Voted_Val       := Fail_Safe;
               Outcome.Verdict := Verdict_Tripped_Fail_Safe;
            end if;

         when Mode_Degraded_2oo2 =>
            -- Identify the two usable channels
            if not Is_Channel_Usable (Channels, Channel_A) then
               if Val_B = Val_C then
                  Voted_Val := Val_B;
                  Outcome.Verdict := Verdict_Degraded_2oo2;
                  Record_Consensus (Channels, Channel_B);
                  Record_Consensus (Channels, Channel_C);
               else
                  Voted_Val       := Fail_Safe;
                  Outcome.Verdict := Verdict_Tripped_Fail_Safe;
               end if;
            elsif not Is_Channel_Usable (Channels, Channel_B) then
               if Val_A = Val_C then
                  Voted_Val := Val_A;
                  Outcome.Verdict := Verdict_Degraded_2oo2;
                  Record_Consensus (Channels, Channel_A);
                  Record_Consensus (Channels, Channel_C);
               else
                  Voted_Val       := Fail_Safe;
                  Outcome.Verdict := Verdict_Tripped_Fail_Safe;
               end if;
            else
               if Val_A = Val_B then
                  Voted_Val := Val_A;
                  Outcome.Verdict := Verdict_Degraded_2oo2;
                  Record_Consensus (Channels, Channel_A);
                  Record_Consensus (Channels, Channel_B);
               else
                  Voted_Val       := Fail_Safe;
                  Outcome.Verdict := Verdict_Tripped_Fail_Safe;
               end if;
            end if;

         when Mode_Tripped_Fail_Safe =>
            Voted_Val       := Fail_Safe;
            Outcome.Verdict := Verdict_Tripped_Fail_Safe;
      end case;
   end Vote_Boolean;

   procedure Vote_Signal_Aspect
     (Channels  : in out Triplicated_Channels;
      Val_A     : Signal_Aspect;
      Val_B     : Signal_Aspect;
      Val_C     : Signal_Aspect;
      Voted_Val : out Signal_Aspect;
      Outcome   : out Voting_Outcome)
   is
      Mode : constant System_Operational_Mode := Determine_Operational_Mode (Channels);
   begin
      Outcome.Has_Divergence := False;

      case Mode is
         when Mode_Triplicated_3oo3 =>
            if Val_A = Val_B and then Val_B = Val_C then
               Voted_Val := Val_A;
               Outcome.Verdict := Verdict_Unanimous_3oo3;
               Record_Consensus (Channels, Channel_A);
               Record_Consensus (Channels, Channel_B);
               Record_Consensus (Channels, Channel_C);
            elsif Val_A = Val_B then
               Voted_Val := Val_A;
               Outcome.Verdict        := Verdict_Majority_2oo3;
               Outcome.Faulty_Channel := Channel_C;
               Outcome.Has_Divergence := True;
               Record_Consensus (Channels, Channel_A);
               Record_Consensus (Channels, Channel_B);
               Record_Divergence (Channels, Channel_C);
            elsif Val_A = Val_C then
               Voted_Val := Val_A;
               Outcome.Verdict        := Verdict_Majority_2oo3;
               Outcome.Faulty_Channel := Channel_B;
               Outcome.Has_Divergence := True;
               Record_Consensus (Channels, Channel_A);
               Record_Consensus (Channels, Channel_C);
               Record_Divergence (Channels, Channel_B);
            elsif Val_B = Val_C then
               Voted_Val := Val_B;
               Outcome.Verdict        := Verdict_Majority_2oo3;
               Outcome.Faulty_Channel := Channel_A;
               Outcome.Has_Divergence := True;
               Record_Consensus (Channels, Channel_B);
               Record_Consensus (Channels, Channel_C);
               Record_Divergence (Channels, Channel_A);
            else
               -- Disagreement: fail safe to Red (Stop)
               Voted_Val       := Aspect_Stop;
               Outcome.Verdict := Verdict_Tripped_Fail_Safe;
            end if;

         when Mode_Degraded_2oo2 =>
            if not Is_Channel_Usable (Channels, Channel_A) then
               if Val_B = Val_C then
                  Voted_Val := Val_B;
                  Outcome.Verdict := Verdict_Degraded_2oo2;
                  Record_Consensus (Channels, Channel_B);
                  Record_Consensus (Channels, Channel_C);
               else
                  Voted_Val       := Aspect_Stop;
                  Outcome.Verdict := Verdict_Tripped_Fail_Safe;
               end if;
            elsif not Is_Channel_Usable (Channels, Channel_B) then
               if Val_A = Val_C then
                  Voted_Val := Val_A;
                  Outcome.Verdict := Verdict_Degraded_2oo2;
                  Record_Consensus (Channels, Channel_A);
                  Record_Consensus (Channels, Channel_C);
               else
                  Voted_Val       := Aspect_Stop;
                  Outcome.Verdict := Verdict_Tripped_Fail_Safe;
               end if;
            else
               if Val_A = Val_B then
                  Voted_Val := Val_A;
                  Outcome.Verdict := Verdict_Degraded_2oo2;
                  Record_Consensus (Channels, Channel_A);
                  Record_Consensus (Channels, Channel_B);
               else
                  Voted_Val       := Aspect_Stop;
                  Outcome.Verdict := Verdict_Tripped_Fail_Safe;
               end if;
            end if;

         when Mode_Tripped_Fail_Safe =>
            Voted_Val       := Aspect_Stop;
            Outcome.Verdict := Verdict_Tripped_Fail_Safe;
      end case;
   end Vote_Signal_Aspect;

   procedure Vote_Switch_Command
     (Channels  : in out Triplicated_Channels;
      Val_A     : Switch_Command;
      Val_B     : Switch_Command;
      Val_C     : Switch_Command;
      Voted_Val : out Switch_Command;
      Outcome   : out Voting_Outcome)
   is
      Mode : constant System_Operational_Mode := Determine_Operational_Mode (Channels);
   begin
      Outcome.Has_Divergence := False;

      case Mode is
         when Mode_Triplicated_3oo3 =>
            if Val_A = Val_B and then Val_B = Val_C then
               Voted_Val := Val_A;
               Outcome.Verdict := Verdict_Unanimous_3oo3;
            elsif Val_A = Val_B then
               Voted_Val := Val_A;
               Outcome.Verdict        := Verdict_Majority_2oo3;
               Outcome.Faulty_Channel := Channel_C;
               Outcome.Has_Divergence := True;
               Record_Divergence (Channels, Channel_C);
            elsif Val_A = Val_C then
               Voted_Val := Val_A;
               Outcome.Verdict        := Verdict_Majority_2oo3;
               Outcome.Faulty_Channel := Channel_B;
               Outcome.Has_Divergence := True;
               Record_Divergence (Channels, Channel_B);
            elsif Val_B = Val_C then
               Voted_Val := Val_B;
               Outcome.Verdict        := Verdict_Majority_2oo3;
               Outcome.Faulty_Channel := Channel_A;
               Outcome.Has_Divergence := True;
               Record_Divergence (Channels, Channel_A);
            else
               Voted_Val       := Command_None;
               Outcome.Verdict := Verdict_Tripped_Fail_Safe;
            end if;

         when Mode_Degraded_2oo2 =>
            if not Is_Channel_Usable (Channels, Channel_A) then
               Voted_Val := (if Val_B = Val_C then Val_B else Command_None);
            elsif not Is_Channel_Usable (Channels, Channel_B) then
               Voted_Val := (if Val_A = Val_C then Val_A else Command_None);
            else
               Voted_Val := (if Val_A = Val_B then Val_A else Command_None);
            end if;
            Outcome.Verdict := (if Voted_Val = Command_None then Verdict_Tripped_Fail_Safe
                                else Verdict_Degraded_2oo2);

         when Mode_Tripped_Fail_Safe =>
            Voted_Val       := Command_None;
            Outcome.Verdict := Verdict_Tripped_Fail_Safe;
      end case;
   end Vote_Switch_Command;

   procedure Vote_Switch_Position
     (Channels  : in out Triplicated_Channels;
      Val_A     : Switch_Position;
      Val_B     : Switch_Position;
      Val_C     : Switch_Position;
      Voted_Val : out Switch_Position;
      Outcome   : out Voting_Outcome)
   is
      Mode : constant System_Operational_Mode := Determine_Operational_Mode (Channels);
   begin
      Outcome.Has_Divergence := False;

      case Mode is
         when Mode_Triplicated_3oo3 =>
            if Val_A = Val_B and then Val_B = Val_C then
               Voted_Val := Val_A;
               Outcome.Verdict := Verdict_Unanimous_3oo3;
            elsif Val_A = Val_B then
               Voted_Val := Val_A;
               Outcome.Verdict        := Verdict_Majority_2oo3;
               Outcome.Faulty_Channel := Channel_C;
               Outcome.Has_Divergence := True;
               Record_Divergence (Channels, Channel_C);
            elsif Val_A = Val_C then
               Voted_Val := Val_A;
               Outcome.Verdict        := Verdict_Majority_2oo3;
               Outcome.Faulty_Channel := Channel_B;
               Outcome.Has_Divergence := True;
               Record_Divergence (Channels, Channel_B);
            elsif Val_B = Val_C then
               Voted_Val := Val_B;
               Outcome.Verdict        := Verdict_Majority_2oo3;
               Outcome.Faulty_Channel := Channel_A;
               Outcome.Has_Divergence := True;
               Record_Divergence (Channels, Channel_A);
            else
               Voted_Val       := Switch_Lost_Detection;
               Outcome.Verdict := Verdict_Tripped_Fail_Safe;
            end if;

         when Mode_Degraded_2oo2 =>
            if not Is_Channel_Usable (Channels, Channel_A) then
               Voted_Val := (if Val_B = Val_C then Val_B else Switch_Lost_Detection);
            elsif not Is_Channel_Usable (Channels, Channel_B) then
               Voted_Val := (if Val_A = Val_C then Val_A else Switch_Lost_Detection);
            else
               Voted_Val := (if Val_A = Val_B then Val_A else Switch_Lost_Detection);
            end if;
            Outcome.Verdict := (if Voted_Val = Switch_Lost_Detection then Verdict_Tripped_Fail_Safe
                                else Verdict_Degraded_2oo2);

         when Mode_Tripped_Fail_Safe =>
            Voted_Val       := Switch_Lost_Detection;
            Outcome.Verdict := Verdict_Tripped_Fail_Safe;
      end case;
   end Vote_Switch_Position;

end Aspect.Vital.Voter;
