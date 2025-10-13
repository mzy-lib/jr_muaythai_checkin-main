-- Update RLS policies for test operations
BEGIN;

-- Drop existing test policies
DROP POLICY IF EXISTS "Allow operations on test members" ON members;
DROP POLICY IF EXISTS "Allow operations on test check-ins" ON check_ins;

-- Add updated policies that allow public access to test data
CREATE POLICY "Allow public operations on test members"
ON members
FOR ALL
TO public
USING (
  email LIKE '%.test.mt@example.com' 
  OR email LIKE '%test.checkin%'
)
WITH CHECK (
  email LIKE '%.test.mt@example.com'
  OR email LIKE '%test.checkin%'
);

CREATE POLICY "Allow public operations on test check-ins"
ON check_ins
FOR ALL
TO public
USING (
  member_id IN (
    SELECT id FROM members
    WHERE email LIKE '%.test.mt@example.com'
    OR email LIKE '%test.checkin%'
  )
)
WITH CHECK (
  member_id IN (
    SELECT id FROM members
    WHERE email LIKE '%.test.mt@example.com'
    OR email LIKE '%test.checkin%'
  )
);

COMMENT ON POLICY "Allow public operations on test members" ON members IS 
'Allows unauthenticated access to test member records for testing purposes';

COMMENT ON POLICY "Allow public operations on test check-ins" ON check_ins IS 
'Allows unauthenticated access to test check-in records for testing purposes';

COMMIT;