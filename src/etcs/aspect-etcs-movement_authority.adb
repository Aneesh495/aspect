package body Aspect.ETCS.Movement_Authority is

   procedure Initialize_Authority
     (Auth     : out Active_Authority;
      P12      : Packet_12_Movement_Authority;
      P21      : Packet_21_Gradient_Profile;
      P27      : Packet_27_Static_Speed_Profile;
      Start_Km : Track_Chainage)
   is
   begin
      Auth.Packet_Data      := P12;
      Auth.Gradient_Data    := P21;
      Auth.Speed_Data       := P27;
      Auth.Current_Chainage := Start_Km;
      Auth.EoA_Chainage     := Start_Km + Track_Chainage (P12.Distance_To_EoA);
      Auth.SvL_Chainage     := Start_Km + Track_Chainage (P12.Distance_To_SvL);
      Auth.Remaining_EoA_M  := P12.Distance_To_EoA;
      Auth.Remaining_SvL_M  := P12.Distance_To_SvL;
      Auth.Status           := MA_Valid;
      Auth.Time_Remaining_S := P12.Timeout_Seconds;
   end Initialize_Authority;

   procedure Update_Position
     (Auth          : in out Active_Authority;
      New_Chainage  : Track_Chainage;
      Current_Speed : Speed_Kph)
   is
      pragma Unreferenced (Current_Speed);
   begin
      Auth.Current_Chainage := New_Chainage;

      -- Check overrun beyond Supervised Location (SvL)
      if New_Chainage > Auth.SvL_Chainage then
         Auth.Remaining_EoA_M := 0.0;
         Auth.Remaining_SvL_M := 0.0;
         Auth.Status          := MA_Overrun_Tripped;
         return;
      end if;

      -- Check overrun beyond End of Authority (EoA)
      if New_Chainage > Auth.EoA_Chainage then
         Auth.Remaining_EoA_M := 0.0;
         Auth.Remaining_SvL_M := Distance_M (Float (Auth.SvL_Chainage - New_Chainage));
         Auth.Status          := MA_Overrun_Tripped;
         return;
      end if;

      -- Normal advance within authority limits
      Auth.Remaining_EoA_M := Distance_M (Float (Auth.EoA_Chainage - New_Chainage));
      Auth.Remaining_SvL_M := Distance_M (Float (Auth.SvL_Chainage - New_Chainage));

      if Auth.Remaining_EoA_M < 500.0 then
         Auth.Status := MA_Approaching_EoA;
      else
         Auth.Status := MA_Valid;
      end if;
   end Update_Position;

   procedure Extend_Authority
     (Auth    : in out Active_Authority;
      New_P12 : Packet_12_Movement_Authority)
   is
   begin
      Auth.Packet_Data      := New_P12;
      Auth.EoA_Chainage     := Auth.Current_Chainage + Track_Chainage (New_P12.Distance_To_EoA);
      Auth.SvL_Chainage     := Auth.Current_Chainage + Track_Chainage (New_P12.Distance_To_SvL);
      Auth.Remaining_EoA_M  := New_P12.Distance_To_EoA;
      Auth.Remaining_SvL_M  := New_P12.Distance_To_SvL;
      Auth.Status           := MA_Valid;
      Auth.Time_Remaining_S := New_P12.Timeout_Seconds;
   end Extend_Authority;

   procedure Revoke_Authority (Auth : in out Active_Authority) is
   begin
      -- Forced stop order: clamp EoA to current location
      Auth.EoA_Chainage    := Auth.Current_Chainage;
      Auth.SvL_Chainage    := Auth.Current_Chainage + 50.0; -- Minimum residual overlap
      Auth.Remaining_EoA_M := 0.0;
      Auth.Remaining_SvL_M := 50.0;
      Auth.Status          := MA_Emergency_Shortened;
   end Revoke_Authority;

   procedure Update_Watchdog
     (Auth    : in out Active_Authority;
      Delta_S : Positive)
   is
   begin
      if Auth.Time_Remaining_S <= Delta_S then
         Auth.Time_Remaining_S := 1;
         Auth.Status           := MA_Expired;
      else
         Auth.Time_Remaining_S := Auth.Time_Remaining_S - Delta_S;
      end if;
   end Update_Watchdog;

end Aspect.ETCS.Movement_Authority;
