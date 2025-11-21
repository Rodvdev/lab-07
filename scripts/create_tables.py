#!/usr/bin/env python3
"""
Script to create database tables in RDS Aurora PostgreSQL
Usage: python scripts/create_tables.py
"""

import os
import sys
import time
import argparse
from dotenv import load_dotenv
import psycopg2
from psycopg2 import sql

# Load environment variables
load_dotenv()

def connect_to_db(host_override=None, max_retries=5, retry_delay=10):
    """Connect to database with retries."""
    db_host = host_override or os.getenv('DB_HOST')
    db_config = {
        'host': db_host,
        'database': os.getenv('DB_NAME'),
        'user': os.getenv('DB_USER'),
        'password': os.getenv('DB_PASS'),
        'port': 5432,
        'connect_timeout': 15
    }
    
    # Validate config
    missing = [k for k, v in db_config.items() if not v]
    if missing:
        print(f"❌ Missing database configuration: {', '.join(missing)}")
        sys.exit(1)
    
    for attempt in range(max_retries):
        try:
            print(f"Attempt {attempt + 1}/{max_retries}: Connecting to {db_config['host']}...")
            conn = psycopg2.connect(**db_config)
            print("✅ Connected successfully!")
            return conn
        except psycopg2.OperationalError as e:
            if attempt < max_retries - 1:
                print(f"❌ Connection failed, retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)
            else:
                print(f"❌ Failed to connect after {max_retries} attempts")
                print(f"Error: {e}")
                print("\n💡 Tips:")
                print("  1. Verify the database is publicly accessible")
                print("  2. Check security group allows your IP on port 5432")
                print("  3. Check VPC route tables have internet gateway routes")
                print("  4. Try connecting from an EC2 instance in the same VPC")
                sys.exit(1)
    
def execute_schema_file(conn, filename):
    """Execute a SQL schema file."""
    if not os.path.exists(filename):
        print(f"❌ Schema file not found: {filename}")
        return False
    
    print(f"\n📋 Executing {filename}...")
    try:
        with open(filename, 'r') as f:
            sql_content = f.read()
        
        conn.autocommit = True
        cur = conn.cursor()
        cur.execute(sql_content)
        cur.close()
        conn.autocommit = False
        print(f"✅ {filename} executed successfully")
        return True
    except Exception as e:
        print(f"❌ Error executing {filename}: {e}")
        return False

def main():
    """Main function to create tables."""
    parser = argparse.ArgumentParser(description='Create database tables in RDS Aurora PostgreSQL')
    parser.add_argument('--host', type=str, help='Database host endpoint (overrides DB_HOST env var)')
    args = parser.parse_args()
    
    print("🔧 Creating database tables...")
    
    # Connect to database
    conn = connect_to_db(host_override=args.host)
    
    try:
        # Execute schema files
        schema_files = ['schema.sql', 'schema_conversions.sql']
        
        for schema_file in schema_files:
            if not execute_schema_file(conn, schema_file):
                print(f"⚠️  Failed to execute {schema_file}, continuing...")
        
        # Verify tables
        print("\n✅ Verifying tables were created...")
        cur = conn.cursor()
        cur.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_type = 'BASE TABLE'
            ORDER BY table_name;
        """)
        tables = cur.fetchall()
        
        if tables:
            print("📊 Tables found:")
            for table in tables:
                print(f"   - {table[0]}")
        else:
            print("⚠️  No tables found")
        
        # Check vehicle count
        try:
            cur.execute("SELECT COUNT(*) FROM vehicles;")
            vehicle_count = cur.fetchone()[0]
            print(f"\n📊 Vehicle count: {vehicle_count}")
        except Exception as e:
            print(f"\n⚠️  Could not get vehicle count: {e}")
        
        cur.close()
        conn.close()
        print("\n✅ Database setup complete!")
        
    except Exception as e:
        print(f"❌ Error during setup: {e}")
        if conn:
            conn.rollback()
        sys.exit(1)

if __name__ == '__main__':
    main()

