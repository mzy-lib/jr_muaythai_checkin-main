-- Fix membership type handling in process_check_in function
BEGIN;

CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
DECLARE
  v_member RECORD;
BEGIN
  -- Get current member status
  SELECT *
  INTO v_member
  FROM members
  WHERE id = NEW.member_id
  FOR UPDATE;

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
    -- Update daily check-ins for monthly memberships
    daily_check_ins = CASE
      WHEN membership IN ('single_monthly', 'double_monthly')
      THEN
        CASE
          -- Reset counter if it's a new day
          WHEN last_check_in_date IS NULL OR last_check_in_date < CURRENT_DATE THEN 1
          -- Increment counter for same day check-ins
          ELSE COALESCE(daily_check_ins, 0) + 1
        END
      ELSE daily_check_ins
    END,
    -- Update last check-in date
    last_check_in_date = CURRENT_DATE,
    -- Always update new member status after check-in
    is_new_member = false
  WHERE id = NEW.member_id;

  -- Log the update for debugging
  RAISE NOTICE 'Member updated - ID: %, Type: %, Daily Check-ins: %, Is Extra: %', 
    v_member.id, v_member.membership, v_member.daily_check_ins, NEW.is_extra;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add new columns for monthly membership tracking if they don't exist
DO $$ 
BEGIN
  BEGIN
    ALTER TABLE members ADD COLUMN daily_check_ins integer DEFAULT 0;
  EXCEPTION
    WHEN duplicate_column THEN NULL;
  END;
  
  BEGIN
    ALTER TABLE members ADD COLUMN last_check_in_date date;
  EXCEPTION
    WHEN duplicate_column THEN NULL;
  END;
END $$;

COMMIT;