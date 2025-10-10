-- Fix time_slot to class_type conversion
BEGIN;

-- Update the function to properly handle afternoon time slots
CREATE OR REPLACE FUNCTION get_class_type_from_time_slot(p_time_slot text)
RETURNS class_type
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_hour integer;
BEGIN
  -- Extract the hour from the start time
  v_hour := CAST(split_part(p_time_slot, ':', 1) AS integer);
  
  -- Determine class type based on hour
  -- Morning: 07:00-11:59
  -- Evening: 12:00-22:00
  RETURN CASE 
    WHEN v_hour >= 7 AND v_hour < 12 THEN 'morning'::class_type
    WHEN v_hour >= 12 THEN 'evening'::class_type
    ELSE 'morning'::class_type  -- Default for early morning hours (before 7am)
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