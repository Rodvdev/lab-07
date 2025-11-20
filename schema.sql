-- Vehicle Catalog Database Schema
-- This script creates the vehicles table and inserts sample data

-- Create vehicles table
CREATE TABLE IF NOT EXISTS vehicles (
    id SERIAL PRIMARY KEY,
    brand VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    year INT NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    availability BOOLEAN NOT NULL DEFAULT FALSE
);

-- Insert sample vehicle data
INSERT INTO vehicles (brand, model, year, price) VALUES
('Toyota', 'Camry', 2023, 28500.00),
('Honda', 'Accord', 2023, 27295.00),
('Ford', 'F-150', 2023, 34845.00),
('Tesla', 'Model 3', 2023, 40240.00),
('BMW', '3 Series', 2023, 43300.00),
('Mercedes-Benz', 'C-Class', 2023, 44950.00),
('Audi', 'A4', 2023, 40100.00),
('Chevrolet', 'Silverado', 2023, 35990.00),
('Nissan', 'Altima', 2023, 25590.00),
('Volkswagen', 'Jetta', 2023, 19515.00)
ON CONFLICT DO NOTHING;

-- Add availability column to existing tables (if column doesn't exist)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vehicles' AND column_name = 'availability'
    ) THEN
        ALTER TABLE vehicles ADD COLUMN availability BOOLEAN NOT NULL DEFAULT FALSE;
    END IF;
END $$;

-- Update some sample vehicles to have availability = true (optional)
UPDATE vehicles SET availability = TRUE WHERE id IN (1, 3, 5, 7, 9);

-- Verify data was inserted
SELECT COUNT(*) as vehicle_count FROM vehicles;

