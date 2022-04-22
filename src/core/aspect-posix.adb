-- Implementation of POSIX timing and socket bindings.

package body Aspect.POSIX is

   function Monotonic_Ns return Nanoseconds is
   begin
      return C_Get_Monotonic_Ns;
   end Monotonic_Ns;

   function Monotonic_Us return Microseconds is
   begin
      return C_Get_Monotonic_Us;
   end Monotonic_Us;

   function Monotonic_Ms return Milliseconds is
   begin
      return C_Get_Monotonic_Ms;
   end Monotonic_Ms;

   procedure Sleep_Ns (Duration_Ns : Nanoseconds) is
   begin
      C_Nanosleep (Duration_Ns);
   end Sleep_Ns;

   procedure Sleep_Us (Duration_Us : Microseconds) is
   begin
      C_Microsleep (Duration_Us);
   end Sleep_Us;

   procedure Sleep_Ms (Duration_Ms : Natural) is
   begin
      C_Microsleep (Microseconds (Duration_Ms) * 1000);
   end Sleep_Ms;

   function Listen_TCP (Port : Natural) return Socket_Descriptor is
      Fd : constant Interfaces.C.int :=
        C_Listen_TCP (Interfaces.C.unsigned_short (Port));
   begin
      return Socket_Descriptor (Fd);
   end Listen_TCP;

   function Listen_Unix (Path : String) return Socket_Descriptor is
      C_Path : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (Path);
      Fd     : constant Interfaces.C.int := C_Listen_Unix (C_Path);
   begin
      Interfaces.C.Strings.Free (C_Path);
      return Socket_Descriptor (Fd);
   end Listen_Unix;

   function Accept_Client (Server_Fd : Socket_Descriptor) return Socket_Descriptor is
      Fd : constant Interfaces.C.int := C_Accept (Interfaces.C.int (Server_Fd));
   begin
      return Socket_Descriptor (Fd);
   end Accept_Client;

   function Send (Client_Fd : Socket_Descriptor; Data : String) return Integer is
      Ret : constant Interfaces.C.int :=
        C_Send (Interfaces.C.int (Client_Fd), Data'Address, Data'Length);
   begin
      return Integer (Ret);
   end Send;

   procedure Receive
     (Client_Fd : Socket_Descriptor;
      Buffer    : out String;
      Length    : out Natural;
      Status    : out Integer)
   is
      Ret : constant Interfaces.C.int :=
        C_Receive (Interfaces.C.int (Client_Fd), Buffer'Address, Buffer'Length);
   begin
      Status := Integer (Ret);
      if Status > 0 then
         Length := Natural (Status);
      else
         Length := 0;
      end if;
   end Receive;

   procedure Close (Fd : in out Socket_Descriptor) is
   begin
      if Fd /= Invalid_Socket then
         C_Close (Interfaces.C.int (Fd));
         Fd := Invalid_Socket;
      end if;
   end Close;

end Aspect.POSIX;
