-- Add policy to allow public to register new members
BEGIN;

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Allow public to register new members" ON members;

-- Create new policy
CREATE POLICY "Allow public to update members"
ON members
FOR ALL
TO public
USING (true)
WITH CHECK (true);

COMMIT; 