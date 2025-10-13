-- Add debug logging to process_check_in function
BEGIN;

CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
BEGIN
  -- Log trigger execution
  RAISE NOTICE 'process_check_in triggered for member_id: %, is_extra: %', NEW.member_id, NEW.is_extra;

  -- Update member information
  UPDATE members
  SET
    -- Decrement remaining classes for class-based memberships
    remaining_classes = CASE 
      WHEN NOT NEW.is_extra 
        AND membership IN ('single_class', 'two_classes', 'ten_classes') 
      THEN remaining_classes - 1
      ELSE remaining_classes
    END,
    -- Increment extra check-ins counter
    extra_check_ins = CASE 
      WHEN NEW.is_extra 
      THEN extra_check_ins + 1
      ELSE extra_check_ins
    END,
    -- Always update new member status after check-in
    is_new_member = false
  WHERE id = NEW.member_id
  RETURNING id, membership, remaining_classes, is_new_member, extra_check_ins;

  -- Log the update result
  RAISE NOTICE 'Member updated: %', FOUND;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMIT; 