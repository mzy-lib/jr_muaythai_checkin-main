-- Add monthly membership handling to process_check_in function
BEGIN;

CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
BEGIN
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
      WHEN NOT NEW.is_extra 
        AND membership IN ('single_monthly', 'double_monthly')
      THEN COALESCE(daily_check_ins, 0) + 1
      ELSE daily_check_ins
    END,
    -- Reset daily check-ins if it's a new day
    daily_check_ins = CASE
      WHEN membership IN ('single_monthly', 'double_monthly')
        AND (last_check_in_date IS NULL OR last_check_in_date < CURRENT_DATE)
      THEN 1
      ELSE daily_check_ins
    END,
    -- Update last check-in date
    last_check_in_date = CURRENT_DATE,
    -- Always update new member status after check-in
    is_new_member = false
  WHERE id = NEW.member_id;

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