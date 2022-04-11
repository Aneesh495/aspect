-- JSON serialization and command ingestion protocol for live telemetry streaming.
-- Emits compact, valid JSON matching dispatcher console schema with zero dynamic heap allocation.

with Aspect.Interlocking; use Aspect.Interlocking;

package Aspect.Telemetry.Protocol is

   Max_JSON_Payload_Size : constant := 16_384;

   subtype JSON_String_Buffer is String (1 .. Max_JSON_Payload_Size);

   -- Serializes an entire telemetry snapshot into valid JSON format
   procedure Snapshot_To_JSON
     (Snapshot : Telemetry_Snapshot;
      Buffer   : out JSON_String_Buffer;
      Length   : out Natural);

   -- Parses a dispatcher incoming JSON command
   -- Supported schema:
   --   {"command": "set_route", "route": 1}
   --   {"command": "cancel_route", "route": 1}
   --   {"command": "emergency_stop"}
   --   {"command": "throw_switch", "switch": 1, "position": "REVERSE"}
   procedure Parse_Command_JSON
     (Payload : String;
      Cmd     : out Interlocking_Command;
      Success : out Boolean);

end Aspect.Telemetry.Protocol;
