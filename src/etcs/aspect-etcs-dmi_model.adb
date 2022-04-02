package body Aspect.ETCS.DMI_Model is

   function Speed_To_Angle (Speed : Speed_Kph) return Float is
      S : constant Float := Float (Speed);
   begin
      if S <= 0.0 then
         return 0.0;
      elsif S >= 400.0 then
         return 300.0;
      else
         return (S / 400.0) * 300.0;
      end if;
   end Speed_To_Angle;

   function Distance_To_Bargraph (Dist : Distance_M) return Percent is
      D : constant Float := Float (Dist);
   begin
      if D <= 0.0 then
         return 0.0;
      elsif D >= 1000.0 then
         return 100.0;
      else
         return Percent ((D / 1000.0) * 100.0);
      end if;
   end Distance_To_Bargraph;

   procedure Update_DMI
     (DMI           : out DMI_State;
      Current_Speed : Speed_Kph;
      Envelope      : Supervision_Envelope;
      Level         : ETCS_Level := Level_2;
      Mode          : ETCS_Mode  := Mode_FS)
   is
   begin
      DMI.Current_Speed     := Current_Speed;
      DMI.Speedometer_Angle := Speed_To_Angle (Current_Speed);
      DMI.Permitted_Speed   := Envelope.Permitted_Speed;
      DMI.Permitted_Angle   := Speed_To_Angle (Envelope.Permitted_Speed);
      DMI.Target_Speed      := Envelope.Target_Speed;
      DMI.Target_Angle      := Speed_To_Angle (Envelope.Target_Speed);
      DMI.Release_Speed     := Envelope.Release_Speed;
      DMI.Distance_To_EoA   := Envelope.Distance_To_Target;
      DMI.Bargraph_Percent  := Distance_To_Bargraph (Envelope.Distance_To_Target);
      DMI.Level             := Level;
      DMI.Mode              := Mode;
      DMI.Supervision       := Envelope.Current_Status;

      case Envelope.Current_Status is
         when Status_Normal =>
            DMI.Needle_Color   := Color_Grey;
            DMI.Acoustic_Alarm := False;

         when Status_Indication =>
            DMI.Needle_Color   := Color_Yellow;
            DMI.Acoustic_Alarm := False;

         when Status_Overspeed_Warning =>
            DMI.Needle_Color   := Color_Yellow;
            DMI.Acoustic_Alarm := True;

         when Status_Service_Intervention =>
            DMI.Needle_Color   := Color_Orange;
            DMI.Acoustic_Alarm := True;

         when Status_Emergency_Trip =>
            DMI.Needle_Color   := Color_Red;
            DMI.Acoustic_Alarm := True;
      end case;
   end Update_DMI;

end Aspect.ETCS.DMI_Model;
