#!/bin/bash

# Script to create database tables
# Usage: ./scripts/create_tables.sh

set -e

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "❌ .env file not found!"
    exit 1
fi

# Check required variables
if [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
    echo "❌ Missing required database environment variables!"
    exit 1
fi

echo "🔧 Creating database tables..."
echo "📡 Connecting to: $DB_HOST"

# Export password for psql
export PGPASSWORD="$DB_PASS"

# Execute schema.sql (vehicles table)
echo ""
echo "📋 Creating vehicles table..."
psql -h "$DB_HOST" \
     -U "$DB_USER" \
     -d "$DB_NAME" \
     -f schema.sql \
     --set ON_ERROR_STOP=on

# Execute schema_conversions.sql (conversions table)
echo ""
echo "📋 Creating conversions table..."
psql -h "$DB_HOST" \
     -U "$DB_USER" \
     -d "$DB_NAME" \
     -f schema_conversions.sql \
     --set ON_ERROR_STOP=on

# Verify tables were created
echo ""
echo "✅ Verifying tables were created..."
psql -h "$DB_HOST" \
     -U "$DB_USER" \
     -d "$DB_NAME" \
     -c "\dt"

# Check vehicle count
echo ""
echo "📊 Checking vehicle count..."
psql -h "$DB_HOST" \
     -U "$DB_USER" \
     -d "$DB_NAME" \
     -c "SELECT COUNT(*) as vehicle_count FROM vehicles;"

echo ""
echo "✅ Database tables created successfully!"

