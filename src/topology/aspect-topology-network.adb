package body Aspect.Topology.Network is

   procedure Initialize_Network (Net : out Railway_Network) is
   begin
      Net.Section_Count := 0;
      Net.Switch_Count  := 0;
      Net.Signal_Count  := 0;
      Net.Balise_Count  := 0;
   end Initialize_Network;

   procedure Register_Section
     (Net     : in out Railway_Network;
      Section : Track_Section)
   is
   begin
      Net.Sections (Section.Id) := Section;
      if Natural (Section.Id) > Net.Section_Count then
         Net.Section_Count := Natural (Section.Id);
      end if;
   end Register_Section;

   procedure Register_Switch
     (Net    : in out Railway_Network;
      Switch : Turnout_Switch)
   is
   begin
      Net.Switches (Switch.Id) := Switch;
      if Natural (Switch.Id) > Net.Switch_Count then
         Net.Switch_Count := Natural (Switch.Id);
      end if;

      -- Mark boundary linkage in adjacency map
      if Switch.Facing_Section /= Null_Section_Id then
         Net.Adjacency (Switch.Facing_Section).Switch_Bound := Switch.Id;
      end if;
   end Register_Switch;

   procedure Register_Signal
     (Net    : in out Railway_Network;
      Signal : Railway_Signal)
   is
   begin
      Net.Signals (Signal.Id) := Signal;
      if Natural (Signal.Id) > Net.Signal_Count then
         Net.Signal_Count := Natural (Signal.Id);
      end if;
   end Register_Signal;

   procedure Register_Balise
     (Net    : in out Railway_Network;
      Balise : Eurobalise)
   is
   begin
      Net.Balises (Balise.Id) := Balise;
      if Natural (Balise.Id) > Net.Balise_Count then
         Net.Balise_Count := Natural (Balise.Id);
      end if;
   end Register_Balise;

   procedure Link_Sections
     (Net      : in out Railway_Network;
      From_Sec : Section_Id;
      To_Sec   : Section_Id;
      Dir      : Direction_Type := Dir_Nominal)
   is
   begin
      if Dir = Dir_Nominal then
         Net.Adjacency (From_Sec).Nominal_Next := To_Sec;
         Net.Adjacency (To_Sec).Reverse_Next   := From_Sec;
      else
         Net.Adjacency (From_Sec).Reverse_Next := To_Sec;
         Net.Adjacency (To_Sec).Nominal_Next   := From_Sec;
      end if;
   end Link_Sections;

   function Next_Section
     (Net     : Railway_Network;
      Current : Section_Id;
      Dir     : Direction_Type) return Section_Id_Base
   is
      Sw_Id : constant Switch_Id_Base := Net.Adjacency (Current).Switch_Bound;
   begin
      -- If there is a turnout switch directly associated with this section
      if Sw_Id /= Null_Switch_Id then
         declare
            Sw : constant Turnout_Switch := Net.Switches (Sw_Id);
         begin
            -- Facing point approach: entering switch from toe
            if Current = Sw.Facing_Section then
               if Sw.Position = Switch_Normal and then Sw.Normal_Detection_Relay then
                  return Sw.Normal_Section;
               elsif Sw.Position = Switch_Reverse and then Sw.Reverse_Detection_Relay then
                  return Sw.Reverse_Section;
               else
                  -- Points in transit or lost detection; path severed
                  return Null_Section_Id;
               end if;
            -- Trailing point approach from normal leg
            elsif Current = Sw.Normal_Section then
               if Sw.Position = Switch_Normal and then Sw.Normal_Detection_Relay then
                  return Sw.Facing_Section;
               else
                  return Null_Section_Id; -- Trailing against switch orientation
               end if;
            -- Trailing point approach from reverse leg
            elsif Current = Sw.Reverse_Section then
               if Sw.Position = Switch_Reverse and then Sw.Reverse_Detection_Relay then
                  return Sw.Facing_Section;
               else
                  return Null_Section_Id; -- Trailing against switch orientation
               end if;
            end if;
         end;
      end if;

      -- Standard linear track block adjacency
      if Dir = Dir_Nominal then
         return Net.Adjacency (Current).Nominal_Next;
      else
         return Net.Adjacency (Current).Reverse_Next;
      end if;
   end Next_Section;

   function Compute_Path_Distance
     (Net  : Railway_Network;
      Path : Section_List) return Distance_M
   is
      Total : Float := 0.0;
   begin
      for I in Path'Range loop
         Total := Total + Float (Net.Sections (Path (I)).Length_M);
      end loop;
      if Total > 100_000.0 then
         return 100_000.0;
      else
         return Distance_M (Total);
      end if;
   end Compute_Path_Distance;

   function Minimum_Speed_Along_Path
     (Net  : Railway_Network;
      Path : Section_List) return Speed_Kph
   is
      Min_Spd : Speed_Kph := 500.0;
   begin
      if Path'Length = 0 then
         return 0.0;
      end if;

      for I in Path'Range loop
         if Net.Sections (Path (I)).Line_Speed_Limit < Min_Spd then
            Min_Spd := Net.Sections (Path (I)).Line_Speed_Limit;
         end if;
      end loop;
      return Min_Spd;
   end Minimum_Speed_Along_Path;

   function Verify_Integrity (Net : Railway_Network) return Boolean is
   begin
      -- Verify each registered switch references valid existing track sections
      for I in 1 .. Net.Switch_Count loop
         declare
            Sw : constant Turnout_Switch := Net.Switches (Switch_Id (I));
         begin
            if Sw.Facing_Section = Null_Section_Id
              or else Sw.Normal_Section = Null_Section_Id
              or else Sw.Reverse_Section = Null_Section_Id
            then
               return False;
            end if;
         end;
      end loop;

      -- Verify signals reference valid track sections
      for I in 1 .. Net.Signal_Count loop
         declare
            Sig : constant Railway_Signal := Net.Signals (Signal_Id (I));
         begin
            if Sig.Track_Section = Null_Section_Id then
               return False;
            end if;
         end;
      end loop;

      return True;
   end Verify_Integrity;

end Aspect.Topology.Network;
