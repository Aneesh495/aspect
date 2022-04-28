-- Implementation of non-blocking telemetry server.

with Aspect.Interlocking; use Aspect.Interlocking;
with Aspect.Telemetry.Protocol; use Aspect.Telemetry.Protocol;

package body Aspect.Telemetry.Server is

   procedure Start_Server
     (Server : out Telemetry_Server;
      Port   : Natural := Default_TCP_Port)
   is
      Fd : constant Socket_Descriptor := Listen_TCP (Port);
   begin
      Server.Clients      := [others => Invalid_Socket];
      Server.Active_Count := 0;

      if Fd /= Invalid_Socket then
         Server.Server_Fd  := Fd;
         Server.Is_Running := True;
      else
         Server.Server_Fd  := Invalid_Socket;
         Server.Is_Running := False;
      end if;
   end Start_Server;

   procedure Poll_Clients (Server : in out Telemetry_Server) is
      New_Client : Socket_Descriptor;
   begin
      if not Server.Is_Running or else Server.Server_Fd = Invalid_Socket then
         return;
      end if;

      -- Poll for incoming connections
      loop
         New_Client := Accept_Client (Server.Server_Fd);
         exit when New_Client = Invalid_Socket;

         -- Find available slot
         declare
            Slot_Found : Boolean := False;
         begin
            for I in 1 .. Max_Clients loop
               if Server.Clients (I) = Invalid_Socket then
                  Server.Clients (I)  := New_Client;
                  Server.Active_Count := Server.Active_Count + 1;
                  Slot_Found          := True;
                  exit;
               end if;
            end loop;

            if not Slot_Found then
               -- Max capacity reached; close incoming connection
               Close (New_Client);
               exit;
            end if;
         end;
      end loop;
   end Poll_Clients;

   procedure Broadcast_Snapshot
     (Server   : in out Telemetry_Server;
      Snapshot : Telemetry_Snapshot)
   is
      Buffer : JSON_String_Buffer;
      Length : Natural := 0;
   begin
      if not Server.Is_Running or else Server.Active_Count = 0 then
         return;
      end if;

      Snapshot_To_JSON (Snapshot, Buffer, Length);

      if Length > 0 and then Length < Max_JSON_Payload_Size then
         Buffer (Length + 1) := ASCII.LF;
         Length := Length + 1;

         for I in 1 .. Max_Clients loop
            if Server.Clients (I) /= Invalid_Socket then
               declare
                  Res : constant Integer :=
                    Send (Server.Clients (I), Buffer (1 .. Length));
               begin
                  if Res < 0 then
                     -- Socket broken or client disconnected
                     Close (Server.Clients (I));
                     if Server.Active_Count > 0 then
                        Server.Active_Count := Server.Active_Count - 1;
                     end if;
                  end if;
               end;
            end if;
         end loop;
      end if;
   end Broadcast_Snapshot;

   procedure Ingest_Commands
     (Server : in out Telemetry_Server;
      World  : in out World_Context)
   is
      Recv_Buf : String (1 .. 1024);
      Recv_Len : Natural;
      Status   : Integer;
   begin
      if not Server.Is_Running or else Server.Active_Count = 0 then
         return;
      end if;

      for I in 1 .. Max_Clients loop
         if Server.Clients (I) /= Invalid_Socket then
            Receive (Server.Clients (I), Recv_Buf, Recv_Len, Status);

            if Status = 0 then
               -- Graceful peer disconnect
               Close (Server.Clients (I));
               if Server.Active_Count > 0 then
                  Server.Active_Count := Server.Active_Count - 1;
               end if;
            elsif Status > 0 then
               declare
                  Cmd  : Interlocking_Command;
                  Succ : Boolean;
               begin
                  Parse_Command_JSON (Recv_Buf (1 .. Recv_Len), Cmd, Succ);
                  if Succ then
                     Send_Dispatcher_Command (World, Cmd);
                  end if;
               end;
            end if;
         end if;
      end loop;
   end Ingest_Commands;

   procedure Stop_Server (Server : in out Telemetry_Server) is
   begin
      for I in 1 .. Max_Clients loop
         if Server.Clients (I) /= Invalid_Socket then
            Close (Server.Clients (I));
         end if;
      end loop;

      if Server.Server_Fd /= Invalid_Socket then
         Close (Server.Server_Fd);
      end if;

      Server.Active_Count := 0;
      Server.Is_Running   := False;
   end Stop_Server;

end Aspect.Telemetry.Server;
