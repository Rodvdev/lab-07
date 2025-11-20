-- Migration Script: Add availability column to vehicles table
-- This script can be run on existing databases to add the availability column

-- Add availability column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vehicles' AND column_name = 'availability'
    ) THEN
        ALTER TABLE vehicles ADD COLUMN availability BOOLEAN NOT NULL DEFAULT FALSE;
        RAISE NOTICE 'Column availability added successfully';
    ELSE
        RAISE NOTICE 'Column availability already exists';
    END IF;
END $$;

-- Optional: Set some vehicles as available (uncomment and modify as needed)
-- UPDATE vehicles SET availability = TRUE WHERE id IN (1, 3, 5, 7, 9);

-- Verify the column was added
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'vehicles' AND column_name = 'availability';

