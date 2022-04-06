-- Bit-exact 2-out-of-3 (2oo3) majority voter and 2-out-of-2 (2oo2) consensus engine.
-- Arbitrates vital decisions across triplicated channels with Byzantine fault tolerance
-- and automated fail-safe state clamping.

with Aspect.Types; use Aspect.Types;
with Aspect.Vital.Channels; use Aspect.Vital.Channels;

package Aspect.Vital.Voter is

   type Voting_Outcome is record
      Verdict        : Voting_Verdict := Verdict_Tripped_Fail_Safe;
      Faulty_Channel : Channel_Id     := Channel_A;
      Has_Divergence : Boolean        := False;
   end record;

   -- Votes on Boolean digital signals (e.g. track occupancy relays, power cutoffs)
   procedure Vote_Boolean
     (Channels  : in out Triplicated_Channels;
      Val_A     : Boolean;
      Val_B     : Boolean;
      Val_C     : Boolean;
      Fail_Safe : Boolean;
      Voted_Val : out Boolean;
      Outcome   : out Voting_Outcome);

   -- Votes on lineside signal aspects (fail-safe default: Aspect_Stop)
   procedure Vote_Signal_Aspect
     (Channels  : in out Triplicated_Channels;
      Val_A     : Signal_Aspect;
      Val_B     : Signal_Aspect;
      Val_C     : Signal_Aspect;
      Voted_Val : out Signal_Aspect;
      Outcome   : out Voting_Outcome);

   -- Votes on point machine commands (fail-safe default: Command_None)
   procedure Vote_Switch_Command
     (Channels  : in out Triplicated_Channels;
      Val_A     : Switch_Command;
      Val_B     : Switch_Command;
      Val_C     : Switch_Command;
      Voted_Val : out Switch_Command;
      Outcome   : out Voting_Outcome);

   -- Votes on switch positions (fail-safe default: Switch_Lost_Detection)
   procedure Vote_Switch_Position
     (Channels  : in out Triplicated_Channels;
      Val_A     : Switch_Position;
      Val_B     : Switch_Position;
      Val_C     : Switch_Position;
      Voted_Val : out Switch_Position;
      Outcome   : out Voting_Outcome);

end Aspect.Vital.Voter;
