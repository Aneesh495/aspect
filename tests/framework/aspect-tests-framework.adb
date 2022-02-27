with Ada.Text_IO; use Ada.Text_IO;

package body Aspect.Tests.Framework is

   ANSI_Green : constant String := Character'Val (27) & "[32m";
   ANSI_Red   : constant String := Character'Val (27) & "[31m";
   ANSI_Bold  : constant String := Character'Val (27) & "[1m";
   ANSI_Reset : constant String := Character'Val (27) & "[0m";

   ----------------------------------------------------------------------------
   -- Initialization
   ----------------------------------------------------------------------------

   procedure Init_Context (Ctx : out Test_Context; Suite_Name : String) is
      Len : constant Natural := Natural'Min (Suite_Name'Length, 64);
   begin
      Ctx.Suite_Name := [others => ' '];
      Ctx.Suite_Name (1 .. Len) := Suite_Name (Suite_Name'First .. Suite_Name'First + Len - 1);
      Ctx.Name_Length  := Len;
      Ctx.Passed_Tests := 0;
      Ctx.Failed_Tests := 0;
      Put_Line (ANSI_Bold & "[SUITE] " & ANSI_Reset & Ctx.Suite_Name (1 .. Len));
   end Init_Context;

   ----------------------------------------------------------------------------
   -- Assertions
   ----------------------------------------------------------------------------

   procedure Assert
     (Ctx     : in out Test_Context;
      Cond    : Boolean;
      Message : String)
   is
   begin
      if Cond then
         Ctx.Passed_Tests := Ctx.Passed_Tests + 1;
      else
         Ctx.Failed_Tests := Ctx.Failed_Tests + 1;
         Put_Line (ANSI_Red & "  [FAIL] " & ANSI_Reset & Message);
      end if;
   end Assert;

   procedure Assert_Equal_Int
     (Ctx      : in out Test_Context;
      Expected : Long_Long_Integer;
      Actual   : Long_Long_Integer;
      Message  : String)
   is
   begin
      if Expected = Actual then
         Ctx.Passed_Tests := Ctx.Passed_Tests + 1;
      else
         Ctx.Failed_Tests := Ctx.Failed_Tests + 1;
         Put_Line (ANSI_Red & "  [FAIL] " & ANSI_Reset & Message &
                   " (Expected: " & Long_Long_Integer'Image (Expected) &
                   ", Actual: " & Long_Long_Integer'Image (Actual) & ")");
      end if;
   end Assert_Equal_Int;

   procedure Assert_Equal_Str
     (Ctx      : in out Test_Context;
      Expected : String;
      Actual   : String;
      Message  : String)
   is
   begin
      if Expected = Actual then
         Ctx.Passed_Tests := Ctx.Passed_Tests + 1;
      else
         Ctx.Failed_Tests := Ctx.Failed_Tests + 1;
         Put_Line (ANSI_Red & "  [FAIL] " & ANSI_Reset & Message &
                   " (Expected: '" & Expected & "', Actual: '" & Actual & "')");
      end if;
   end Assert_Equal_Str;

   procedure Assert_Within_Float
     (Ctx       : in out Test_Context;
      Expected  : Float;
      Actual    : Float;
      Tolerance : Float;
      Message   : String)
   is
      Diff : constant Float := abs (Expected - Actual);
   begin
      if Diff <= Tolerance then
         Ctx.Passed_Tests := Ctx.Passed_Tests + 1;
      else
         Ctx.Failed_Tests := Ctx.Failed_Tests + 1;
         Put_Line (ANSI_Red & "  [FAIL] " & ANSI_Reset & Message &
                   " (Expected: " & Float'Image (Expected) &
                   ", Actual: " & Float'Image (Actual) &
                   ", Diff: " & Float'Image (Diff) &
                   ", Tol: " & Float'Image (Tolerance) & ")");
      end if;
   end Assert_Within_Float;

   ----------------------------------------------------------------------------
   -- Summary and Reporting
   ----------------------------------------------------------------------------

   function Summarize (Ctx : Test_Context) return Boolean is
      Total : constant Natural := Ctx.Passed_Tests + Ctx.Failed_Tests;
      Name  : constant String  := Ctx.Suite_Name (1 .. Ctx.Name_Length);
   begin
      if Ctx.Failed_Tests = 0 then
         Put_Line (ANSI_Green & "  [PASS] " & ANSI_Reset & Name &
                   " (" & Natural'Image (Ctx.Passed_Tests) & "/" & Natural'Image (Total) & " assertions)");
         return True;
      else
         Put_Line (ANSI_Red & "  [FAIL] " & ANSI_Reset & Name &
                   " (" & Natural'Image (Ctx.Failed_Tests) & " failed out of " & Natural'Image (Total) & ")");
         return False;
      end if;
   end Summarize;

   function Passed_Count (Ctx : Test_Context) return Natural is
   begin
      return Ctx.Passed_Tests;
   end Passed_Count;

   function Failed_Count (Ctx : Test_Context) return Natural is
   begin
      return Ctx.Failed_Tests;
   end Failed_Count;

end Aspect.Tests.Framework;
