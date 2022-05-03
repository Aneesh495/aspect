-- Implementation of ANSI/VT100 terminal canvas.

with Ada.Text_IO;

package body Aspect.TUI.Canvas is

   procedure Clear (C : in out Terminal_Canvas) is
   begin
      for R in 1 .. Canvas_Rows loop
         for Col in 1 .. Canvas_Cols loop
            C.Grid (R, Col) := (Char => ' ', FG => Color_Default, BG => Color_Default, Bold => False);
         end loop;
      end loop;
   end Clear;

   procedure Put_Char
     (C    : in out Terminal_Canvas;
      Row  : Positive;
      Col  : Positive;
      Ch   : Character;
      FG   : Color_Type := Color_Default;
      BG   : Color_Type := Color_Default;
      Bold : Boolean    := False)
   is
   begin
      if Row in 1 .. Canvas_Rows and then Col in 1 .. Canvas_Cols then
         C.Grid (Row, Col) := (Char => Ch, FG => FG, BG => BG, Bold => Bold);
      end if;
   end Put_Char;

   procedure Put_String
     (C    : in out Terminal_Canvas;
      Row  : Positive;
      Col  : Positive;
      Str  : String;
      FG   : Color_Type := Color_Default;
      BG   : Color_Type := Color_Default;
      Bold : Boolean    := False)
   is
      Current_Col : Natural := Col;
   begin
      if Row not in 1 .. Canvas_Rows then
         return;
      end if;

      for I in Str'Range loop
         exit when Current_Col > Canvas_Cols;
         C.Grid (Row, Current_Col) := (Char => Str (I), FG => FG, BG => BG, Bold => Bold);
         Current_Col := Current_Col + 1;
      end loop;
   end Put_String;

   procedure Draw_Box
     (C      : in out Terminal_Canvas;
      Top    : Positive;
      Left   : Positive;
      Height : Positive;
      Width  : Positive;
      Title  : String     := "";
      FG     : Color_Type := Color_Cyan;
      Bold   : Boolean    := False)
   is
      Bottom : constant Natural := Top + Height - 1;
      Right  : constant Natural := Left + Width - 1;
   begin
      if Top not in 1 .. Canvas_Rows or else Bottom > Canvas_Rows or else
         Left not in 1 .. Canvas_Cols or else Right > Canvas_Cols
      then
         return;
      end if;

      -- Corners
      Put_Char (C, Top, Left, '+', FG => FG, Bold => Bold);
      Put_Char (C, Top, Right, '+', FG => FG, Bold => Bold);
      Put_Char (C, Bottom, Left, '+', FG => FG, Bold => Bold);
      Put_Char (C, Bottom, Right, '+', FG => FG, Bold => Bold);

      -- Top and bottom horizontal borders
      for Col in Left + 1 .. Right - 1 loop
         Put_Char (C, Top, Col, '-', FG => FG, Bold => Bold);
         Put_Char (C, Bottom, Col, '-', FG => FG, Bold => Bold);
      end loop;

      -- Left and right vertical borders
      for Row in Top + 1 .. Bottom - 1 loop
         Put_Char (C, Row, Left, '|', FG => FG, Bold => Bold);
         Put_Char (C, Row, Right, '|', FG => FG, Bold => Bold);
      end loop;

      -- Optional Title
      if Title'Length > 0 and then Width > Title'Length + 4 then
         Put_Char (C, Top, Left + 2, '[', FG => FG, Bold => Bold);
         Put_String (C, Top, Left + 3, Title, FG => Color_Bright_White, Bold => True);
         Put_Char (C, Top, Left + 3 + Title'Length, ']', FG => FG, Bold => Bold);
      end if;
   end Draw_Box;

   procedure Fill_Rect
     (C      : in out Terminal_Canvas;
      Top    : Positive;
      Left   : Positive;
      Height : Positive;
      Width  : Positive;
      Ch     : Character  := ' ';
      FG     : Color_Type := Color_Default;
      BG     : Color_Type := Color_Default)
   is
      Bottom : constant Natural := Top + Height - 1;
      Right  : constant Natural := Left + Width - 1;
   begin
      for R in Top .. Natural'Min (Bottom, Canvas_Rows) loop
         for Col in Left .. Natural'Min (Right, Canvas_Cols) loop
            Put_Char (C, R, Col, Ch, FG => FG, BG => BG);
         end loop;
      end loop;
   end Fill_Rect;

   function FG_To_ANSI (FG : Color_Type) return String is
   begin
      case FG is
         when Color_Default        => return "39";
         when Color_Black          => return "30";
         when Color_Red            => return "31";
         when Color_Green          => return "32";
         when Color_Yellow         => return "33";
         when Color_Blue           => return "34";
         when Color_Magenta        => return "35";
         when Color_Cyan           => return "36";
         when Color_White          => return "37";
         when Color_Bright_Red     => return "91";
         when Color_Bright_Green   => return "92";
         when Color_Bright_Yellow  => return "93";
         when Color_Bright_Blue    => return "94";
         when Color_Bright_Magenta => return "95";
         when Color_Bright_Cyan    => return "96";
         when Color_Bright_White   => return "97";
         when Color_Dim_White      => return "2;37";
      end case;
   end FG_To_ANSI;

   function BG_To_ANSI (BG : Color_Type) return String is
   begin
      case BG is
         when Color_Default => return "49";
         when Color_Black   => return "40";
         when Color_Red     => return "41";
         when Color_Green   => return "42";
         when Color_Yellow  => return "43";
         when Color_Blue    => return "44";
         when Color_Magenta => return "45";
         when Color_Cyan    => return "46";
         when Color_White   => return "47";
         when others        => return "49";
      end case;
   end BG_To_ANSI;

   procedure Render_Screen
     (C            : Terminal_Canvas;
      Clear_Screen : Boolean := False)
   is
      ESC : constant Character := Character'Val (27);
      Last_FG   : Color_Type := Color_Default;
      Last_BG   : Color_Type := Color_Default;
      Last_Bold : Boolean    := False;
   begin
      if Clear_Screen then
         Ada.Text_IO.Put (ESC & "[2J");
      end if;

      -- Move cursor to top-left (1,1)
      Ada.Text_IO.Put (ESC & "[H");

      for R in 1 .. Canvas_Rows loop
         for Col in 1 .. Canvas_Cols loop
            declare
               Cell_Ref : constant Cell := C.Grid (R, Col);
            begin
               if Cell_Ref.FG /= Last_FG or else
                  Cell_Ref.BG /= Last_BG or else
                  Cell_Ref.Bold /= Last_Bold
               then
                  Ada.Text_IO.Put (ESC & "[0;");
                  if Cell_Ref.Bold then
                     Ada.Text_IO.Put ("1;");
                  end if;
                  Ada.Text_IO.Put (FG_To_ANSI (Cell_Ref.FG) & ";" &
                                   BG_To_ANSI (Cell_Ref.BG) & "m");
                  Last_FG   := Cell_Ref.FG;
                  Last_BG   := Cell_Ref.BG;
                  Last_Bold := Cell_Ref.Bold;
               end if;

               Ada.Text_IO.Put (Cell_Ref.Char);
            end;
         end loop;
         Ada.Text_IO.New_Line;
      end loop;

      -- Reset terminal attributes
      Ada.Text_IO.Put (ESC & "[0m");
      Ada.Text_IO.Flush;
   end Render_Screen;

end Aspect.TUI.Canvas;
