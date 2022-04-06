package body Aspect.Vital.FDIR is

   procedure Initialize_FDIR (FDIR : out FDIR_Supervisor) is
   begin
      FDIR.Logs           := [others => <>];
      FDIR.Log_Count      := 0;
      FDIR.Isolation_Mask := 0;
   end Initialize_FDIR;

   procedure Handle_Channel_Discrepancy
     (FDIR     : in out FDIR_Supervisor;
      Channels : in out Triplicated_Channels;
      Faulty   : Channel_Id;
      Time_Ms  : Natural)
   is
      Sev : Diagnostic_Severity := Severity_Transient_Fault;
   begin
      Record_Divergence (Channels, Faulty);

      if not Is_Channel_Usable (Channels, Faulty) then
         Sev := Severity_Channel_Isolated;
      end if;

      if FDIR.Log_Count < 64 then
         FDIR.Log_Count := FDIR.Log_Count + 1;
         FDIR.Logs (FDIR.Log_Count) :=
           (Timestamp_Ms => Time_Ms,
            Channel      => Faulty,
            Severity     => Sev,
            Event_Code   => 101);
      end if;
   end Handle_Channel_Discrepancy;

   procedure Resynchronize_Channel
     (FDIR           : in out FDIR_Supervisor;
      Channels       : in out Triplicated_Channels;
      Target_Channel : Channel_Id;
      Master_Channel : Channel_Id;
      Success        : out Boolean)
   is
   begin
      if not Is_Channel_Usable (Channels, Master_Channel) then
         Success := False;
         return;
      end if;

      -- Copy vital state from healthy master to target channel
      Channels (Target_Channel).Core_State              := Channels (Master_Channel).Core_State;
      Channels (Target_Channel).Health                  := Channel_Nominal;
      Channels (Target_Channel).Consecutive_Divergences := 0;
      Channels (Target_Channel).Is_Isolated             := False;

      if FDIR.Log_Count < 64 then
         FDIR.Log_Count := FDIR.Log_Count + 1;
         FDIR.Logs (FDIR.Log_Count) :=
           (Timestamp_Ms => 0,
            Channel      => Target_Channel,
            Severity     => Severity_Informational,
            Event_Code   => 200); -- Channel resynchronization complete
      end if;

      Success := True;
   end Resynchronize_Channel;

   function Total_Fault_Events (FDIR : FDIR_Supervisor) return Natural is
   begin
      return FDIR.Log_Count;
   end Total_Fault_Events;

end Aspect.Vital.FDIR;
