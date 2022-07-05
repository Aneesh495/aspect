-- Implementation of 2oo3 TMR Byzantine fault tolerance property test.

with Aspect.Types; use Aspect.Types;
with Aspect.Topology.Network; use Aspect.Topology.Network;
with Aspect.Interlocking.Engine; use Aspect.Interlocking.Engine;
with Aspect.Vital; use Aspect.Vital;
with Aspect.Vital.Channels; use Aspect.Vital.Channels;
with Aspect.Vital.Voter; use Aspect.Vital.Voter;

package body Aspect.Formal.TMR_Byzantine is

   procedure Verify_TMR_Byzantine_Property (Ctx : in out Test_Context) is
      Net       : Railway_Network;
      Core      : Interlocking_Core;
      Channels  : Triplicated_Channels;
      Outcome   : Voting_Outcome;
      Voted_Asp : Signal_Aspect;
      Voted_Bool: Boolean;
   begin
      Initialize_Network (Net);
      Initialize_Core (Core, Net);
      Initialize_Channels (Channels, Core);

      -- 1. Initial State: All 3 channels nominal and participating in 3oo3
      Assert (Ctx, Determine_Operational_Mode (Channels) = Mode_Triplicated_3oo3,
              "Initial 2oo3 executive operates in Mode_Triplicated_3oo3");
      Assert (Ctx, Active_Healthy_Count (Channels) = 3, "All 3 channels initially healthy");

      -- 2. Byzantine Fault Injection: Channel A corrupted to Aspect_Clear while B & C command Aspect_Stop
      Vote_Signal_Aspect
        (Channels  => Channels,
         Val_A     => Aspect_Clear,  -- Fault injected!
         Val_B     => Aspect_Stop,
         Val_C     => Aspect_Stop,
         Voted_Val => Voted_Asp,
         Outcome   => Outcome);

      Assert (Ctx, Voted_Asp = Aspect_Stop,
              "Majority 2oo3 voter correctly masked Byzantine fault on Channel A (Voted: Stop)");
      Assert (Ctx, Outcome.Verdict = Verdict_Majority_2oo3,
              "Voting outcome correctly identifies 2oo3 majority consensus");
      Assert (Ctx, Outcome.Faulty_Channel = Channel_A,
              "Faulty channel identified as Channel A");

      Assert (Ctx, Channels (Channel_A).Consecutive_Divergences = 1,
              "Channel A consecutive divergence counter incremented to 1");

      -- 3. Inject second consecutive divergence on Channel A
      Vote_Signal_Aspect
        (Channels  => Channels,
         Val_A     => Aspect_Clear,
         Val_B     => Aspect_Stop,
         Val_C     => Aspect_Stop,
         Voted_Val => Voted_Asp,
         Outcome   => Outcome);

      Assert (Ctx, Channels (Channel_A).Consecutive_Divergences = 2,
              "Channel A consecutive divergence counter incremented to 2");
      Assert (Ctx, not Channels (Channel_A).Is_Isolated,
              "Channel A not yet permanently isolated (threshold = 3)");

      -- 4. Inject third consecutive divergence on Channel A: triggers permanent isolation
      Vote_Signal_Aspect
        (Channels  => Channels,
         Val_A     => Aspect_Clear,
         Val_B     => Aspect_Stop,
         Val_C     => Aspect_Stop,
         Voted_Val => Voted_Asp,
         Outcome   => Outcome);

      Assert (Ctx, Channels (Channel_A).Is_Isolated,
              "Channel A permanently isolated after 3 consecutive Byzantine divergences");
      Assert (Ctx, Determine_Operational_Mode (Channels) = Mode_Degraded_2oo2,
              "Executive transitioned to Mode_Degraded_2oo2");
      Assert (Ctx, Active_Healthy_Count (Channels) = 2, "Exactly 2 healthy channels remain");

      -- 5. Test 2oo2 Degraded Mode Consensus
      Vote_Signal_Aspect
        (Channels  => Channels,
         Val_A     => Aspect_Clear,  -- Ignored because Channel A is isolated
         Val_B     => Aspect_Caution,
         Val_C     => Aspect_Caution,
         Voted_Val => Voted_Asp,
         Outcome   => Outcome);

      Assert (Ctx, Voted_Asp = Aspect_Caution,
              "2oo2 mode reached consensus on remaining healthy channels B & C");
      Assert (Ctx, Outcome.Verdict = Verdict_Degraded_2oo2,
              "Outcome verdict is Verdict_Degraded_2oo2");

      -- 6. Total Consensus Loss: Channel B and C disagree in 2oo2 mode
      -- Must immediately trigger fail-safe clamping to Aspect_Stop!
      Vote_Boolean
        (Channels  => Channels,
         Val_A     => True,  -- Isolated
         Val_B     => True,  -- Disagreement!
         Val_C     => False,
         Fail_Safe => False,
         Voted_Val => Voted_Bool,
         Outcome   => Outcome);

      Assert (Ctx, not Voted_Bool,
              "2oo2 consensus loss immediately clamps to safe state (False)");
      Assert (Ctx, Outcome.Verdict = Verdict_Tripped_Fail_Safe,
              "Outcome verdict clamped to Verdict_Tripped_Fail_Safe");

   end Verify_TMR_Byzantine_Property;

end Aspect.Formal.TMR_Byzantine;
