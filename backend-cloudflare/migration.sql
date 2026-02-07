-- Add new columns to existing audit_log table
ALTER TABLE audit_log ADD COLUMN email TEXT;
ALTER TABLE audit_log ADD COLUMN score INTEGER;

-- Create index for email column
CREATE INDEX IF NOT EXISTS idx_email ON audit_log(email);
