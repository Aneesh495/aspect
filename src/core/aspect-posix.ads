-- POSIX thin and thick bindings for high-resolution timing and non-blocking sockets.
-- Provides nanosecond clock access and non-blocking IPC primitives for real-time telemetry.

with Interfaces.C;
with Interfaces.C.Strings;
with System;

package Aspect.POSIX is

   type Socket_Descriptor is new Integer;
   Invalid_Socket : constant Socket_Descriptor := -1;

   type Nanoseconds  is mod 2**64;
   type Microseconds is mod 2**64;
   type Milliseconds is mod 2**64;

   ----------------------------------------------------------------------------
   -- High-Resolution Monotonic Clock Interface
   ----------------------------------------------------------------------------

   function Monotonic_Ns return Nanoseconds;
   function Monotonic_Us return Microseconds;
   function Monotonic_Ms return Milliseconds;

   procedure Sleep_Ns (Duration_Ns : Nanoseconds);
   procedure Sleep_Us (Duration_Us : Microseconds);
   procedure Sleep_Ms (Duration_Ms : Natural);

   ----------------------------------------------------------------------------
   -- Non-Blocking Sockets Interface
   ----------------------------------------------------------------------------

   -- Creates a non-blocking TCP server listening on 127.0.0.1:Port
   function Listen_TCP (Port : Natural) return Socket_Descriptor;

   -- Creates a non-blocking Unix domain stream server
   function Listen_Unix (Path : String) return Socket_Descriptor;

   -- Accepts an incoming connection without blocking
   -- Returns Invalid_Socket if no connection is currently pending
   function Accept_Client (Server_Fd : Socket_Descriptor) return Socket_Descriptor;

   -- Sends data over connected non-blocking socket
   -- Returns bytes sent, or negative on error
   function Send (Client_Fd : Socket_Descriptor; Data : String) return Integer;

   -- Receives data from non-blocking socket
   -- Returns bytes read, 0 on disconnect, -1 if no data is ready (EAGAIN), or -2 on error
   procedure Receive
     (Client_Fd : Socket_Descriptor;
      Buffer    : out String;
      Length    : out Natural;
      Status    : out Integer);

   -- Closes an active socket descriptor and sets it to Invalid_Socket
   procedure Close (Fd : in out Socket_Descriptor);

private

   ----------------------------------------------------------------------------
   -- Thin C Foreign Function Interfaces
   ----------------------------------------------------------------------------

   function C_Get_Monotonic_Ns return Nanoseconds with
     Import, Convention => C, External_Name => "aspect_get_monotonic_ns";

   function C_Get_Monotonic_Us return Microseconds with
     Import, Convention => C, External_Name => "aspect_get_monotonic_us";

   function C_Get_Monotonic_Ms return Milliseconds with
     Import, Convention => C, External_Name => "aspect_get_monotonic_ms";

   procedure C_Nanosleep (Duration_Ns : Nanoseconds) with
     Import, Convention => C, External_Name => "aspect_nanosleep";

   procedure C_Microsleep (Duration_Us : Microseconds) with
     Import, Convention => C, External_Name => "aspect_microsleep";

   function C_Listen_TCP (Port : Interfaces.C.unsigned_short) return Interfaces.C.int with
     Import, Convention => C, External_Name => "aspect_socket_listen_tcp";

   function C_Listen_Unix (Path : Interfaces.C.Strings.chars_ptr) return Interfaces.C.int with
     Import, Convention => C, External_Name => "aspect_socket_listen_unix";

   function C_Accept (Server_Fd : Interfaces.C.int) return Interfaces.C.int with
     Import, Convention => C, External_Name => "aspect_socket_accept";

   function C_Send
     (Client_Fd : Interfaces.C.int;
      Data      : System.Address;
      Len       : Interfaces.C.size_t) return Interfaces.C.int with
     Import, Convention => C, External_Name => "aspect_socket_send";

   function C_Receive
     (Client_Fd : Interfaces.C.int;
      Buffer    : System.Address;
      Max_Len   : Interfaces.C.size_t) return Interfaces.C.int with
     Import, Convention => C, External_Name => "aspect_socket_receive";

   procedure C_Close (Fd : Interfaces.C.int) with
     Import, Convention => C, External_Name => "aspect_socket_close";

end Aspect.POSIX;
