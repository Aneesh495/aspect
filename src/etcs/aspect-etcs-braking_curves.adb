with Aspect.Math; use Aspect.Math;

package body Aspect.ETCS.Braking_Curves is

   procedure Calculate_Envelopes
     (Params          : Train_Brake_Parameters;
      Current_Speed   : Speed_Kph;
      Distance_To_EoA : Distance_M;
      Distance_To_SvL : Distance_M;
      Target_Speed    : Speed_Kph;
      Ceiling_Speed   : Speed_Kph;
      Envelope        : out Supervision_Envelope)
   is
      A_Emerg_Eff : constant Deceleration_Mps2 := Composite_Deceleration
        (Params.Nominal_Emergency_A, Params.Gradient, Params.Adhesion, Params.Rotating_Mass);

      A_Serv_Eff  : constant Deceleration_Mps2 := Composite_Deceleration
        (Params.Nominal_Service_A, Params.Gradient, Params.Adhesion, Params.Rotating_Mass);

      V_Tgt_Mps   : constant Speed_Mps := Kph_To_Mps (Target_Speed);
      Ceil_Mps    : constant Speed_Mps := Kph_To_Mps (Ceiling_Speed);
      Rel_Mps     : constant Speed_Mps := Kph_To_Mps (Envelope.Release_Speed);

      -- Safe kinematic speeds from EoA and SvL distances
      V_Raw_Ebi_Mps : Speed_Mps;
      V_Raw_Sbi_Mps : Speed_Mps;

      V_Ebi_Mps : Speed_Mps;
      V_Sbi_Mps : Speed_Mps;
      V_Warn_Mps: Speed_Mps;
      V_Perm_Mps: Speed_Mps;
      V_Ind_Mps : Speed_Mps;
   begin
      Envelope.Distance_To_Target := Distance_To_EoA;
      Envelope.Target_Speed       := Target_Speed;
      Envelope.Ceiling_Speed      := Ceiling_Speed;
      Envelope.Release_Speed      := 25.0;

      -- 1. EBI curve: Calculated from Supervised Location (SvL) with emergency lag
      V_Raw_Ebi_Mps := Safe_Speed_At_Distance (V_Tgt_Mps, Distance_To_SvL, A_Emerg_Eff);
      declare
         Ebi_Minus_Lag : constant Float :=
           Float (V_Raw_Ebi_Mps) - (Float (A_Emerg_Eff) * Params.Emergency_Lag_S);
      begin
         if Ebi_Minus_Lag < Float (V_Tgt_Mps) then
            V_Ebi_Mps := V_Tgt_Mps;
         elsif Ebi_Minus_Lag > Float (Ceil_Mps) + 5.0 then
            V_Ebi_Mps := Speed_Mps (Float (Ceil_Mps) + 5.0);
         else
            V_Ebi_Mps := Speed_Mps (Ebi_Minus_Lag);
         end if;
      end;

      -- 2. SBI curve: Calculated from End of Authority (EoA) with service brake lag
      V_Raw_Sbi_Mps := Safe_Speed_At_Distance (V_Tgt_Mps, Distance_To_EoA, A_Serv_Eff);
      declare
         Sbi_Minus_Lag : constant Float :=
           Float (V_Raw_Sbi_Mps) - (Float (A_Serv_Eff) * Params.Service_Lag_S);
      begin
         if Sbi_Minus_Lag < Float (V_Tgt_Mps) then
            V_Sbi_Mps := V_Tgt_Mps;
         elsif Sbi_Minus_Lag > Float (Ceil_Mps) + 2.0 then
            V_Sbi_Mps := Speed_Mps (Float (Ceil_Mps) + 2.0);
         else
            V_Sbi_Mps := Speed_Mps (Sbi_Minus_Lag);
         end if;
      end;

      -- 3. Warning curve (W): acoustic alert ahead of automated service intervention
      declare
         Warn_Float : constant Float :=
           Float (V_Sbi_Mps) - (Float (A_Serv_Eff) * Params.Warning_Time_S);
      begin
         if Warn_Float < Float (V_Tgt_Mps) then
            V_Warn_Mps := V_Tgt_Mps;
         elsif Warn_Float > Float (Ceil_Mps) then
            V_Warn_Mps := Ceil_Mps;
         else
            V_Warn_Mps := Speed_Mps (Warn_Float);
         end if;
      end;

      -- 4. Permitted speed curve (P): maximum driver commanded authority
      -- Offset below warning speed; floored by release speed near EoA
      declare
         Perm_Float : Float := Float (V_Warn_Mps) - 1.0;
      begin
         -- Release speed floor allows train to complete platform berth stop
         if Target_Speed = 0.0 and then Distance_To_EoA < 200.0 then
            if Perm_Float < Float (Rel_Mps) then
               Perm_Float := Float (Rel_Mps);
            end if;
         end if;

         if Perm_Float < 0.0 then
            V_Perm_Mps := 0.0;
         elsif Perm_Float > Float (Ceil_Mps) then
            V_Perm_Mps := Ceil_Mps;
         else
            V_Perm_Mps := Speed_Mps (Perm_Float);
         end if;
      end;

      -- 5. Indication curve (I): visual display cue indicating braking point ahead
      declare
         Ind_Float : constant Float :=
           Float (V_Perm_Mps) - (Float (A_Serv_Eff) * Params.Driver_Reaction_S);
      begin
         if Ind_Float < Float (V_Tgt_Mps) then
            V_Ind_Mps := V_Tgt_Mps;
         elsif Ind_Float > Float (Ceil_Mps) then
            V_Ind_Mps := Ceil_Mps;
         else
            V_Ind_Mps := Speed_Mps (Ind_Float);
         end if;
      end;

      Envelope.EBI_Speed        := Mps_To_Kph (V_Ebi_Mps);
      Envelope.SBI_Speed        := Mps_To_Kph (V_Sbi_Mps);
      Envelope.Warning_Speed    := Mps_To_Kph (V_Warn_Mps);
      Envelope.Permitted_Speed  := Mps_To_Kph (V_Perm_Mps);
      Envelope.Indication_Speed := Mps_To_Kph (V_Ind_Mps);

      Envelope.Current_Status   := Evaluate_State (Current_Speed, Envelope);
   end Calculate_Envelopes;

   function Evaluate_State
     (Current_Speed : Speed_Kph;
      Envelope      : Supervision_Envelope) return Supervision_State
   is
   begin
      if Current_Speed >= Envelope.EBI_Speed then
         return Status_Emergency_Trip;
      elsif Current_Speed >= Envelope.SBI_Speed then
         return Status_Service_Intervention;
      elsif Current_Speed >= Envelope.Warning_Speed then
         return Status_Overspeed_Warning;
      elsif Current_Speed >= Envelope.Indication_Speed then
         return Status_Indication;
      else
         return Status_Normal;
      end if;
   end Evaluate_State;

end Aspect.ETCS.Braking_Curves;
