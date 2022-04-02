-- Driver Machine Interface (DMI) model conforming to ERA-ERTMS-015560.
-- Computes circular speedometer needle coordinates, color-coded supervision arcs,
-- target speed hooks, logarithmic distance-to-target bargraphs, and mode indications.

with Aspect.ETCS.Braking_Curves; use Aspect.ETCS.Braking_Curves;

package Aspect.ETCS.DMI_Model is

   type Gauge_Color is (
      Color_Grey,      -- Normal operation within permitted authority
      Color_White,     -- Target indications
      Color_Yellow,    -- Warning speed exceeded; driver intervention requested
      Color_Orange,    -- Service brake commanded automatically
      Color_Red        -- Emergency brake trip active
   );

   type DMI_State is record
      Current_Speed       : Speed_Kph         := 0.0;
      Speedometer_Angle   : Float             := 0.0; -- Degrees (0.0 to 300.0)
      Needle_Color        : Gauge_Color       := Color_Grey;

      -- Speed Hooks
      Permitted_Speed     : Speed_Kph         := 160.0;
      Permitted_Angle     : Float             := 0.0;
      Target_Speed        : Speed_Kph         := 0.0;
      Target_Angle        : Float             := 0.0;
      Release_Speed       : Speed_Kph         := 25.0;

      -- Distance to Target Bargraph
      Distance_To_EoA     : Distance_M        := 0.0;
      Bargraph_Percent    : Percent           := 100.0;

      -- System State
      Level               : ETCS_Level        := Level_2;
      Mode                : ETCS_Mode         := Mode_FS;
      Supervision         : Supervision_State := Status_Normal;
      Acoustic_Alarm      : Boolean           := False;
   end record;

   procedure Update_DMI
     (DMI           : out DMI_State;
      Current_Speed : Speed_Kph;
      Envelope      : Supervision_Envelope;
      Level         : ETCS_Level := Level_2;
      Mode          : ETCS_Mode  := Mode_FS);

   function Speed_To_Angle (Speed : Speed_Kph) return Float;

   function Distance_To_Bargraph (Dist : Distance_M) return Percent;

end Aspect.ETCS.DMI_Model;
