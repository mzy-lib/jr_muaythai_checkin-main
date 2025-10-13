-- Add policy to allow all members to check in
BEGIN;

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Allow public to create check-ins" ON check_ins;

-- Create new policy
CREATE POLICY "Allow public to create check-ins"
ON check_ins
FOR INSERT
TO public
WITH CHECK (true);

COMMIT; 