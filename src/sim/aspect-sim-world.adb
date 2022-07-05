with Aspect.Types; use Aspect.Types;
with Aspect.Interlocking.Engine; use Aspect.Interlocking.Engine;
with Aspect.ETCS.Packets; use Aspect.ETCS.Packets;
with Aspect.ETCS.Braking_Curves; use Aspect.ETCS.Braking_Curves;
with Aspect.Sim.Vehicle_Dynamics; use Aspect.Sim.Vehicle_Dynamics;
with Aspect.Vital; use Aspect.Vital;
with Aspect.Vital.Channels; use Aspect.Vital.Channels;

package body Aspect.Sim.World is

   procedure Initialize_Simulation_World
     (World    : out World_Context;
      Scenario : Scenario_Kind := Scenario_Junction)
   is
      Initial_Core : Interlocking_Core;
   begin
      World.Scenario    := Scenario;
      World.Sim_Time_Ms := 0;
      World.Total_Steps := 0;

      case Scenario is
         when Scenario_Junction =>
            Build_Junction_Scenario (World.Net, Initial_Core, World.Registry);
         when Scenario_High_Speed =>
            Build_High_Speed_Scenario (World.Net, Initial_Core, World.Registry);
         when Scenario_Safety_Stress =>
            Build_Safety_Stress_Scenario (World.Net, Initial_Core, World.Registry);
      end case;

      Initialize_Supervisor (World.Supervisor, Initial_Core);
      Initialize_RBC (World.RBC);

      -- Register all scenario trains with the Radio Block Centre
      for I in 1 .. World.Registry.Train_Count loop
         Register_Train_Session (World.RBC, Train_Id (I));
      end loop;
   end Initialize_Simulation_World;

   procedure Send_Dispatcher_Command
     (World : in out World_Context;
      Cmd   : Interlocking_Command)
   is
   begin
      for C in Channel_Id loop
         if Is_Channel_Usable (World.Supervisor.Channels, C) then
            World.Supervisor.Channels (C).Core_State.Net.Sections := World.Net.Sections;
         end if;
      end loop;
      Dispatch_Command (World.Supervisor, Cmd);
   end Send_Dispatcher_Command;

   procedure Step_Simulation
     (World    : in out World_Context;
      Delta_Ms : Positive := Default_Sim_Step_Ms)
   is
      Delta_S   : constant Float := Float (Delta_Ms) / 1000.0;
      Core_Ref  : Interlocking_Core;
      Succ      : Boolean;
   begin
      World.Sim_Time_Ms := World.Sim_Time_Ms + Delta_Ms;
      World.Total_Steps := World.Total_Steps + 1;

      -- Propagate field track detection to vital supervisor before cycle
      for C in Channel_Id loop
         if Is_Channel_Usable (World.Supervisor.Channels, C) then
            World.Supervisor.Channels (C).Core_State.Net.Sections := World.Net.Sections;
         end if;
      end loop;

      -- 1. Step the vital 2oo3 supervisory executive
      Execute_Minor_Cycle (World.Supervisor, Delta_Ms);
      Core_Ref := Get_Voted_Core (World.Supervisor);

      -- Synchronize physical field state with voted interlocking outputs
      World.Net.Switches := Core_Ref.Net.Switches;
      World.Net.Signals  := Core_Ref.Net.Signals;

      -- 2. Update train positions and track shunting in the physics world
      Update_Train_Positions (World.Registry, World.Net, Core_Ref, Delta_S);

      -- 3. RBC Supervision and European Vital Computer (EVC) closed loop
      for I in 1 .. World.Registry.Train_Count loop
         declare
            T : Simulated_Train renames World.Registry.Trains (Train_Id (I));
         begin
            if T.Is_Active then
               -- Train sends periodic position report to RBC
               Process_Position_Report
                 (World.RBC,
                  (Train               => Train_Id (I),
                   Current_Chainage    => T.Odometry.True_Chainage,
                   Current_Speed       => Mps_To_Kph (T.Vehicle.Speed),
                   Current_Section     => T.Current_Section,
                   Report_Timestamp_Ms => World.Sim_Time_Ms));

               -- If route is active, check RBC Movement Authority synthesis
               if Core_Ref.Route_Count > 0 then
                  Generate_Movement_Authority (World.RBC, Core_Ref, Train_Id (I), 1, Succ);
                  if Succ then
                     -- EVC calculates braking curves against current speed
                     declare
                        Params : Train_Brake_Parameters;
                        Env    : Supervision_Envelope;
                        MA     : constant Packet_12_Movement_Authority :=
                          World.RBC.Sessions (Train_Id (I)).Last_Generated_MA;
                     begin
                        Params.Nominal_Emergency_A := 1.20;
                        Params.Nominal_Service_A   := 0.85;

                        Calculate_Envelopes
                          (Params          => Params,
                           Current_Speed   => Mps_To_Kph (T.Vehicle.Speed),
                           Distance_To_EoA => MA.Distance_To_EoA,
                           Distance_To_SvL => MA.Distance_To_SvL,
                           Target_Speed    => 0.0,
                           Ceiling_Speed   => MA.V_MAIN,
                           Envelope        => Env);

                        -- EVC Driver model: Accelerate up to permitted speed
                        if Env.Current_Status = Status_Normal then
                           if Mps_To_Kph (T.Vehicle.Speed) < Env.Permitted_Speed - 10.0 then
                              Set_Throttle (T.Vehicle, Demand => 70.0);
                           else
                              Set_Throttle (T.Vehicle, Demand => 15.0); -- Coasting
                           end if;
                        elsif Env.Current_Status = Status_Indication then
                           -- Driver prepares to brake
                           Set_Throttle (T.Vehicle, Demand => 0.0);
                        elsif Env.Current_Status = Status_Overspeed_Warning then
                           -- Driver applies service brake
                           Set_Braking (T.Vehicle, Demand => 50.0);
                        elsif Env.Current_Status = Status_Service_Intervention then
                           -- EVC automated service brake intervention
                           Set_Braking (T.Vehicle, Demand => 100.0);
                        elsif Env.Current_Status = Status_Emergency_Trip then
                           -- EVC emergency brake trip
                           Set_Braking (T.Vehicle, Demand => 100.0, Is_Emergency => True);
                        end if;
                     end;
                  end if;
               end if;
            end if;
         end;
      end loop;
   end Step_Simulation;

end Aspect.Sim.World;
