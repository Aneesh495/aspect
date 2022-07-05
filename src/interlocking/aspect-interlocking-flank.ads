-- Flank protection engine guarding against converging side-collisions.
-- Automatically identifies converging switch legs, locks defensive points
-- in diverting alignments, and clamps opposing shunt signals to Stop.

with Aspect.Topology.Network; use Aspect.Topology.Network;

package Aspect.Interlocking.Flank is

   type Flank_Defense is record
      Protective_Switch : Switch_Id_Base  := Null_Switch_Id;
      Diverting_Position: Switch_Position := Switch_Normal;
      Protective_Signal : Signal_Id_Base  := Null_Signal_Id;
      Fouling_Section   : Section_Id_Base := Null_Section_Id;
   end record;

   type Flank_Defense_List is array (1 .. Max_Flank_Protections) of Flank_Defense;

   type Route_Flank_Profile is record
      Defenses      : Flank_Defense_List := [others => <>];
      Defense_Count : Natural            := 0;
   end record;

   type Flank_Table is array (Route_Id) of Route_Flank_Profile;

   procedure Initialize_Flank_Table (Table : out Flank_Table);

   procedure Add_Flank_Defense
     (Table              : in out Flank_Table;
      Route              : Route_Id;
      Protective_Switch  : Switch_Id;
      Diverting_Position : Switch_Position;
      Protective_Signal  : Signal_Id_Base := Null_Signal_Id;
      Fouling_Section    : Section_Id_Base := Null_Section_Id);

   -- Verifies whether all flank defensive points are locked and fouling sections clear
   function Verify_Flank_Integrity
     (Table   : Flank_Table;
      Net     : Railway_Network;
      Route   : Route_Id) return Boolean;

   -- Commands defensive switch throws and locks them in protective diverting alignment
   procedure Lock_Flank_Defenses
     (Table   : Flank_Table;
      Net     : in out Railway_Network;
      Route   : Route_Id;
      Success : out Boolean);

   -- Unlocks defensive flank switches upon route release
   procedure Unlock_Flank_Defenses
     (Table   : Flank_Table;
      Net     : in out Railway_Network;
      Route   : Route_Id);

end Aspect.Interlocking.Flank;
