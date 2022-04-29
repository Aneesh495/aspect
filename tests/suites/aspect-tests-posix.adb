-- Implementation of POSIX timing and socket integration tests.

with Aspect.POSIX; use Aspect.POSIX;
with Aspect.Telemetry.Server; use Aspect.Telemetry.Server;
with Aspect.Tests.Framework; use Aspect.Tests.Framework;

package body Aspect.Tests.POSIX is

   ----------------------------------------------------------------------------
   -- Test: High-Resolution Monotonic Clock and Sleep
   ----------------------------------------------------------------------------
   procedure Test_Clock (Ctx : in out Test_Context) is
      T1_Ns, T2_Ns : Nanoseconds;
      T1_Us, T2_Us : Microseconds;
      T1_Ms        : Milliseconds;
      Elapsed_Us   : Microseconds;
   begin
      T1_Ns := Monotonic_Ns;
      T1_Us := Monotonic_Us;
      T1_Ms := Monotonic_Ms;

      Assert (Ctx, T1_Ns > 0, "Monotonic nanosecond clock returns positive value");
      Assert (Ctx, T1_Us > 0, "Monotonic microsecond clock returns positive value");
      Assert (Ctx, T1_Ms > 0, "Monotonic millisecond clock returns positive value");

      -- Sleep for 2000 microseconds (2.0 ms)
      Sleep_Us (2000);

      T2_Ns := Monotonic_Ns;
      T2_Us := Monotonic_Us;

      Assert (Ctx, T2_Ns > T1_Ns, "Nanosecond clock strictly increases after sleep");
      Assert (Ctx, T2_Us > T1_Us, "Microsecond clock strictly increases after sleep");

      Elapsed_Us := T2_Us - T1_Us;
      Assert (Ctx, Elapsed_Us >= 1500, "Elapsed sleep time at least 1500 microseconds");
      Assert (Ctx, Elapsed_Us <= 100_000, "Elapsed sleep time under 100 milliseconds");
   end Test_Clock;

   ----------------------------------------------------------------------------
   -- Test: Non-Blocking TCP Telemetry Server Lifecycle
   ----------------------------------------------------------------------------
   procedure Test_TCP_Server (Ctx : in out Test_Context) is
      Server : Telemetry_Server;
   begin
      Start_Server (Server, Port => 9876);
      Assert (Ctx, Server.Is_Running, "Telemetry server started successfully on port 9876");
      Assert (Ctx, Server.Server_Fd /= Invalid_Socket, "Server listening descriptor is valid");
      Assert (Ctx, Server.Active_Count = 0, "Initial client count is zero");

      -- Non-blocking poll returns immediately without stalling
      Poll_Clients (Server);
      Assert (Ctx, Server.Active_Count = 0, "Client count remains zero when no connections pending");

      Stop_Server (Server);
      Assert (Ctx, not Server.Is_Running, "Server stopped successfully");
      Assert (Ctx, Server.Server_Fd = Invalid_Socket, "Server socket closed and invalidated");
   end Test_TCP_Server;

   ----------------------------------------------------------------------------
   -- Test: Non-Blocking Unix Domain Socket
   ----------------------------------------------------------------------------
   procedure Test_Unix_Socket (Ctx : in out Test_Context) is
      Fd : Socket_Descriptor;
   begin
      Fd := Listen_Unix ("/tmp/aspect_test_ipc.sock");
      Assert (Ctx, Fd /= Invalid_Socket, "Created Unix domain socket at /tmp/aspect_test_ipc.sock");

      Close (Fd);
      Assert (Ctx, Fd = Invalid_Socket, "Unix socket closed and invalidated cleanly");
   end Test_Unix_Socket;

   ----------------------------------------------------------------------------
   -- Main Entry Point
   ----------------------------------------------------------------------------
   procedure Run_POSIX_Tests (Overall_Passed : in out Boolean) is
      Ctx : Test_Context;
   begin
      Init_Context (Ctx, "Aspect.POSIX (Monotonic Clock, Sleep, and Non-Blocking Sockets)");

      Test_Clock (Ctx);
      Test_TCP_Server (Ctx);
      Test_Unix_Socket (Ctx);

      if not Summarize (Ctx) then
         Overall_Passed := False;
      end if;
   end Run_POSIX_Tests;

end Aspect.Tests.POSIX;
