-- Implementation of property-based zero-collision verification.

with Aspect.Types; use Aspect.Types;
with Aspect.Interlocking; use Aspect.Interlocking;
with Aspect.Sim.Scenarios; use Aspect.Sim.Scenarios;
with Aspect.Sim.World; use Aspect.Sim.World;
with Aspect.Formal.Oracles; use Aspect.Formal.Oracles;

package body Aspect.Formal.Collision is

   type LCG_State is mod 2**32;

   function Next_Random (State : in out LCG_State) return Natural is
   begin
      State := State * 1103515245 + 12345;
      return Natural (State mod 1000);
   end Next_Random;

   procedure Verify_Collision_Property (Ctx : in out Test_Context) is
      World       : World_Context;
      Rng         : LCG_State := 42;
      Report      : Oracle_Report;
      Iterations  : constant Positive := 10_000;
      Cmd_Fired   : Natural := 0;
   begin
      Initialize_Simulation_World (World, Scenario => Scenario_Junction);

      for Iter in 1 .. Iterations loop
         -- Every 25 iterations, simulate random dispatcher action
         if Iter mod 25 = 0 then
            declare
               Dice : constant Natural := Next_Random (Rng) mod 4;
            begin
               case Dice is
                  when 0 =>
                     Send_Dispatcher_Command
                       (World,
                        (Kind      => Cmd_Set_Route,
                         Route     => 1,
                         Sw_Id     => Null_Switch_Id,
                         Sw_Target => Switch_Normal,
                         Issuer_Id => 1));
                     Cmd_Fired := Cmd_Fired + 1;
                  when 1 =>
                     Send_Dispatcher_Command
                       (World,
                        (Kind      => Cmd_Set_Route,
                         Route     => 2,
                         Sw_Id     => Null_Switch_Id,
                         Sw_Target => Switch_Reverse,
                         Issuer_Id => 1));
                     Cmd_Fired := Cmd_Fired + 1;
                  when 2 =>
                     Send_Dispatcher_Command
                       (World,
                        (Kind      => Cmd_Cancel_Route,
                         Route     => 1,
                         Sw_Id     => Null_Switch_Id,
                         Sw_Target => Switch_Normal,
                         Issuer_Id => 1));
                     Cmd_Fired := Cmd_Fired + 1;
                  when 3 =>
                     Send_Dispatcher_Command
                       (World,
                        (Kind      => Cmd_Emergency_Stop_All,
                         Route     => Null_Route_Id,
                         Sw_Id     => Null_Switch_Id,
                         Sw_Target => Switch_Normal,
                         Issuer_Id => 1));
                     Cmd_Fired := Cmd_Fired + 1;
                  when others =>
                     null;
               end case;
            end;
         end if;

         -- Advance world dynamics and interlocking 50ms cycle
         Step_Simulation (World, Delta_Ms => 50);

         -- Verify mathematical collision oracle
         Report := Verify_Zero_Collision (World);
         if not Report.Passed then
            Assert (Ctx, False, "Collision oracle violated at step " & Natural'Image (Iter) &
                                ": " & Report.Detail (1 .. Report.Detail_Len));
            return;
         end if;
      end loop;

      Assert (Ctx, True, "Zero-collision invariant verified across 10,000 randomized cycles (" &
                         Natural'Image (Cmd_Fired) & " dispatch actions)");
   end Verify_Collision_Property;

end Aspect.Formal.Collision;
