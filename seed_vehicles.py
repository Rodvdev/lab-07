#!/usr/bin/env python3
"""
Script to seed additional vehicles into the database
Usage: python seed_vehicles.py
"""

import os
import sys
from dotenv import load_dotenv
import psycopg2

# Load environment variables
load_dotenv()

def seed_vehicles():
    """Add 5 more vehicles to reach 15 total."""
    
    # Database configuration
    db_config = {
        'host': os.getenv('DB_HOST'),
        'database': os.getenv('DB_NAME'),
        'user': os.getenv('DB_USER'),
        'password': os.getenv('DB_PASS'),
        'port': 5432,
        'connect_timeout': 15,
        'sslmode': 'require'
    }
    
    # Additional vehicles to add (5 more)
    additional_vehicles = [
        ('Mazda', 'CX-5', 2023, 27650.00, True),
        ('Subaru', 'Outback', 2023, 28095.00, True),
        ('Jeep', 'Grand Cherokee', 2023, 38295.00, False),
        ('Hyundai', 'Tucson', 2023, 25895.00, True),
        ('Kia', 'Telluride', 2023, 34465.00, True)
    ]
    
    try:
        print("🔌 Connecting to database...")
        conn = psycopg2.connect(**db_config)
        print("✅ Connected successfully!")
        
        cursor = conn.cursor()
        
        # Check current vehicle count
        cursor.execute("SELECT COUNT(*) FROM vehicles;")
        current_count = cursor.fetchone()[0]
        print(f"📊 Current vehicle count: {current_count}")
        
        # Insert additional vehicles
        print(f"\n🌱 Seeding {len(additional_vehicles)} additional vehicles...")
        insert_query = """
            INSERT INTO vehicles (brand, model, year, price, availability)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING id, brand, model;
        """
        
        inserted_count = 0
        for vehicle in additional_vehicles:
            try:
                cursor.execute(insert_query, vehicle)
                result = cursor.fetchone()
                if result:
                    inserted_count += 1
                    print(f"  ✅ Added: {result[1]} {result[2]} (ID: {result[0]})")
            except psycopg2.IntegrityError:
                print(f"  ⚠️  Skipped (duplicate): {vehicle[0]} {vehicle[1]}")
                conn.rollback()
                continue
        
        conn.commit()
        
        # Check final vehicle count
        cursor.execute("SELECT COUNT(*) FROM vehicles;")
        final_count = cursor.fetchone()[0]
        print(f"\n📊 Final vehicle count: {final_count}")
        
        cursor.close()
        conn.close()
        
        print(f"\n✅ Successfully seeded {inserted_count} vehicles!")
        print(f"   Total vehicles in database: {final_count}")
        
    except psycopg2.OperationalError as e:
        print(f"❌ Database connection error: {e}")
        sys.exit(1)
    except psycopg2.Error as e:
        print(f"❌ Database error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    seed_vehicles()

