-- Lightweight high-assurance test harness for Aspect.
-- Provides deterministic assertion tracking, edge case reporting,
-- and regression suite aggregation without third-party dependencies.

package Aspect.Tests.Framework is

   type Test_Result is (Test_Pass, Test_Fail, Test_Skip);

   type Test_Context is limited private;

   -- Initializes a new test reporting context
   procedure Init_Context (Ctx : out Test_Context; Suite_Name : String);

   -- Basic Boolean assertion with failure logging
   procedure Assert
     (Ctx     : in out Test_Context;
      Cond    : Boolean;
      Message : String);

   -- Equality assertion for integers
   procedure Assert_Equal_Int
     (Ctx      : in out Test_Context;
      Expected : Long_Long_Integer;
      Actual   : Long_Long_Integer;
      Message  : String);

   -- Equality assertion for discrete strings
   procedure Assert_Equal_Str
     (Ctx      : in out Test_Context;
      Expected : String;
      Actual   : String;
      Message  : String);

   -- Approximate float assertion within given tolerance epsilon
   procedure Assert_Within_Float
     (Ctx       : in out Test_Context;
      Expected  : Float;
      Actual    : Float;
      Tolerance : Float;
      Message   : String);

   -- Summarizes results for the current suite and prints terminal status
   function Summarize (Ctx : Test_Context) return Boolean;

   function Passed_Count (Ctx : Test_Context) return Natural;
   function Failed_Count (Ctx : Test_Context) return Natural;

private

   type Test_Context is record
      Suite_Name   : String (1 .. 64) := [others => ' '];
      Name_Length  : Natural := 0;
      Passed_Tests : Natural := 0;
      Failed_Tests : Natural := 0;
   end record;

end Aspect.Tests.Framework;
