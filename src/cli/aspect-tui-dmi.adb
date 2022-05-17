-- Implementation of ETCS Level 2 DMI speedometer renderer.

with Aspect.Types; use Aspect.Types;

package body Aspect.TUI.DMI is

   function Format_Float (Val : Float; Decimals : Natural := 1) return String is
      V_Abs     : constant Float := abs Val;
      Int_Part  : constant Long_Long_Integer := Long_Long_Integer (Float'Floor (V_Abs));
      Frac_Part : constant Float := V_Abs - Float (Int_Part);
      Mult      : Float := 1.0;
   begin
      for D in 1 .. Decimals loop
         Mult := Mult * 10.0;
      end loop;
      declare
         Frac_Int : constant Long_Long_Integer := Long_Long_Integer (Float'Floor (Frac_Part * Mult));
         Frac_Str : constant String := Long_Long_Integer'Image (Frac_Int);
         Start    : constant Positive := (if Frac_Str (Frac_Str'First) = ' ' then Frac_Str'First + 1 else Frac_Str'First);
         Int_Str  : constant String := Long_Long_Integer'Image (Int_Part);
         Int_Start: constant Positive := (if Int_Str (Int_Str'First) = ' ' then Int_Str'First + 1 else Int_Str'First);
      begin
         return (if Val < 0.0 then "-" else "") &
                Int_Str (Int_Start .. Int_Str'Last) & "." &
                Frac_Str (Start .. Frac_Str'Last);
      end;
   end Format_Float;

   procedure Render_DMI
     (C        : in out Terminal_Canvas;
      Snapshot : Telemetry_Snapshot;
      Train_Idx: Positive := 1;
      Top_Row  : Positive := 25;
      Left_Col : Positive := 2)
   is
      Width  : constant Positive := 57;
      Height : constant Positive := 11;
   begin
      Draw_Box
        (C      => C,
         Top    => Top_Row,
         Left   => Left_Col,
         Height => Height,
         Width  => Width,
         Title  => "ETCS LEVEL 2 DMI CAB SPEEDOMETER",
         FG     => Color_Bright_Cyan,
         Bold   => True);

      if Snapshot.Train_Count < Train_Idx then
         Put_String (C, Top_Row + 4, Left_Col + 15, "NO ACTIVE TRAIN EN ROUTE", FG => Color_Dim_White);
         return;
      end if;

      declare
         T : constant Train_Telemetry := Snapshot.Trains (Train_Idx);
         Speed_Col : constant Color_Type :=
           (if T.Current_Speed > T.EBI_Speed then Color_Bright_Red
            elsif T.Current_Speed > T.Warning_Speed then Color_Bright_Yellow
            elsif T.Current_Speed > T.Permitted_Speed then Color_Bright_Yellow
            else Color_Bright_Green);
      begin
         -- Speedometer Dial ASCII Graphic
         Put_String (C, Top_Row + 2, Left_Col + 3, "  .---.", FG => Color_Bright_White);
         Put_String (C, Top_Row + 3, Left_Col + 3, " /  |  \\", FG => Speed_Col, Bold => True);
         Put_String (C, Top_Row + 4, Left_Col + 3, "|   *   |", FG => Speed_Col, Bold => True);
         Put_String (C, Top_Row + 5, Left_Col + 3, " \\     /", FG => Color_Bright_White);
         Put_String (C, Top_Row + 6, Left_Col + 3, "  '---'", FG => Color_Bright_White);

         -- Numeric Supervision Readouts
         Put_String (C, Top_Row + 2, Left_Col + 14, "ACTUAL SPEED : ", FG => Color_Bright_White, Bold => True);
         Put_String (C, Top_Row + 2, Left_Col + 30, Format_Float (Float (T.Current_Speed)) & " km/h", FG => Speed_Col, Bold => True);

         Put_String (C, Top_Row + 3, Left_Col + 14, "PERMITTED (V): ", FG => Color_Dim_White);
         Put_String (C, Top_Row + 3, Left_Col + 30, Format_Float (Float (T.Permitted_Speed)) & " km/h", FG => Color_Bright_White);

         Put_String (C, Top_Row + 4, Left_Col + 14, "WARNING   (W): ", FG => Color_Dim_White);
         Put_String (C, Top_Row + 4, Left_Col + 30, Format_Float (Float (T.Warning_Speed)) & " km/h", FG => Color_Bright_Yellow);

         Put_String (C, Top_Row + 5, Left_Col + 14, "EBI TRIP  (E): ", FG => Color_Dim_White);
         Put_String (C, Top_Row + 5, Left_Col + 30, Format_Float (Float (T.EBI_Speed)) & " km/h", FG => Color_Bright_Red, Bold => True);

         -- Throttle Bargraph
         Put_String (C, Top_Row + 7, Left_Col + 3, "THROTTLE : [", FG => Color_Dim_White);
         declare
            Filled : constant Natural := Natural (Float'Floor (Float (T.Throttle_Pct) / 5.0));
         begin
            for B in 1 .. 20 loop
               if B <= Filled then
                  Put_Char (C, Top_Row + 7, Left_Col + 14 + B, '=', FG => Color_Bright_Green, Bold => True);
               else
                  Put_Char (C, Top_Row + 7, Left_Col + 14 + B, ' ', FG => Color_Dim_White);
               end if;
            end loop;
         end;
         Put_String (C, Top_Row + 7, Left_Col + 35, "] " & Format_Float (Float (T.Throttle_Pct)) & "%", FG => Color_Bright_White);

         -- Brake Bargraph
         Put_String (C, Top_Row + 8, Left_Col + 3, "BRAKE    : [", FG => Color_Dim_White);
         declare
            Filled : constant Natural := Natural (Float'Floor (Float (T.Brake_Pct) / 5.0));
         begin
            for B in 1 .. 20 loop
               if B <= Filled then
                  Put_Char (C, Top_Row + 8, Left_Col + 14 + B, '#', FG => Color_Bright_Red, Bold => True);
               else
                  Put_Char (C, Top_Row + 8, Left_Col + 14 + B, ' ', FG => Color_Dim_White);
               end if;
            end loop;
         end;
         Put_String (C, Top_Row + 8, Left_Col + 35, "] " & Format_Float (Float (T.Brake_Pct)) & "%", FG => Color_Bright_White);

         -- Location and Odometry Status
         Put_String (C, Top_Row + 9, Left_Col + 3, "CHAINAGE : KM " & Format_Float (Float (T.Chainage_Km), 3), FG => Color_Bright_Cyan);
         if T.Wheel_Slip then
            Put_String (C, Top_Row + 9, Left_Col + 30, "[WHEEL SLIP DETECTED]", FG => Color_Bright_Yellow, Bold => True);
         elsif T.Emergency_Brake then
            Put_String (C, Top_Row + 9, Left_Col + 30, "[EMERGENCY BRAKE TRIPPED]", FG => Color_Bright_Red, Bold => True);
         else
            Put_String (C, Top_Row + 9, Left_Col + 30, "[ODOMETRY FUSION OK]", FG => Color_Bright_Green);
         end if;
      end;
   end Render_DMI;

end Aspect.TUI.DMI;
