/*
  # Fix member import functionality

  1. Changes
    - Add unique constraint on member email
    - Modify import logic to handle duplicates properly
    - Add indexes for better performance

  2. Security
    - Maintain existing RLS policies
*/

-- Add unique constraint on email for members
ALTER TABLE members
ADD CONSTRAINT members_email_key UNIQUE (email);

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS members_name_idx ON members (name);
CREATE INDEX IF NOT EXISTS members_email_idx ON members (email);
CREATE INDEX IF NOT EXISTS check_ins_member_id_idx ON check_ins (member_id);
CREATE INDEX IF NOT EXISTS check_ins_check_in_date_idx ON check_ins (check_in_date);