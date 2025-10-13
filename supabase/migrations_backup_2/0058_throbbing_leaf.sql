-- Add RLS policies for test data operations
BEGIN;

-- Allow operations on test members
CREATE POLICY "Allow operations on test members"
ON members
FOR ALL
USING (
  email LIKE '%.test.mt@example.com'
  OR email LIKE '%test.checkin%'
);

-- Allow operations on test check-ins
CREATE POLICY "Allow operations on test check-ins"
ON check_ins
FOR ALL
USING (
  member_id IN (
    SELECT id FROM members
    WHERE email LIKE '%.test.mt@example.com'
    OR email LIKE '%test.checkin%'
  )
);

COMMIT;