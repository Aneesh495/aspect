-- Implementation of terminal track schematic renderer.

with Aspect.Types; use Aspect.Types;

package body Aspect.TUI.Track is

   function Section_Color (Sec : Track_Telemetry) return Color_Type is
   begin
      if Sec.Is_Occupied then
         return Color_Bright_Red;
      elsif Sec.Is_Locked then
         return Color_Bright_Yellow;
      else
         return Color_Bright_Green;
      end if;
   end Section_Color;

   function Switch_Color (Sw : Switch_Telemetry) return Color_Type is
   begin
      if Sw.Motor_Stalled or else Sw.Trail_Through then
         return Color_Bright_Red;
      elsif Sw.Position = Switch_Reverse then
         return Color_Bright_Yellow;
      else
         return Color_Bright_Cyan;
      end if;
   end Switch_Color;

   procedure Render_Track_Layout
     (C        : in out Terminal_Canvas;
      Snapshot : Telemetry_Snapshot;
      Top_Row  : Positive := 2;
      Left_Col : Positive := 2)
   is
      Box_Width  : constant Positive := 116;
      Box_Height : constant Positive := 10;
   begin
      Draw_Box
        (C      => C,
         Top    => Top_Row,
         Left   => Left_Col,
         Height => Box_Height,
         Width  => Box_Width,
         Title  => "SCHEMATIC TRACK TOPOLOGY & POINT TURNOUTS",
         FG     => Color_Cyan,
         Bold   => True);

      -- Schematic Track Diagrams
      -- Row 1: Mainline Track Corridor
      Put_String (C, Top_Row + 2, Left_Col + 3, "MAINLINE : ", FG => Color_Bright_White, Bold => True);

      -- Section 1
      declare
         Col1 : constant Color_Type :=
           (if Snapshot.Section_Count >= 1 then Section_Color (Snapshot.Sections (1)) else Color_Green);
      begin
         Put_String (C, Top_Row + 2, Left_Col + 14, "====[ S01 ]====", FG => Col1, Bold => True);
      end;

      -- Turnout 1
      declare
         Sw_Col1 : constant Color_Type :=
           (if Snapshot.Switch_Count >= 1 then Switch_Color (Snapshot.Switches (1)) else Color_Cyan);
         Sw_Pos1 : constant String :=
           (if Snapshot.Switch_Count >= 1 and then Snapshot.Switches (1).Position = Switch_Reverse
            then "[SW1:REV]" else "[SW1:NORM]");
      begin
         Put_String (C, Top_Row + 2, Left_Col + 30, Sw_Pos1, FG => Sw_Col1, Bold => True);
      end;

      -- Section 2
      declare
         Col2 : constant Color_Type :=
           (if Snapshot.Section_Count >= 2 then Section_Color (Snapshot.Sections (2)) else Color_Green);
      begin
         Put_String (C, Top_Row + 2, Left_Col + 41, "====[ S02 ]====", FG => Col2, Bold => True);
      end;

      -- Turnout 2
      declare
         Sw_Col2 : constant Color_Type :=
           (if Snapshot.Switch_Count >= 2 then Switch_Color (Snapshot.Switches (2)) else Color_Cyan);
         Sw_Pos2 : constant String :=
           (if Snapshot.Switch_Count >= 2 and then Snapshot.Switches (2).Position = Switch_Reverse
            then "[SW2:REV]" else "[SW2:NORM]");
      begin
         Put_String (C, Top_Row + 2, Left_Col + 57, Sw_Pos2, FG => Sw_Col2, Bold => True);
      end;

      -- Section 3
      declare
         Col3 : constant Color_Type :=
           (if Snapshot.Section_Count >= 3 then Section_Color (Snapshot.Sections (3)) else Color_Green);
      begin
         Put_String (C, Top_Row + 2, Left_Col + 68, "====[ S03 ]====", FG => Col3, Bold => True);
      end;

      -- Row 2: Diverging Turnout Siding Track Corridor
      Put_String (C, Top_Row + 4, Left_Col + 3, "SIDING   : ", FG => Color_Bright_White, Bold => True);
      Put_String (C, Top_Row + 3, Left_Col + 34, "\\", FG => Color_Bright_Yellow);
      Put_String (C, Top_Row + 3, Left_Col + 61, "/", FG => Color_Bright_Yellow);

      -- Section 4 (Siding track)
      declare
         Col4 : constant Color_Type :=
           (if Snapshot.Section_Count >= 4 then Section_Color (Snapshot.Sections (4)) else Color_Green);
      begin
         Put_String (C, Top_Row + 4, Left_Col + 36, "=======[ S04: LOOP ]=======", FG => Col4, Bold => True);
      end;

      -- Track Circuit Status Table
      Put_String (C, Top_Row + 6, Left_Col + 3,
                  "SEC  STATE     LOCK    AXLES   BALLAST     |  SWITCH  POSITION  LOCK    STATUS",
                  FG => Color_Dim_White, Bold => True);

      for I in 1 .. Natural'Min (Snapshot.Section_Count, 2) loop
         declare
            Sec     : constant Track_Telemetry := Snapshot.Sections (I);
            Row_Pos : constant Positive := Top_Row + 6 + I;
            Id_Str  : constant String := "S0" & Character'Val (Character'Pos ('0') + I);
            St_Str  : constant String := (if Sec.Is_Occupied then "OCCUPIED" else "CLEAR   ");
            Lk_Str  : constant String := (if Sec.Is_Locked then "LOCKED" else "FREE  ");
         begin
            Put_String (C, Row_Pos, Left_Col + 3, Id_Str, FG => Color_Bright_White);
            Put_String (C, Row_Pos, Left_Col + 8, St_Str, FG => (if Sec.Is_Occupied then Color_Bright_Red else Color_Bright_Green));
            Put_String (C, Row_Pos, Left_Col + 18, Lk_Str, FG => (if Sec.Is_Locked then Color_Bright_Yellow else Color_Dim_White));
            Put_String (C, Row_Pos, Left_Col + 26, Natural'Image (Sec.Axle_Count), FG => Color_Bright_White);
            Put_String (C, Row_Pos, Left_Col + 34, "500.0 Ohm", FG => Color_Dim_White);
         end;
      end loop;

      -- Switch Status Rows
      for I in 1 .. Natural'Min (Snapshot.Switch_Count, 2) loop
         declare
            Sw      : constant Switch_Telemetry := Snapshot.Switches (I);
            Row_Pos : constant Positive := Top_Row + 6 + I;
            Id_Str  : constant String := "SW-0" & Character'Val (Character'Pos ('0') + I);
            Pos_Str : constant String := (if Sw.Position = Switch_Reverse then "REVERSE" else "NORMAL ");
            Lk_Str  : constant String := (if Sw.Is_Locked then "LOCKED" else "FREE  ");
            Flt_Str : constant String := (if Sw.Motor_Stalled then "STALL"
                                         elsif Sw.Trail_Through then "TRAILED"
                                         else "NOMINAL");
         begin
            Put_String (C, Row_Pos, Left_Col + 49, Id_Str, FG => Color_Bright_White);
            Put_String (C, Row_Pos, Left_Col + 57, Pos_Str, FG => (if Sw.Position = Switch_Reverse then Color_Bright_Yellow else Color_Bright_Cyan));
            Put_String (C, Row_Pos, Left_Col + 67, Lk_Str, FG => (if Sw.Is_Locked then Color_Bright_Yellow else Color_Dim_White));
            Put_String (C, Row_Pos, Left_Col + 75, Flt_Str, FG => (if Flt_Str = "NOMINAL" then Color_Bright_Green else Color_Bright_Red));
         end;
      end loop;

   end Render_Track_Layout;

end Aspect.TUI.Track;
