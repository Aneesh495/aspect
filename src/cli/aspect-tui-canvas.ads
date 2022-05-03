-- High-performance ANSI/VT100 terminal canvas and box drawing engine.
-- Provides deterministic double-buffered screen rendering for the Aspect TUI.

package Aspect.TUI.Canvas is

   Canvas_Rows : constant := 36;
   Canvas_Cols : constant := 120;

   type Color_Type is (
      Color_Default,
      Color_Black,
      Color_Red,
      Color_Green,
      Color_Yellow,
      Color_Blue,
      Color_Magenta,
      Color_Cyan,
      Color_White,
      Color_Bright_Red,
      Color_Bright_Green,
      Color_Bright_Yellow,
      Color_Bright_Blue,
      Color_Bright_Magenta,
      Color_Bright_Cyan,
      Color_Bright_White,
      Color_Dim_White
   );

   type Cell is record
      Char : Character  := ' ';
      FG   : Color_Type := Color_Default;
      BG   : Color_Type := Color_Default;
      Bold : Boolean    := False;
   end record;

   type Cell_Grid is array (1 .. Canvas_Rows, 1 .. Canvas_Cols) of Cell;

   type Terminal_Canvas is record
      Grid : Cell_Grid;
   end record;

   -- Resets all canvas cells to empty space with default attributes
   procedure Clear (C : in out Terminal_Canvas);

   -- Places a single character at (Row, Col)
   procedure Put_Char
     (C    : in out Terminal_Canvas;
      Row  : Positive;
      Col  : Positive;
      Ch   : Character;
      FG   : Color_Type := Color_Default;
      BG   : Color_Type := Color_Default;
      Bold : Boolean    := False);

   -- Renders a text string at (Row, Col)
   procedure Put_String
     (C    : in out Terminal_Canvas;
      Row  : Positive;
      Col  : Positive;
      Str  : String;
      FG   : Color_Type := Color_Default;
      BG   : Color_Type := Color_Default;
      Bold : Boolean    := False);

   -- Draws an outlined rectangular box with optional title
   procedure Draw_Box
     (C      : in out Terminal_Canvas;
      Top    : Positive;
      Left   : Positive;
      Height : Positive;
      Width  : Positive;
      Title  : String     := "";
      FG     : Color_Type := Color_Cyan;
      Bold   : Boolean    := False);

   -- Fills a rectangular region with a given character and background
   procedure Fill_Rect
     (C      : in out Terminal_Canvas;
      Top    : Positive;
      Left   : Positive;
      Height : Positive;
      Width  : Positive;
      Ch     : Character  := ' ';
      FG     : Color_Type := Color_Default;
      BG     : Color_Type := Color_Default);

   -- Emits ANSI escape sequence buffer to stdout
   procedure Render_Screen
     (C            : Terminal_Canvas;
      Clear_Screen : Boolean := False);

end Aspect.TUI.Canvas;
