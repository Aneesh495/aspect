package body Aspect.Vital.Channels is

   procedure Initialize_Channels
     (Channels     : out Triplicated_Channels;
      Initial_Core : Interlocking_Core)
   is
   begin
      for C in Channel_Id loop
         Channels (C).Id                      := C;
         Channels (C).Health                  := Channel_Nominal;
         Channels (C).Consecutive_Divergences := 0;
         Channels (C).Lifetime_Divergences    := 0;
         Channels (C).Is_Isolated             := False;
         Channels (C).Core_State              := Initial_Core;
      end loop;
   end Initialize_Channels;

   procedure Record_Divergence
     (Channels    : in out Triplicated_Channels;
      Faulty_Chan : Channel_Id)
   is
      Desc : Channel_Descriptor renames Channels (Faulty_Chan);
   begin
      Desc.Consecutive_Divergences := Desc.Consecutive_Divergences + 1;
      Desc.Lifetime_Divergences    := Desc.Lifetime_Divergences + 1;

      if Desc.Consecutive_Divergences >= Max_Consecutive_Divergences then
         Desc.Health      := Channel_Faulted;
         Desc.Is_Isolated := True;
      else
         Desc.Health      := Channel_Diverged;
      end if;
   end Record_Divergence;

   procedure Record_Consensus
     (Channels : in out Triplicated_Channels;
      Chan     : Channel_Id)
   is
      Desc : Channel_Descriptor renames Channels (Chan);
   begin
      if not Desc.Is_Isolated then
         Desc.Consecutive_Divergences := 0;
         Desc.Health                  := Channel_Nominal;
      end if;
   end Record_Consensus;

   function Is_Channel_Usable
     (Channels : Triplicated_Channels;
      Chan     : Channel_Id) return Boolean
   is
   begin
      return (not Channels (Chan).Is_Isolated)
        and then (Channels (Chan).Health in Channel_Nominal | Channel_Diverged);
   end Is_Channel_Usable;

   function Active_Healthy_Count
     (Channels : Triplicated_Channels) return Natural
   is
      Count : Natural := 0;
   begin
      for C in Channel_Id loop
         if Is_Channel_Usable (Channels, C) then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Active_Healthy_Count;

   function Determine_Operational_Mode
     (Channels : Triplicated_Channels) return System_Operational_Mode
   is
      Active : constant Natural := Active_Healthy_Count (Channels);
   begin
      case Active is
         when 3 =>
            return Mode_Triplicated_3oo3;
         when 2 =>
            return Mode_Degraded_2oo2;
         when others =>
            return Mode_Tripped_Fail_Safe;
      end case;
   end Determine_Operational_Mode;

end Aspect.Vital.Channels;
