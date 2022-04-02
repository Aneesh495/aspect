-- Movement Authority (MA) lifecycle and on-board target supervision.
-- Manages EoA progression, dynamic extensions from Radio Block Centre,
-- and emergency authority revocations.

with Aspect.Topology; use Aspect.Topology;
with Aspect.ETCS.Packets; use Aspect.ETCS.Packets;

package Aspect.ETCS.Movement_Authority is

   type Authority_Status is (
      MA_Valid,
      MA_Approaching_EoA,
      MA_Expired,
      MA_Emergency_Shortened,
      MA_Overrun_Tripped
   );

   type Active_Authority is record
      Packet_Data        : Packet_12_Movement_Authority;
      Gradient_Data      : Packet_21_Gradient_Profile;
      Speed_Data         : Packet_27_Static_Speed_Profile;

      -- On-Board Position Tracking
      Current_Chainage   : Track_Chainage  := 0.0;
      EoA_Chainage       : Track_Chainage  := 0.0;
      SvL_Chainage       : Track_Chainage  := 0.0;
      Remaining_EoA_M    : Distance_M      := 0.0;
      Remaining_SvL_M    : Distance_M      := 0.0;

      Status             : Authority_Status := MA_Valid;
      Time_Remaining_S   : Positive         := 300;
   end record;

   procedure Initialize_Authority
     (Auth     : out Active_Authority;
      P12      : Packet_12_Movement_Authority;
      P21      : Packet_21_Gradient_Profile;
      P27      : Packet_27_Static_Speed_Profile;
      Start_Km : Track_Chainage);

   -- Updates train chainage and recalculates remaining distances
   procedure Update_Position
     (Auth           : in out Active_Authority;
      New_Chainage   : Track_Chainage;
      Current_Speed  : Speed_Kph);

   -- Dynamic extension: called when RBC grants additional block sections ahead
   procedure Extend_Authority
     (Auth           : in out Active_Authority;
      New_P12        : Packet_12_Movement_Authority);

   -- Emergency revocation by RBC (forced stop order)
   procedure Revoke_Authority (Auth : in out Active_Authority);

   -- Decrements validity timeout watchdog
   procedure Update_Watchdog
     (Auth     : in out Active_Authority;
      Delta_S  : Positive);

end Aspect.ETCS.Movement_Authority;
