-- Radio Block Centre (RBC) supervising ETCS Level 2 train communications.
-- Translates Computer-Based Interlocking route locks into dynamic Movement Authorities,
-- gradient profiles, and speed profiles transmitted over Euroradio.

with Aspect.Topology; use Aspect.Topology;
with Aspect.Interlocking.Engine; use Aspect.Interlocking.Engine;
with Aspect.ETCS.Packets; use Aspect.ETCS.Packets;

package Aspect.ETCS.RBC is

   type Session_State is (
      Session_Disconnected,
      Session_Connecting,
      Session_Active,
      Session_Terminating
   );

   type Train_Position_Report is record
      Train               : Train_Id_Base  := Null_Train_Id;
      Current_Chainage    : Track_Chainage := 0.0;
      Current_Speed       : Speed_Kph      := 0.0;
      Current_Section     : Section_Id_Base:= Null_Section_Id;
      Report_Timestamp_Ms : Natural        := 0;
   end record;

   type RBC_Train_Session is record
      Train               : Train_Id_Base         := Null_Train_Id;
      State               : Session_State         := Session_Disconnected;
      Last_Position       : Train_Position_Report;
      Allocated_Route     : Route_Id_Base         := Null_Route_Id;
      Last_Generated_MA   : Packet_12_Movement_Authority;
      Last_Generated_P21  : Packet_21_Gradient_Profile;
      Last_Generated_P27  : Packet_27_Static_Speed_Profile;
      MA_Needs_Update     : Boolean               := False;
   end record;

   type Session_Array is array (Train_Id) of RBC_Train_Session;

   type Radio_Block_Centre is record
      Sessions            : Session_Array         := [others => <>];
      Registered_Count    : Natural               := 0;
   end record;

   procedure Initialize_RBC (Centre : out Radio_Block_Centre);

   -- Registers and establishes radio session with a train
   procedure Register_Train_Session
     (Centre : in out Radio_Block_Centre;
      Train  : Train_Id);

   -- Ingests position report from train
   procedure Process_Position_Report
     (Centre : in out Radio_Block_Centre;
      Report : Train_Position_Report);

   -- Synthesizes dynamic Movement Authority by querying CBI state
   procedure Generate_Movement_Authority
     (Centre : in out Radio_Block_Centre;
      Core   : Interlocking_Core;
      Train  : Train_Id;
      Route  : Route_Id;
      Succ   : out Boolean);

   function Has_Pending_MA
     (Centre : Radio_Block_Centre;
      Train  : Train_Id) return Boolean;

end Aspect.ETCS.RBC;
