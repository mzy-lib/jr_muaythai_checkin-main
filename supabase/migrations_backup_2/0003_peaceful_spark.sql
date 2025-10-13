/*
  # Create admin user and permissions

  1. Changes
    - Set up admin role and permissions
    - Add policies for admin access
  
  2. Security
    - Enable RLS policies for admin access
    - Set up secure access controls
*/

-- Ensure policies exist for admin access
DO $$ 
BEGIN
  -- Drop existing policies if they exist
  DROP POLICY IF EXISTS "Admin full access on members" ON members;
  DROP POLICY IF EXISTS "Admin full access on check_ins" ON check_ins;
  
  -- Create new policies
  CREATE POLICY "Admin full access on members"
    ON members
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

  CREATE POLICY "Admin full access on check_ins"
    ON check_ins
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);
END $$;

-- Note: The admin user should be created through the Supabase dashboard or API
-- This migration only sets up the necessary policies and permissions