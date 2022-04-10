-- Implementation of real-time telemetry snapshot capture.

with Aspect.Topology.Tracks; use Aspect.Topology.Tracks;
with Aspect.Topology.Switches; use Aspect.Topology.Switches;
with Aspect.Topology.Signals; use Aspect.Topology.Signals;
with Aspect.Interlocking.Routes; use Aspect.Interlocking.Routes;
with Aspect.Interlocking.Engine; use Aspect.Interlocking.Engine;
with Aspect.ETCS.Packets; use Aspect.ETCS.Packets;
with Aspect.ETCS.Braking_Curves; use Aspect.ETCS.Braking_Curves;
with Aspect.Sim.Track_Simulation; use Aspect.Sim.Track_Simulation;
with Aspect.Vital.Cyclic_Executive; use Aspect.Vital.Cyclic_Executive;

package body Aspect.Telemetry is

   procedure Capture_Snapshot
     (World    : World_Context;
      Snapshot : out Telemetry_Snapshot)
   is
      Core_Ref : constant Interlocking_Core :=
        Get_Voted_Core (World.Supervisor);
   begin
      Snapshot.Timestamp_Ms := World.Sim_Time_Ms;
      Snapshot.Step_Number  := World.Total_Steps;

      -- 1. Track Section Occupancies and Locking
      Snapshot.Section_Count := Natural'Min (World.Net.Section_Count, Max_Telemetry_Sections);
      for I in 1 .. Snapshot.Section_Count loop
         declare
            Sec_Ref : constant Track_Section := World.Net.Sections (Section_Id (I));
         begin
            Snapshot.Sections (I) :=
              (Id           => Sec_Ref.Id,
               Is_Occupied  => Sec_Ref.Occupancy /= State_Clear,
               Is_Locked    => Sec_Ref.Lock_Status /= Lock_None,
               Ballast_Ohms => Sec_Ref.Ballast_Resistance,
               Axle_Count   => Sec_Ref.Axle_In_Count);
         end;
      end loop;

      -- 2. Switch Turnout Alignments and Locking
      Snapshot.Switch_Count := Natural'Min (World.Net.Switch_Count, Max_Telemetry_Switches);
      for I in 1 .. Snapshot.Switch_Count loop
         declare
            Sw_Ref : constant Turnout_Switch := World.Net.Switches (Switch_Id (I));
         begin
            Snapshot.Switches (I) :=
              (Id            => Sw_Ref.Id,
               Position      => Sw_Ref.Position,
               Blade_Gap_Mm  => 0,
               Is_Locked     => Sw_Ref.Is_Mechanically_Locked,
               Motor_Stalled => Sw_Ref.Obstacle_Stall_Fault,
               Trail_Through => Sw_Ref.Trailing_Cut_Detected);
         end;
      end loop;

      -- 3. Signal Lamps and Aspects
      Snapshot.Signal_Count := Natural'Min (World.Net.Signal_Count, Max_Telemetry_Signals);
      for I in 1 .. Snapshot.Signal_Count loop
         declare
            Sig_Ref : constant Railway_Signal := World.Net.Signals (Signal_Id (I));
         begin
            Snapshot.Signals (I) :=
              (Id           => Sig_Ref.Id,
               Aspect       => Sig_Ref.Current_Aspect,
               Current_Ma   => 250.0,
               Lamp_Fault   => Sig_Ref.Filament_Burnout_Fault);
         end;
      end loop;

      -- 4. Active Interlocking Routes
      Snapshot.Route_Count := Natural'Min (Core_Ref.Route_Count, Max_Telemetry_Routes);
      for I in 1 .. Snapshot.Route_Count loop
         declare
            R_Ref : constant Interlocking_Route := Core_Ref.Routes (Route_Id (I));
         begin
            Snapshot.Routes (I) :=
              (Id        => R_Ref.Id,
               State     => R_Ref.State,
               Entry_Sig => R_Ref.Origin_Signal,
               Exit_Sig  => R_Ref.Exit_Signal,
               Train     => R_Ref.Assigned_Train);
         end;
      end loop;

      -- 5. Active Trains and ETCS Supervision Envelopes
      Snapshot.Train_Count := Natural'Min (World.Registry.Train_Count, Max_Telemetry_Trains);
      for I in 1 .. Snapshot.Train_Count loop
         declare
            T_Ref  : constant Simulated_Train := World.Registry.Trains (Train_Id (I));
            Spd    : constant Speed_Kph := Mps_To_Kph (T_Ref.Vehicle.Speed);
            Env    : Supervision_Envelope;
            MA     : constant Packet_12_Movement_Authority :=
              World.RBC.Sessions (Train_Id (I)).Last_Generated_MA;
            Params : Train_Brake_Parameters;
         begin
            Params.Nominal_Emergency_A := 1.20;
            Params.Nominal_Service_A   := 0.85;

            Calculate_Envelopes
              (Params          => Params,
               Current_Speed   => Spd,
               Distance_To_EoA => MA.Distance_To_EoA,
               Distance_To_SvL => MA.Distance_To_SvL,
               Target_Speed    => 0.0,
               Ceiling_Speed   => MA.V_MAIN,
               Envelope        => Env);

            Snapshot.Trains (I) :=
              (Id               => T_Ref.Id,
               Chainage_Km      => T_Ref.Odometry.True_Chainage,
               Current_Speed    => Spd,
               Permitted_Speed  => Env.Permitted_Speed,
               Warning_Speed    => Env.Warning_Speed,
               SBI_Speed        => Env.SBI_Speed,
               EBI_Speed        => Env.EBI_Speed,
               Throttle_Pct     => T_Ref.Vehicle.Throttle_Demand,
               Brake_Pct        => T_Ref.Vehicle.Brake_Demand,
               Emergency_Brake  => T_Ref.Vehicle.Is_Emergency_Braking,
               Wheel_Slip       => T_Ref.Odometry.Wheel_Slip_Detected,
               Section          => T_Ref.Current_Section);
         end;
      end loop;

      -- 6. 2oo3 Voter Metrics
      Snapshot.Voter :=
        (Cycle_Count    => Natural (World.Supervisor.Metrics.Total_Cycles_Executed),
         Last_Passed    => World.Supervisor.Metrics.Last_Invariant_Passed,
         Divergences    => World.Supervisor.Metrics.Divergence_Events,
         Tripped_Cycles => World.Supervisor.Metrics.Tripped_Cycles,
         Is_Degraded    => World.Supervisor.Is_Halted);

   end Capture_Snapshot;

end Aspect.Telemetry;
