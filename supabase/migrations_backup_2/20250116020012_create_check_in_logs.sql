-- Create check_in_logs table
BEGIN;

-- Create check_in_logs table
CREATE TABLE IF NOT EXISTS check_in_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  check_in_id uuid NOT NULL REFERENCES check_ins(id),
  details jsonb NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Create index on check_in_id
CREATE INDEX IF NOT EXISTS check_in_logs_check_in_id_idx ON check_in_logs(check_in_id);

-- Create index on created_at
CREATE INDEX IF NOT EXISTS check_in_logs_created_at_idx ON check_in_logs(created_at);

COMMIT; 