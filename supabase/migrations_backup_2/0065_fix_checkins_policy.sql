-- Fix check-ins table public access policy
BEGIN;

-- Drop all existing policies
DROP POLICY IF EXISTS "Allow public to create check-ins" ON check_ins;
DROP POLICY IF EXISTS "Allow public to read check-ins" ON check_ins;
DROP POLICY IF EXISTS "Allow public to read own check-ins" ON check_ins;
DROP POLICY IF EXISTS "Allow admin full access to check-ins" ON check_ins;

-- Create new policies with correct permissions
CREATE POLICY "Allow public to create check-ins"
ON check_ins
FOR INSERT
TO public
WITH CHECK (true);

CREATE POLICY "Allow public to read check-ins"
ON check_ins
FOR SELECT
TO public
USING (true);

COMMIT; 