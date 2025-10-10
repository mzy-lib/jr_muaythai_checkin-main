-- Fix time slot to class_type mapping
BEGIN;

-- Update the function to properly map time slots to class types
CREATE OR REPLACE FUNCTION get_class_type_from_time_slot(p_time_slot text)
RETURNS class_type
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- For group classes, use exact time slots
  IF p_time_slot = '09:00-10:30' THEN
    RETURN 'morning'::class_type;
  ELSIF p_time_slot = '17:00-18:30' THEN
    RETURN 'evening'::class_type;
  END IF;
  
  -- For private classes, determine based on hour
  DECLARE
    v_hour integer;
  BEGIN
    v_hour := CAST(split_part(p_time_slot, ':', 1) AS integer);
    RETURN CASE 
      WHEN v_hour >= 7 AND v_hour < 12 THEN 'morning'::class_type
      ELSE 'evening'::class_type
    END;
  END;
END;
$$;

-- Update existing check-ins to fix class_type
UPDATE check_ins
SET class_type = get_class_type_from_time_slot(time_slot)
WHERE time_slot IS NOT NULL;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_class_type_from_time_slot(text) TO public;

COMMIT; 