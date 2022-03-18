with Aspect.Topology.Signals; use Aspect.Topology.Signals;

package body Aspect.Interlocking.Approach is

   procedure Initialize_Approach_Table (Table : out Approach_Table) is
   begin
      Table := [others => (Route_Ref => Null_Route_Id, Timer_Active => False, Timer_Remaining => 0)];
   end Initialize_Approach_Table;

   procedure Request_Cancellation
     (Table   : in out Approach_Table;
      Net     : in out Railway_Network;
      Route   : in out Interlocking_Route;
      Status  : out Cancellation_Status)
   is
      Sig_Id : constant Signal_Id_Base := Route.Origin_Signal;
      Succ   : Boolean;
   begin
      if not Is_Active (Route) then
         Status := Cancel_Rejected;
         return;
      end if;

      -- If train has already accepted the green signal and entered the interlocking,
      -- standard cancellation is strictly forbidden
      if Route.State in Route_Occupied | Route_Sectional_Release then
         Status := Cancel_Rejected;
         return;
      end if;

      -- If signal was never cleared (still in Requested or Interlocked), cancel immediately
      if Route.State in Route_Requested | Route_Interlocked then
         Transition_State (Route, Route_Cancelled, Succ);
         Status := Cancel_Immediate;
         return;
      end if;

      -- Signal was cleared; inspect approach track occupancy
      if Sig_Id /= Null_Signal_Id then
         declare
            App_Sec : constant Section_Id_Base := Net.Signals (Sig_Id).Approach_Section;
            Train_Approaching : Boolean := False;
         begin
            if App_Sec /= Null_Section_Id then
               Train_Approaching := (Net.Sections (App_Sec).Occupancy = State_Occupied);
            end if;

            -- Immediately drop signal to danger regardless of approach lock
            Drop_To_Danger (Net.Signals (Sig_Id));

            if Train_Approaching then
               -- Train is within sighting distance; initiate approach locking countdown
               Table (Route.Id).Route_Ref       := Route.Id;
               Table (Route.Id).Timer_Active    := True;
               Table (Route.Id).Timer_Remaining := Default_Approach_Timeout_Ms;
               Status := Cancel_Approach_Timer;
            else
               -- Approach clear; safe to revoke route immediately
               Transition_State (Route, Route_Cancelled, Succ);
               Status := Cancel_Immediate;
            end if;
         end;
      else
         Transition_State (Route, Route_Cancelled, Succ);
         Status := Cancel_Immediate;
      end if;
   end Request_Cancellation;

   procedure Update_Approach_Timers
     (Table    : in out Approach_Table;
      Net      : in out Railway_Network;
      Routes   : in out Route_Array;
      Delta_Ms : Positive)
   is
      pragma Unreferenced (Net);
      Succ : Boolean;
   begin
      for I in Table'Range loop
         if Table (I).Timer_Active then
            if Table (I).Timer_Remaining <= Delta_Ms then
               Table (I).Timer_Remaining := 0;
               Table (I).Timer_Active    := False;
               -- Timer elapsed; train had adequate distance to stop safely; revoke route
               Transition_State (Routes (I), Route_Cancelled, Succ);
            else
               Table (I).Timer_Remaining := Table (I).Timer_Remaining - Delta_Ms;
            end if;
         end if;
      end loop;
   end Update_Approach_Timers;

   function Is_Under_Approach_Lock
     (Table : Approach_Table;
      Route : Route_Id) return Boolean
   is
   begin
      return Table (Route).Timer_Active;
   end Is_Under_Approach_Lock;

end Aspect.Interlocking.Approach;
