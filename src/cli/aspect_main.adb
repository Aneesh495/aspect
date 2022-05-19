-- Main executable entry point for the Aspect Railway Vital Interlocking & ETCS Level 2 Kernel.
-- Standards: EN 50128 SIL 4 / ERA ETCS Subset-026.
-- Implements the 50ms cyclic executive loop, interactive ANSI TUI, and telemetry streaming.

with Ada.Text_IO; use Ada.Text_IO;
with Aspect.POSIX; use Aspect.POSIX;
with Aspect.Sim.World; use Aspect.Sim.World;
with Aspect.Telemetry; use Aspect.Telemetry;
with Aspect.Telemetry.Server; use Aspect.Telemetry.Server;
with Aspect.TUI.Canvas; use Aspect.TUI.Canvas;
with Aspect.TUI.Track; use Aspect.TUI.Track;
with Aspect.TUI.Signals; use Aspect.TUI.Signals;
with Aspect.TUI.DMI; use Aspect.TUI.DMI;
with Aspect.TUI.Diagnostics; use Aspect.TUI.Diagnostics;
with Aspect.CLI; use Aspect.CLI;

procedure Aspect_Main is
   Config      : CLI_Config;
   Should_Exit : Boolean := False;
   World       : World_Context;
   Server      : Telemetry_Server;
   Snapshot    : Telemetry_Snapshot;
   Canvas      : Terminal_Canvas;

   Cycle_Ns    : constant Nanoseconds := 50_000_000; -- 50 milliseconds in nanoseconds
   T_Start     : Nanoseconds;
   T_End       : Nanoseconds;
   Elapsed     : Nanoseconds;
   Tick_Count  : Natural := 0;
begin
   Parse_Arguments (Config, Should_Exit);
   if Should_Exit then
      return;
   end if;

   -- 1. Initialize deterministic simulation world
   Initialize_Simulation_World (World, Scenario => Config.Scenario);

   -- 2. Bind and start non-blocking telemetry TCP server
   Start_Server (Server, Port => Config.Telemetry_Port);
   if Server.Is_Running then
      Put_Line ("[ASPECT] Telemetry TCP broadcast server active on port" &
                Positive'Image (Config.Telemetry_Port));
   else
      Put_Line ("[ASPECT] Note: Telemetry TCP broadcast server could not bind port" &
                Positive'Image (Config.Telemetry_Port));
   end if;

   -- Clear terminal screen if running interactive TUI
   if Config.Mode = Mode_Interactive_TUI then
      Ada.Text_IO.Put (Character'Val (27) & "[2J");
      Ada.Text_IO.Flush;
   else
      Put_Line ("[ASPECT] Running in headless mode. Press Ctrl+C to terminate.");
   end if;

   -- 3. Master 50ms Cyclic Executive Loop
   loop
      T_Start := Monotonic_Ns;

      -- Advance physics and vital interlocking state by 50ms
      Step_Simulation (World, Delta_Ms => Config.Tick_Delta_Ms);
      Tick_Count := Tick_Count + 1;

      -- Handle network telemetry and dispatcher commands
      if Server.Is_Running then
         Poll_Clients (Server);
         Ingest_Commands (Server, World);
      end if;

      -- Capture real-time snapshot
      Capture_Snapshot (World, Snapshot);

      -- Broadcast snapshot over active TCP client streams
      if Server.Is_Running then
         Broadcast_Snapshot (Server, Snapshot);
      end if;

      -- Render interactive TUI if enabled
      if Config.Mode = Mode_Interactive_TUI then
         Clear (Canvas);
         Render_Track_Layout (Canvas, Snapshot, Top_Row => 2, Left_Col => 2);
         Render_Signals_And_Routes (Canvas, Snapshot, Top_Row => 13, Left_Col => 2);
         Render_DMI (Canvas, Snapshot, Train_Idx => 1, Top_Row => 25, Left_Col => 2);
         Render_Diagnostics (Canvas, Snapshot, Top_Row => 25, Left_Col => 61);
         Render_Screen (Canvas, Clear_Screen => False);
      else
         -- In headless mode, log status periodically every 40 ticks (2 seconds)
         if Tick_Count mod 40 = 0 then
            Put_Line ("[ASPECT] Sim Time:" & Natural'Image (World.Sim_Time_Ms) & " ms" &
                      " | Steps:" & Natural'Image (World.Total_Steps) &
                      " | 2oo3 Voter:" & (if Snapshot.Voter.Is_Degraded then "DEGRADED" else "OK") &
                      " | Speed:" & Float'Image (Float (Snapshot.Trains (1).Current_Speed)) & " km/h" &
                      " | Permitted:" & Float'Image (Float (Snapshot.Trains (1).Permitted_Speed)) & " km/h");
         end if;
      end if;

      -- Check termination limit if specified
      if Config.Max_Ticks > 0 and then Tick_Count >= Config.Max_Ticks then
         Put_Line ("[ASPECT] Reached target tick count (" & Natural'Image (Config.Max_Ticks) & "). Exiting.");
         exit;
      end if;

      -- Precise high-resolution timing regulation for 50ms cycle
      T_End := Monotonic_Ns;
      if T_End > T_Start then
         Elapsed := T_End - T_Start;
         if Elapsed < Cycle_Ns then
            Sleep_Ns (Cycle_Ns - Elapsed);
         end if;
      end if;
   end loop;

   -- Clean up sockets and terminal
   Stop_Server (Server);
   if Config.Mode = Mode_Interactive_TUI then
      Ada.Text_IO.Put (Character'Val (27) & "[0m");
      Ada.Text_IO.New_Line;
   end if;

end Aspect_Main;
