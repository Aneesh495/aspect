package body Aspect.ETCS is

   function Scale_To_Distance
     (Raw_Value : Natural;
      Scale     : Q_SCALE_Type) return Distance_M
   is
      Val_F : constant Float := Float (Raw_Value);
      D     : Float;
   begin
      case Scale is
         when Q_SCALE_10cm =>
            D := Val_F * 0.1;
         when Q_SCALE_1m =>
            D := Val_F * 1.0;
         when Q_SCALE_10m =>
            D := Val_F * 10.0;
      end case;

      if D > 100_000.0 then
         return 100_000.0;
      else
         return Distance_M (D);
      end if;
   end Scale_To_Distance;

end Aspect.ETCS;
