-- Update check-in related triggers
BEGIN;

-- 1. Update check_in_logging trigger function
CREATE OR REPLACE FUNCTION check_in_logging()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member RECORD;
  v_card RECORD;
  v_trainer RECORD;
BEGIN
  -- Get member info
  SELECT name, email INTO v_member
  FROM members
  WHERE id = NEW.member_id;

  -- Get card info if exists
  SELECT id, card_type, card_category, card_subtype
  INTO v_card
  FROM membership_cards
  WHERE id = NEW.card_id;

  -- Get trainer info if exists
  SELECT name, type INTO v_trainer
  FROM trainers
  WHERE id = NEW.trainer_id;

  -- Log check-in details
  INSERT INTO check_in_logs (
    check_in_id,
    details,
    created_at
  ) VALUES (
    NEW.id,
    jsonb_build_object(
      'member_name', v_member.name,
      'member_email', v_member.email,
      'check_in_date', NEW.check_in_date,
      'time_slot', NEW.time_slot,
      'is_extra', NEW.is_extra,
      'is_private', NEW.is_private,
      'is_1v2', NEW.is_1v2,
      'card_id', NEW.card_id,
      'card_info', CASE WHEN v_card.id IS NOT NULL THEN 
        jsonb_build_object(
          'card_type', v_card.card_type,
          'card_category', v_card.card_category,
          'card_subtype', v_card.card_subtype
        )
      ELSE NULL END,
      'trainer_info', CASE WHEN v_trainer.name IS NOT NULL THEN
        jsonb_build_object(
          'name', v_trainer.name,
          'type', v_trainer.type
        )
      ELSE NULL END
    ),
    NOW()
  );

  RETURN NEW;
END;
$$;

-- 2. Update check_in_validation trigger function
CREATE OR REPLACE FUNCTION check_in_validation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing_check_in RECORD;
  v_time_slot text;
BEGIN
  -- Check for duplicate check-in
  SELECT id, time_slot, is_private
  INTO v_existing_check_in
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = NEW.check_in_date
    AND time_slot = NEW.time_slot
    AND is_private = NEW.is_private;

  IF FOUND THEN
    IF v_existing_check_in.is_private THEN
      RAISE EXCEPTION '今天已经签到过这个时段的私教课。Already checked in for this private class time slot today.'
        USING HINT = 'duplicate_checkin';
    ELSE
      RAISE EXCEPTION '今天已经签到过这个时段的课程。Already checked in for this time slot today.'
        USING HINT = 'duplicate_checkin';
    END IF;
  END IF;

  -- Validate time slot
  IF NOT validate_time_slot(NEW.time_slot, NEW.check_in_date, NEW.is_private) THEN
    RAISE EXCEPTION '无效的时间段。Invalid time slot.'
      USING HINT = 'invalid_time_slot';
  END IF;

  RETURN NEW;
END;
$$;

-- 3. Update check_in_stats trigger function
CREATE OR REPLACE FUNCTION update_check_in_stats()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Update member's last check-in date
  UPDATE members
  SET last_check_in_date = NEW.check_in_date
  WHERE id = NEW.member_id;

  -- If it's an extra check-in, increment the counter
  IF NEW.is_extra THEN
    UPDATE members
    SET extra_check_ins = COALESCE(extra_check_ins, 0) + 1
    WHERE id = NEW.member_id;
  END IF;

  RETURN NEW;
END;
$$;

-- 4. Drop and recreate triggers
DROP TRIGGER IF EXISTS check_in_validation_trigger ON check_ins;
CREATE TRIGGER check_in_validation_trigger
  BEFORE INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION check_in_validation();

DROP TRIGGER IF EXISTS check_in_logging_trigger ON check_ins;
CREATE TRIGGER check_in_logging_trigger
  AFTER INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION check_in_logging();

DROP TRIGGER IF EXISTS update_check_in_stats_trigger ON check_ins;
CREATE TRIGGER update_check_in_stats_trigger
  AFTER INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION update_check_in_stats();

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION check_in_logging() TO public;
GRANT EXECUTE ON FUNCTION check_in_validation() TO public;
GRANT EXECUTE ON FUNCTION update_check_in_stats() TO public;

COMMIT; 