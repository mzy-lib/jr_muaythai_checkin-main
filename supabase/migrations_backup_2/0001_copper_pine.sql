/*
  # Initial Schema for JR Muay Thai Sign-in System

  1. New Tables
    - `members`
      - Core member information for both new and existing members
      - Tracks membership type and remaining sessions
    - `check_ins`
      - Records all check-ins with timestamps
    - `class_schedule`
      - Defines class schedule and types
    
  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users (admin) to manage data
    - Add policies for public access for check-ins
*/

-- Create enum for membership types
CREATE TYPE membership_type AS ENUM (
  'single_class',
  'two_classes',
  'ten_classes',
  'single_daily_monthly',
  'double_daily_monthly'
);

-- Create enum for class types
CREATE TYPE class_type AS ENUM (
  'morning',
  'evening'
);

-- Members table
CREATE TABLE members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  email text,
  phone text,
  membership membership_type,
  remaining_classes int DEFAULT 0,
  membership_expiry timestamptz,
  extra_check_ins int DEFAULT 0,
  is_new_member boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Check-ins table
CREATE TABLE check_ins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid REFERENCES members(id),
  class_type class_type NOT NULL,
  check_in_date date DEFAULT CURRENT_DATE,
  created_at timestamptz DEFAULT now(),
  is_extra boolean DEFAULT false
);

-- Class schedule table
CREATE TABLE class_schedule (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  day_of_week int NOT NULL CHECK (day_of_week BETWEEN 1 AND 6),
  class_type class_type NOT NULL,
  start_time time NOT NULL,
  end_time time NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE check_ins ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_schedule ENABLE ROW LEVEL SECURITY;

-- Policies for members table
CREATE POLICY "Allow public read access to members" ON members
  FOR SELECT TO public USING (true);

CREATE POLICY "Allow admin full access to members" ON members
  FOR ALL TO authenticated USING (true);

-- Policies for check_ins table
CREATE POLICY "Allow public to create check-ins" ON check_ins
  FOR INSERT TO public WITH CHECK (true);

CREATE POLICY "Allow public to read own check-ins" ON check_ins
  FOR SELECT TO public USING (true);

CREATE POLICY "Allow admin full access to check-ins" ON check_ins
  FOR ALL TO authenticated USING (true);

-- Policies for class_schedule table
CREATE POLICY "Allow public read access to class schedule" ON class_schedule
  FOR SELECT TO public USING (true);

CREATE POLICY "Allow admin full access to class schedule" ON class_schedule
  FOR ALL TO authenticated USING (true);

-- Insert default class schedule
INSERT INTO class_schedule (day_of_week, class_type, start_time, end_time)
VALUES
  (1, 'morning', '09:00', '10:30'),
  (1, 'evening', '17:00', '18:30'),
  (2, 'morning', '09:00', '10:30'),
  (2, 'evening', '17:00', '18:30'),
  (3, 'morning', '09:00', '10:30'),
  (3, 'evening', '17:00', '18:30'),
  (4, 'morning', '09:00', '10:30'),
  (4, 'evening', '17:00', '18:30'),
  (5, 'morning', '09:00', '10:30'),
  (5, 'evening', '17:00', '18:30'),
  (6, 'morning', '09:00', '10:30'),
  (6, 'evening', '17:00', '18:30');

-- Function to update member status after check-in
CREATE OR REPLACE FUNCTION process_check_in()
RETURNS TRIGGER AS $$
BEGIN
  -- Get member details
  DECLARE
    v_membership membership_type;
    v_remaining_classes int;
    v_membership_expiry timestamptz;
    v_daily_check_ins int;
  BEGIN
    SELECT 
      membership,
      remaining_classes,
      membership_expiry
    INTO
      v_membership,
      v_remaining_classes,
      v_membership_expiry
    FROM members
    WHERE id = NEW.member_id;

    -- Count daily check-ins
    SELECT COUNT(*)
    INTO v_daily_check_ins
    FROM check_ins
    WHERE member_id = NEW.member_id
    AND check_in_date = CURRENT_DATE;

    -- Set is_extra flag based on membership type and status
    IF v_membership IS NULL THEN
      NEW.is_extra := true;
    ELSIF v_membership IN ('single_daily_monthly', 'double_daily_monthly') THEN
      IF v_membership_expiry < CURRENT_DATE THEN
        NEW.is_extra := true;
      ELSIF v_membership = 'single_daily_monthly' AND v_daily_check_ins >= 1 THEN
        NEW.is_extra := true;
      ELSIF v_membership = 'double_daily_monthly' AND v_daily_check_ins >= 2 THEN
        NEW.is_extra := true;
      END IF;
    ELSIF v_remaining_classes <= 0 THEN
      NEW.is_extra := true;
    END IF;

    -- Update member information
    IF NOT NEW.is_extra AND v_membership NOT IN ('single_daily_monthly', 'double_daily_monthly') THEN
      UPDATE members
      SET remaining_classes = remaining_classes - 1
      WHERE id = NEW.member_id;
    END IF;

    IF NEW.is_extra THEN
      UPDATE members
      SET extra_check_ins = extra_check_ins + 1
      WHERE id = NEW.member_id;
    END IF;

    -- Update new member status
    IF (SELECT is_new_member FROM members WHERE id = NEW.member_id) THEN
      UPDATE members
      SET is_new_member = false
      WHERE id = NEW.member_id;
    END IF;

    RETURN NEW;
  END;
END;
$$ LANGUAGE plpgsql;

-- Trigger for check-in processing
CREATE TRIGGER check_in_trigger
  BEFORE INSERT ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION process_check_in();