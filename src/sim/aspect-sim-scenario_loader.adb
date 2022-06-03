-- Implementation of declarative JSON railway scenario loader.

with Ada.Text_IO; use Ada.Text_IO;
with Aspect.Types; use Aspect.Types;
with Aspect.Topology; use Aspect.Topology;
with Aspect.Topology.Tracks; use Aspect.Topology.Tracks;
with Aspect.Topology.Switches; use Aspect.Topology.Switches;
with Aspect.Topology.Signals; use Aspect.Topology.Signals;
with Aspect.Interlocking.Routes; use Aspect.Interlocking.Routes;
with Aspect.Sim.Vehicle_Dynamics; use Aspect.Sim.Vehicle_Dynamics;

package body Aspect.Sim.Scenario_Loader is

   procedure Set_Error (Msg : out Error_String; Str : String) is
      Copy_Len : constant Natural := Natural'Min (Str'Length, Max_Error_Len);
   begin
      Msg := [others => ' '];
      Msg (1 .. Copy_Len) := Str (Str'First .. Str'First + Copy_Len - 1);
   end Set_Error;

   function Index_Of (Haystack : String; Needle : String; Start_At : Positive := 1) return Natural is
   begin
      if Needle'Length = 0 or else Haystack'Length < Needle'Length or else Start_At > Haystack'Last then
         return 0;
      end if;
      for I in Start_At .. Haystack'Last - Needle'Length + 1 loop
         if Haystack (I .. I + Needle'Length - 1) = Needle then
            return I;
         end if;
      end loop;
      return 0;
   end Index_Of;

   function Parse_Positive_Int (Text : String; Key : String; Start_At : Positive := 1) return Natural is
      K_Idx : constant Natural := Index_Of (Text, Key, Start_At);
      Idx   : Natural;
      Val   : Natural := 0;
      Found : Boolean := False;
   begin
      if K_Idx = 0 then
         return 0;
      end if;
      Idx := K_Idx + Key'Length;
      while Idx <= Text'Last and then (Text (Idx) = ' ' or else Text (Idx) = ':' or else Text (Idx) = '"') loop
         Idx := Idx + 1;
      end loop;
      while Idx <= Text'Last and then Text (Idx) in '0' .. '9' loop
         Found := True;
         Val := Val * 10 + (Character'Pos (Text (Idx)) - Character'Pos ('0'));
         Idx := Idx + 1;
      end loop;
      return (if Found then Val else 0);
   end Parse_Positive_Int;

   function Parse_Float_Val (Text : String; Key : String; Start_At : Positive := 1) return Float is
      K_Idx : constant Natural := Index_Of (Text, Key, Start_At);
      Idx   : Natural;
      S_Start: Natural;
   begin
      if K_Idx = 0 then
         return 0.0;
      end if;
      Idx := K_Idx + Key'Length;
      while Idx <= Text'Last and then (Text (Idx) = ' ' or else Text (Idx) = ':' or else Text (Idx) = '"') loop
         Idx := Idx + 1;
      end loop;
      S_Start := Idx;
      while Idx <= Text'Last and then (Text (Idx) in '0' .. '9' or else Text (Idx) = '.' or else Text (Idx) = '-') loop
         Idx := Idx + 1;
      end loop;
      if Idx > S_Start then
         return Float'Value (Text (S_Start .. Idx - 1));
      else
         return 0.0;
      end if;
   exception
      when others =>
         return 0.0;
   end Parse_Float_Val;

   procedure Load_Scenario_From_JSON
     (JSON_Text : String;
      Net       : out Railway_Network;
      Core      : out Interlocking_Core;
      Reg       : out Simulation_Registry;
      Success   : out Boolean;
      Error_Msg : out Error_String)
   is
      Sec_Array_Idx : constant Natural := Index_Of (JSON_Text, """sections""");
      Cur_Idx       : Natural;
      Sec_Count     : Natural := 0;
      Sw_Count      : Natural := 0;
      Sig_Count     : Natural := 0;
      Route_Count   : Natural := 0;
      Train_Count   : Natural := 0;
   begin
      Initialize_Network (Net);
      Initialize_Registry (Reg);
      Success := True;
      Set_Error (Error_Msg, "");

      if Sec_Array_Idx = 0 then
         Success := False;
         Set_Error (Error_Msg, "Missing 'sections' array in scenario JSON");
         return;
      end if;

      -- 1. Parse Sections
      Cur_Idx := Sec_Array_Idx;
      loop
         declare
            Item_Idx : constant Natural := Index_Of (JSON_Text, "{", Cur_Idx + 1);
            End_Item : Natural;
         begin
            exit when Item_Idx = 0;
            End_Item := Index_Of (JSON_Text, "}", Item_Idx);
            exit when End_Item = 0;

            -- Check if we left sections array
            declare
               Sw_Marker : constant Natural := Index_Of (JSON_Text, """switches""", Cur_Idx);
            begin
               if Sw_Marker > 0 and then Item_Idx > Sw_Marker then
                  exit;
               end if;
            end;

            declare
               Block_Str : constant String := JSON_Text (Item_Idx .. End_Item);
               Id_Val    : constant Natural := Parse_Positive_Int (Block_Str, """id""");
               Len_Val   : constant Float := Parse_Float_Val (Block_Str, """length_m""");
               Spd_Val   : constant Float := Parse_Float_Val (Block_Str, """line_speed_kph""");
               Grad_Val  : constant Float := Parse_Float_Val (Block_Str, """gradient_per_mille""");
               Sec       : Track_Section;
            begin
               if Id_Val > 0 and then Id_Val <= Positive (Section_Id'Last) then
                  Sec_Count := Natural'Max (Sec_Count, Id_Val);
                  Initialize_Section
                    (Section    => Sec,
                     Id         => Section_Id (Id_Val),
                     Name       => "SEC_" & Natural'Image (Id_Val),
                     Length_M   => Distance_M (Len_Val),
                     Start_Km   => Track_Chainage (Float (Id_Val - 1) * (Len_Val / 1000.0)),
                     Line_Speed => Speed_Kph (Spd_Val),
                     Gradient   => Gradient_Per_Mille (Grad_Val));
                  Net.Sections (Section_Id (Id_Val)) := Sec;
               end if;
            end;

            Cur_Idx := End_Item;
         end;
      end loop;
      Net.Section_Count := Sec_Count;

      -- 2. Parse Switches
      declare
         Sw_Array_Idx : constant Natural := Index_Of (JSON_Text, """switches""");
      begin
         if Sw_Array_Idx > 0 then
            Cur_Idx := Sw_Array_Idx;
            loop
               declare
                  Item_Idx : constant Natural := Index_Of (JSON_Text, "{", Cur_Idx + 1);
                  End_Item : Natural;
               begin
                  exit when Item_Idx = 0;
                  End_Item := Index_Of (JSON_Text, "}", Item_Idx);
                  exit when End_Item = 0;

                  declare
                     Sig_Marker : constant Natural := Index_Of (JSON_Text, """signals""", Cur_Idx);
                  begin
                     if Sig_Marker > 0 and then Item_Idx > Sig_Marker then
                        exit;
                     end if;
                  end;

                  declare
                     Block_Str : constant String := JSON_Text (Item_Idx .. End_Item);
                     Id_Val    : constant Natural := Parse_Positive_Int (Block_Str, """id""");
                     Point_Sec : constant Natural := Parse_Positive_Int (Block_Str, """point_section""");
                     Norm_Sec  : constant Natural := Parse_Positive_Int (Block_Str, """normal_section""");
                     Rev_Sec   : constant Natural := Parse_Positive_Int (Block_Str, """reverse_section""");
                     Spd_N     : constant Float := Parse_Float_Val (Block_Str, """speed_normal_kph""");
                     Spd_R     : constant Float := Parse_Float_Val (Block_Str, """speed_reverse_kph""");
                     Sw        : Turnout_Switch;
                  begin
                     if Id_Val > 0 and then Id_Val <= Positive (Switch_Id'Last) then
                        Sw_Count := Natural'Max (Sw_Count, Id_Val);
                        Initialize_Switch
                          (Switch          => Sw,
                           Id              => Switch_Id (Id_Val),
                           Name            => "SW_" & Natural'Image (Id_Val),
                           Point_Section   => Section_Id (Point_Sec),
                           Facing_Section  => Section_Id (Point_Sec),
                           Normal_Section  => Section_Id (Norm_Sec),
                           Reverse_Section => Section_Id (Rev_Sec),
                           Speed_Norm      => Speed_Kph (Spd_N),
                           Speed_Rev       => Speed_Kph (Spd_R));
                        Net.Switches (Switch_Id (Id_Val)) := Sw;
                     end if;
                  end;

                  Cur_Idx := End_Item;
               end;
            end loop;
         end if;
      end;
      Net.Switch_Count := Sw_Count;

      -- 3. Parse Signals
      declare
         Sig_Array_Idx : constant Natural := Index_Of (JSON_Text, """signals""");
      begin
         if Sig_Array_Idx > 0 then
            Cur_Idx := Sig_Array_Idx;
            loop
               declare
                  Item_Idx : constant Natural := Index_Of (JSON_Text, "{", Cur_Idx + 1);
                  End_Item : Natural;
               begin
                  exit when Item_Idx = 0;
                  End_Item := Index_Of (JSON_Text, "}", Item_Idx);
                  exit when End_Item = 0;

                  declare
                     Route_Marker : constant Natural := Index_Of (JSON_Text, """routes""", Cur_Idx);
                  begin
                     if Route_Marker > 0 and then Item_Idx > Route_Marker then
                        exit;
                     end if;
                  end;

                  declare
                     Block_Str : constant String := JSON_Text (Item_Idx .. End_Item);
                     Id_Val    : constant Natural := Parse_Positive_Int (Block_Str, """id""");
                     Sec_Val   : constant Natural := Parse_Positive_Int (Block_Str, """section""");
                     App_Val   : constant Natural := Parse_Positive_Int (Block_Str, """approach_section""");
                     Next_Val  : constant Natural := Parse_Positive_Int (Block_Str, """next_signal""");
                     Chain_Val : constant Float := Parse_Float_Val (Block_Str, """chainage_km""");
                     Sig       : Railway_Signal;
                  begin
                     if Id_Val > 0 and then Id_Val <= Positive (Signal_Id'Last) then
                        Sig_Count := Natural'Max (Sig_Count, Id_Val);
                        Initialize_Signal
                          (Signal       => Sig,
                           Id           => Signal_Id (Id_Val),
                           Name         => "SIG_" & Natural'Image (Id_Val),
                           Category     => Category_Main,
                           Section      => Section_Id (Sec_Val),
                           Approach_Sec => Section_Id (App_Val),
                           Next_Sig     => Signal_Id_Base (Next_Val),
                           Chainage     => Track_Chainage (Chain_Val));
                        Net.Signals (Signal_Id (Id_Val)) := Sig;
                     end if;
                  end;

                  Cur_Idx := End_Item;
               end;
            end loop;
         end if;
      end;
      Net.Signal_Count := Sig_Count;

      -- 4. Initialize Interlocking Core and Register Routes
      Initialize_Core (Core, Net);

      declare
         Route_Array_Idx : constant Natural := Index_Of (JSON_Text, """routes""");
      begin
         if Route_Array_Idx > 0 then
            Cur_Idx := Route_Array_Idx;
            loop
               declare
                  Item_Idx : constant Natural := Index_Of (JSON_Text, "{", Cur_Idx + 1);
                  End_Item : Natural;
               begin
                  exit when Item_Idx = 0;
                  End_Item := Index_Of (JSON_Text, "}", Item_Idx);
                  exit when End_Item = 0;

                  declare
                     Train_Marker : constant Natural := Index_Of (JSON_Text, """trains""", Cur_Idx);
                  begin
                     if Train_Marker > 0 and then Item_Idx > Train_Marker then
                        exit;
                     end if;
                  end;

                  declare
                     Block_Str : constant String := JSON_Text (Item_Idx .. End_Item);
                     Id_Val    : constant Natural := Parse_Positive_Int (Block_Str, """id""");
                     Entry_Sig : constant Natural := Parse_Positive_Int (Block_Str, """entry_signal""");
                     Exit_Sig  : constant Natural := Parse_Positive_Int (Block_Str, """exit_signal""");
                     R         : Interlocking_Route;
                  begin
                     if Id_Val > 0 and then Id_Val <= Positive (Route_Id'Last) then
                        Route_Count := Natural'Max (Route_Count, Id_Val);
                        Initialize_Route
                          (Route      => R,
                           Id         => Route_Id (Id_Val),
                           Name       => "R_" & Natural'Image (Id_Val),
                           Origin_Sig => Signal_Id (Entry_Sig),
                           Exit_Sig   => Signal_Id_Base (Exit_Sig),
                           Class      => Class_Main_Train);

                        -- Add basic section 1
                        Add_Section (R, 1);
                        Register_Route (Core, R);
                     end if;
                  end;

                  Cur_Idx := End_Item;
               end;
            end loop;
         end if;
      end;

      Finalize_Configuration (Core);

      -- 5. Parse Trains
      declare
         Train_Array_Idx : constant Natural := Index_Of (JSON_Text, """trains""");
      begin
         if Train_Array_Idx > 0 then
            Cur_Idx := Train_Array_Idx;
            loop
               declare
                  Item_Idx : constant Natural := Index_Of (JSON_Text, "{", Cur_Idx + 1);
                  End_Item : Natural;
               begin
                  exit when Item_Idx = 0;
                  End_Item := Index_Of (JSON_Text, "}", Item_Idx);
                  exit when End_Item = 0;

                  declare
                     Block_Str : constant String := JSON_Text (Item_Idx .. End_Item);
                     Id_Val    : constant Natural := Parse_Positive_Int (Block_Str, """id""");
                     Mass_Val  : constant Float := Parse_Float_Val (Block_Str, """mass_tonnes""");
                     Len_Val   : constant Float := Parse_Float_Val (Block_Str, """length_m""");
                     Chain_Val : constant Float := Parse_Float_Val (Block_Str, """start_chainage_km""");
                     Sec_Val   : constant Natural := Parse_Positive_Int (Block_Str, """start_section""");
                     T         : Train_Vehicle;
                  begin
                     if Id_Val > 0 and then Id_Val <= Positive (Train_Id'Last) then
                        Train_Count := Natural'Max (Train_Count, Id_Val);
                        Initialize_Train
                          (Train    => T,
                           Id       => Train_Id (Id_Val),
                           Name     => "TR_" & Natural'Image (Id_Val),
                           Mass     => Mass_Tonnes (Mass_Val),
                           Length_M => Distance_M (Len_Val));

                        Add_Train
                          (Reg       => Reg,
                           Train     => T,
                           Start_Km  => Track_Chainage (Chain_Val),
                           Start_Sec => Section_Id (Sec_Val));
                     end if;
                  end;

                  Cur_Idx := End_Item;
               end;
            end loop;
         end if;
      end;

   end Load_Scenario_From_JSON;

   procedure Load_Scenario_From_File
     (File_Path : String;
      Net       : out Railway_Network;
      Core      : out Interlocking_Core;
      Reg       : out Simulation_Registry;
      Success   : out Boolean;
      Error_Msg : out Error_String)
   is
      File : File_Type;
      Max_File_Chars : constant := 32_768;
      Buffer : String (1 .. Max_File_Chars);
      Buf_Len: Natural := 0;
   begin
      begin
         Open (File, In_File, File_Path);
      exception
         when others =>
            Success := False;
            Set_Error (Error_Msg, "Cannot open file: " & File_Path);
            return;
      end;

      while not End_Of_File (File) and then Buf_Len < Max_File_Chars loop
         declare
            Line : constant String := Get_Line (File);
         begin
            if Buf_Len + Line'Length + 1 <= Max_File_Chars then
               Buffer (Buf_Len + 1 .. Buf_Len + Line'Length) := Line;
               Buf_Len := Buf_Len + Line'Length;
               Buffer (Buf_Len + 1) := ' ';
               Buf_Len := Buf_Len + 1;
            end if;
         end;
      end loop;

      Close (File);

      Load_Scenario_From_JSON
        (JSON_Text => Buffer (1 .. Buf_Len),
         Net       => Net,
         Core      => Core,
         Reg       => Reg,
         Success   => Success,
         Error_Msg => Error_Msg);

   exception
      when others =>
         if Is_Open (File) then
            Close (File);
         end if;
         Success := False;
         Set_Error (Error_Msg, "Unexpected exception during scenario load");
   end Load_Scenario_From_File;

end Aspect.Sim.Scenario_Loader;
