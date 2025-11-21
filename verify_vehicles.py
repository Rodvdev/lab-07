#!/usr/bin/env python3
"""Quick script to verify vehicles in database"""

import os
from dotenv import load_dotenv
import psycopg2

load_dotenv()
conn = psycopg2.connect(
    host=os.getenv('DB_HOST'),
    database=os.getenv('DB_NAME'),
    user=os.getenv('DB_USER'),
    password=os.getenv('DB_PASS'),
    port=5432,
    sslmode='require'
)
cursor = conn.cursor()
cursor.execute('SELECT id, brand, model, year, price, availability FROM vehicles ORDER BY id;')
vehicles = cursor.fetchall()
print('\n📋 All vehicles in database:')
print('-' * 75)
for v in vehicles:
    avail = '✅ Available' if v[5] else '❌ Not Available'
    print(f'ID: {v[0]:2d} | {v[1]:15s} {v[2]:20s} | {v[3]} | ${v[4]:10,.2f} | {avail}')
print('-' * 75)
print(f'Total: {len(vehicles)} vehicles')
cursor.close()
conn.close()

