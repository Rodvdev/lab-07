import os
import logging
from flask import Flask, render_template, request
import psycopg2
from psycopg2 import pool
import requests
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Database configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST'),
    'database': os.getenv('DB_NAME'),
    'user': os.getenv('DB_USER'),
    'password': os.getenv('DB_PASS'),
    'port': 5432
}

# Exchange Rates API configuration
EXCHANGE_API_URL = 'https://api.apilayer.com/exchangerates_data/latest'
EXCHANGE_API_KEY = os.getenv('API_KEY_EXCHANGE')

# Database connection pool (minimal for Lambda)
db_pool = None

def get_db_connection():
    """Get database connection from pool or create new connection."""
    global db_pool
    
    try:
        if db_pool is None:
            # For Lambda, use a simple connection pool (min 1, max 1 to avoid cold start issues)
            db_pool = psycopg2.pool.SimpleConnectionPool(1, 1, **DB_CONFIG)
            logger.info("Database connection pool created")
        
        return db_pool.getconn()
    except Exception as e:
        logger.error(f"Error connecting to database: {str(e)}")
        raise

def return_db_connection(conn):
    """Return connection to pool."""
    if db_pool and conn:
        db_pool.putconn(conn)

@app.route('/')
def index():
    """Home page with navigation links."""
    return render_template('index.html')

@app.route('/exchange')
def exchange():
    """Display exchange rates from ExchangeRates API."""
    rates = None
    error = None
    
    try:
        headers = {
            'apikey': EXCHANGE_API_KEY
        }
        params = {
            'base': 'USD',
            'symbols': 'USD,EUR,PEN'
        }
        
        response = requests.get(EXCHANGE_API_URL, headers=headers, params=params, timeout=10)
        response.raise_for_status()
        
        data = response.json()
        rates = {
            'USD': data.get('rates', {}).get('USD', 1.0),
            'EUR': data.get('rates', {}).get('EUR', 0.0),
            'PEN': data.get('rates', {}).get('PEN', 0.0),
            'date': data.get('date', 'N/A')
        }
        
    except requests.exceptions.RequestException as e:
        logger.error(f"Error fetching exchange rates: {str(e)}")
        error = f"Failed to fetch exchange rates: {str(e)}"
    except Exception as e:
        logger.error(f"Unexpected error in exchange route: {str(e)}")
        error = f"An unexpected error occurred: {str(e)}"
    
    return render_template('exchange.html', rates=rates, error=error)

@app.route('/vehicles')
def vehicles():
    """Display vehicle catalog from Aurora PostgreSQL."""
    vehicles_list = []
    error = None
    conn = None
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        query = """
            SELECT id, brand, model, year, price, availability
            FROM vehicles
            ORDER BY brand, model
        """
        cursor.execute(query)
        rows = cursor.fetchall()
        
        vehicles_list = [
            {
                'id': row[0],
                'brand': row[1],
                'model': row[2],
                'year': row[3],
                'price': float(row[4]) if row[4] else 0.0,
                'availability': bool(row[5]) if len(row) > 5 else False
            }
            for row in rows
        ]
        
        cursor.close()
        
    except psycopg2.Error as e:
        logger.error(f"Database error: {str(e)}")
        error = f"Database error: {str(e)}"
    except Exception as e:
        logger.error(f"Unexpected error in vehicles route: {str(e)}")
        error = f"An unexpected error occurred: {str(e)}"
    finally:
        if conn:
            return_db_connection(conn)
    
    return render_template('vehicles.html', vehicles=vehicles_list, error=error)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5001)

