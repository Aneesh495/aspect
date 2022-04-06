-- Triplicated computation channels for EN 50128 SIL 4 fault isolation.
-- Tracks independent channel execution health, consecutive discrepancy counts,
-- and automated hardware isolation triggers.

with Aspect.Types; use Aspect.Types;
with Aspect.Interlocking.Engine; use Aspect.Interlocking.Engine;

package Aspect.Vital.Channels is

   type Channel_Descriptor is record
      Id                      : Channel_Id              := Channel_A;
      Health                  : Channel_Health          := Channel_Nominal;
      Consecutive_Divergences : Natural                 := 0;
      Lifetime_Divergences    : Natural                 := 0;
      Is_Isolated             : Boolean                 := False;
      Core_State              : Interlocking_Core;
   end record;

   type Triplicated_Channels is array (Channel_Id) of Channel_Descriptor;

   procedure Initialize_Channels
     (Channels : out Triplicated_Channels;
      Initial_Core : Interlocking_Core);

   procedure Record_Divergence
     (Channels   : in out Triplicated_Channels;
      Faulty_Chan: Channel_Id);

   procedure Record_Consensus
     (Channels   : in out Triplicated_Channels;
      Chan       : Channel_Id);

   function Is_Channel_Usable
     (Channels : Triplicated_Channels;
      Chan     : Channel_Id) return Boolean;

   function Active_Healthy_Count
     (Channels : Triplicated_Channels) return Natural;

   function Determine_Operational_Mode
     (Channels : Triplicated_Channels) return System_Operational_Mode;

end Aspect.Vital.Channels;
