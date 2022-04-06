-- Fault Detection, Isolation, and Recovery (FDIR) supervisor.
-- Governs hierarchical fault recovery, automated degradation from 3oo3 to 2oo2,
-- memory resynchronization, and fail-silent shutdown enforcement.

with Aspect.Types; use Aspect.Types;
with Aspect.Vital.Channels; use Aspect.Vital.Channels;

package Aspect.Vital.FDIR is

   type Diagnostic_Severity is (
      Severity_Informational,
      Severity_Transient_Fault,
      Severity_Channel_Isolated,
      Severity_System_Trip
   );

   type Diagnostic_Record is record
      Timestamp_Ms : Natural              := 0;
      Channel      : Channel_Id           := Channel_A;
      Severity     : Diagnostic_Severity  := Severity_Informational;
      Event_Code   : Natural              := 0;
   end record;

   type Diagnostic_Log is array (1 .. 64) of Diagnostic_Record;

   type FDIR_Supervisor is record
      Logs           : Diagnostic_Log := [others => <>];
      Log_Count      : Natural        := 0;
      Isolation_Mask : Natural        := 0;
   end record;

   procedure Initialize_FDIR (FDIR : out FDIR_Supervisor);

   -- Logs fault event and applies automated isolation if necessary
   procedure Handle_Channel_Discrepancy
     (FDIR     : in out FDIR_Supervisor;
      Channels : in out Triplicated_Channels;
      Faulty   : Channel_Id;
      Time_Ms  : Natural);

   -- Re-synchronizes a recovered channel from a healthy master channel
   procedure Resynchronize_Channel
     (FDIR           : in out FDIR_Supervisor;
      Channels       : in out Triplicated_Channels;
      Target_Channel : Channel_Id;
      Master_Channel : Channel_Id;
      Success        : out Boolean);

   function Total_Fault_Events (FDIR : FDIR_Supervisor) return Natural;

end Aspect.Vital.FDIR;
