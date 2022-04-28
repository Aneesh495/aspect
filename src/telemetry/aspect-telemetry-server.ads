-- Non-blocking telemetry broadcast server and dispatcher command ingestor.
-- Broadcasts real-time JSON snapshots over TCP/IPC sockets and ingests
-- operator commands without stalling the 50ms vital cycle.

with Aspect.POSIX; use Aspect.POSIX;

package Aspect.Telemetry.Server is

   Max_Clients : constant := 8;
   Default_TCP_Port : constant := 9002;

   type Client_Array is array (1 .. Max_Clients) of Socket_Descriptor;

   type Telemetry_Server is record
      Server_Fd    : Socket_Descriptor := Invalid_Socket;
      Clients      : Client_Array      := [others => Invalid_Socket];
      Active_Count : Natural           := 0;
      Is_Running   : Boolean           := False;
   end record;

   -- Initializes and binds the non-blocking TCP server on 127.0.0.1:Port
   procedure Start_Server
     (Server : out Telemetry_Server;
      Port   : Natural := Default_TCP_Port);

   -- Polls for new client connections and cleans up disconnected sockets
   procedure Poll_Clients (Server : in out Telemetry_Server);

   -- Broadcasts current telemetry snapshot to all connected clients
   procedure Broadcast_Snapshot
     (Server   : in out Telemetry_Server;
      Snapshot : Telemetry_Snapshot);

   -- Reads pending incoming commands from clients and dispatches to world
   procedure Ingest_Commands
     (Server : in out Telemetry_Server;
      World  : in out World_Context);

   -- Cleanly closes all client sockets and server descriptor
   procedure Stop_Server (Server : in out Telemetry_Server);

end Aspect.Telemetry.Server;
