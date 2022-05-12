-- Implementation of signal aspects and route state renderer.

with Aspect.Types; use Aspect.Types;

package body Aspect.TUI.Signals is

   function Aspect_FG (A : Signal_Aspect) return Color_Type is
   begin
      case A is
         when Aspect_Stop =>
            return Color_Bright_Red;
         when Aspect_Caution | Aspect_Preliminary_Caution =>
            return Color_Bright_Yellow;
         when Aspect_Clear =>
            return Color_Bright_Green;
         when Aspect_Shunt =>
            return Color_Bright_White;
         when Aspect_Dark =>
            return Color_Dim_White;
      end case;
   end Aspect_FG;

   function Aspect_Name (A : Signal_Aspect) return String is
   begin
      case A is
         when Aspect_Stop =>
            return "STOP       ";
         when Aspect_Caution =>
            return "CAUTION    ";
         when Aspect_Preliminary_Caution =>
            return "PRE-CAUTION";
         when Aspect_Clear =>
            return "CLEAR      ";
         when Aspect_Shunt =>
            return "SHUNT      ";
         when Aspect_Dark =>
            return "DARK (FAIL)";
      end case;
   end Aspect_Name;

   function Route_State_Name (S : Route_State) return String is
   begin
      case S is
         when Route_Unset =>
            return "UNSET      ";
         when Route_Requested =>
            return "REQUESTED  ";
         when Route_Interlocked =>
            return "INTERLOCKED";
         when Route_Cleared =>
            return "CLEARED    ";
         when Route_Approached =>
            return "APPROACHED ";
         when Route_Occupied =>
            return "OCCUPIED   ";
         when Route_Sectional_Release =>
            return "SEC_RELEASE";
         when Route_Released =>
            return "RELEASED   ";
         when Route_Cancelled =>
            return "CANCELLED  ";
      end case;
   end Route_State_Name;

   procedure Render_Signals_And_Routes
     (C        : in out Terminal_Canvas;
      Snapshot : Telemetry_Snapshot;
      Top_Row  : Positive := 13;
      Left_Col : Positive := 2)
   is
      Panel_Width : constant Positive := 57;
      Height      : constant Positive := 11;
   begin
      -- Left Box: Signals
      Draw_Box
        (C      => C,
         Top    => Top_Row,
         Left   => Left_Col,
         Height => Height,
         Width  => Panel_Width,
         Title  => "LINESIDE SIGNALS & LAMP FILAMENTS",
         FG     => Color_Bright_Cyan,
         Bold   => True);

      Put_String (C, Top_Row + 2, Left_Col + 3,
                  "SIGNAL   LAMP HEADS   ASPECT       CURRENT  HEALTH",
                  FG => Color_Dim_White, Bold => True);

      for I in 1 .. Natural'Min (Snapshot.Signal_Count, 6) loop
         declare
            Sig     : constant Signal_Telemetry := Snapshot.Signals (I);
            Row_Pos : constant Positive := Top_Row + 2 + I;
            Id_Str  : constant String := "SIG-0" & Character'Val (Character'Pos ('0') + I);
            A_Color : constant Color_Type := Aspect_FG (Sig.Aspect);
         begin
            Put_String (C, Row_Pos, Left_Col + 3, Id_Str, FG => Color_Bright_White);

            -- Visual Lamp Head
            case Sig.Aspect is
               when Aspect_Clear =>
                  Put_String (C, Row_Pos, Left_Col + 12, "[G]", FG => Color_Bright_Green, Bold => True);
               when Aspect_Caution =>
                  Put_String (C, Row_Pos, Left_Col + 12, "[Y]", FG => Color_Bright_Yellow, Bold => True);
               when Aspect_Preliminary_Caution =>
                  Put_String (C, Row_Pos, Left_Col + 12, "[YY]", FG => Color_Bright_Yellow, Bold => True);
               when Aspect_Stop =>
                  Put_String (C, Row_Pos, Left_Col + 12, "[R]", FG => Color_Bright_Red, Bold => True);
               when others =>
                  Put_String (C, Row_Pos, Left_Col + 12, "[?]", FG => Color_Dim_White);
            end case;

            Put_String (C, Row_Pos, Left_Col + 25, Aspect_Name (Sig.Aspect), FG => A_Color, Bold => True);
            Put_String (C, Row_Pos, Left_Col + 38, "250.0 mA", FG => Color_Dim_White);

            if Sig.Lamp_Fault then
               Put_String (C, Row_Pos, Left_Col + 47, "BLOWN", FG => Color_Bright_Red, Bold => True);
            else
               Put_String (C, Row_Pos, Left_Col + 47, "NOMINAL", FG => Color_Bright_Green);
            end if;
         end;
      end loop;

      -- Right Box: Interlocking Routes
      Draw_Box
        (C      => C,
         Top    => Top_Row,
         Left   => Left_Col + Panel_Width + 2,
         Height => Height,
         Width  => Panel_Width,
         Title  => "GEOGRAPHIC INTERLOCKING ROUTES",
         FG     => Color_Bright_Cyan,
         Bold   => True);

      Put_String (C, Top_Row + 2, Left_Col + Panel_Width + 5,
                  "ROUTE  LIFECYCLE STATE  ENTRY   EXIT    TRAIN",
                  FG => Color_Dim_White, Bold => True);

      for I in 1 .. Natural'Min (Snapshot.Route_Count, 6) loop
         declare
            R       : constant Route_Telemetry := Snapshot.Routes (I);
            Row_Pos : constant Positive := Top_Row + 2 + I;
            Id_Str  : constant String := "R-0" & Character'Val (Character'Pos ('0') + I);
            St_Col  : constant Color_Type :=
              (if R.State = Route_Interlocked or else R.State = Route_Cleared then Color_Bright_Green
               elsif R.State = Route_Requested or else R.State = Route_Approached then Color_Bright_Yellow
               elsif R.State = Route_Cancelled then Color_Bright_Red
               else Color_Dim_White);
         begin
            Put_String (C, Row_Pos, Left_Col + Panel_Width + 5, Id_Str, FG => Color_Bright_White);
            Put_String (C, Row_Pos, Left_Col + Panel_Width + 12, Route_State_Name (R.State), FG => St_Col, Bold => True);
            Put_String (C, Row_Pos, Left_Col + Panel_Width + 29, "SIG-01", FG => Color_Dim_White);
            Put_String (C, Row_Pos, Left_Col + Panel_Width + 37, "SIG-02", FG => Color_Dim_White);
            Put_String (C, Row_Pos, Left_Col + Panel_Width + 45, "TR-01", FG => Color_Bright_Cyan);
         end;
      end loop;

   end Render_Signals_And_Routes;

end Aspect.TUI.Signals;
