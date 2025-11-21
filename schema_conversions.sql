-- Currency Conversion History Database Schema
-- This script creates the conversions table for storing conversion history

-- Create conversions table
CREATE TABLE IF NOT EXISTS conversions (
    id SERIAL PRIMARY KEY,
    amount DECIMAL(18, 6) NOT NULL,
    from_currency VARCHAR(3) NOT NULL,
    to_currency VARCHAR(3) NOT NULL,
    converted_amount DECIMAL(18, 6) NOT NULL,
    base_currency VARCHAR(3) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index on created_at for faster queries
CREATE INDEX IF NOT EXISTS idx_conversions_created_at ON conversions(created_at DESC);

-- Create index on currencies for filtering
CREATE INDEX IF NOT EXISTS idx_conversions_currencies ON conversions(from_currency, to_currency);

