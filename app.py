import os
import logging
from datetime import datetime
from flask import Flask, render_template, request, jsonify
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
    'port': 5432,
    'connect_timeout': 10,  # Add connection timeout
    'sslmode': 'require'  # Required for Neon database
}

# Currency Data API configuration
EXCHANGE_API_URL = 'https://api.apilayer.com/currency_data/live'
EXCHANGE_API_KEY = os.getenv('API_KEY_EXCHANGE')

# Database connection pool (minimal for Lambda)
db_pool = None

def validate_db_config():
    """Validate that database configuration is present."""
    required_keys = ['host', 'database', 'user', 'password']
    missing = [key for key in required_keys if not DB_CONFIG.get(key)]
    if missing:
        raise ValueError(f"Missing database configuration: {', '.join(missing)}. "
                        f"Please set the following environment variables: "
                        f"{', '.join(['DB_' + k.upper() for k in missing])}")

def get_db_connection():
    """Get database connection from pool or create new connection."""
    global db_pool
    
    # Validate configuration before attempting connection
    validate_db_config()
    
    try:
        if db_pool is None:
            # For Lambda, use a simple connection pool (min 1, max 1 to avoid cold start issues)
            db_pool = psycopg2.pool.SimpleConnectionPool(1, 1, **DB_CONFIG)
            logger.info(f"Database connection pool created for {DB_CONFIG['host']}")
        
        return db_pool.getconn()
    except psycopg2.OperationalError as e:
        logger.error(f"Database connection error: {str(e)}")
        logger.error(f"Attempting to connect to: {DB_CONFIG['host']}:{DB_CONFIG['port']}")
        logger.error("Common issues:")
        logger.error("  - RDS is in a private VPC and not accessible from local machine")
        logger.error("  - Security group doesn't allow connections from your IP")
        logger.error("  - Database endpoint/credentials are incorrect")
        raise
    except Exception as e:
        logger.error(f"Error connecting to database: {str(e)}")
        raise

def return_db_connection(conn):
    """Return connection to pool."""
    if db_pool and conn:
        db_pool.putconn(conn)

@app.route('/production/')
def index():
    """Home page with navigation links."""
    return render_template('index.html')

@app.route('/production/exchange')
def exchange():
    """Display exchange rates from Currency Data API."""
    rates = None
    error = None
    base_currency = request.args.get('base', 'USD').upper()
    
    # Validate base currency
    if base_currency not in ['USD', 'EUR', 'PEN']:
        base_currency = 'USD'
    
    try:
        headers = {
            'apikey': EXCHANGE_API_KEY
        }
        
        # Get all currencies we need (USD, EUR, PEN)
        # We'll request based on USD and convert if needed
        params = {
            'base': 'USD',
            'symbols': 'EUR,PEN'
        }
        
        response = requests.get(EXCHANGE_API_URL, headers=headers, params=params, timeout=10)
        response.raise_for_status()
        
        data = response.json()
        
        # Currency Data API returns quotes in format "USDEUR", "USDPEN", etc.
        if data.get('success') and 'quotes' in data:
            quotes = data.get('quotes', {})
            timestamp = data.get('timestamp', 0)
            
            # Convert timestamp to readable date
            date_str = datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d %H:%M:%S') if timestamp else 'N/A'
            
            # Get base rates from USD
            usd_eur = quotes.get('USDEUR', 0.0)
            usd_pen = quotes.get('USDPEN', 0.0)
            
            # Calculate rates based on selected base currency
            if base_currency == 'USD':
                rates = {
                    'base': 'USD',
                    'USD': 1.0,
                    'EUR': usd_eur,
                    'PEN': usd_pen,
                    'timestamp': timestamp,
                    'date': date_str
                }
            elif base_currency == 'EUR':
                # Convert from USD base to EUR base
                eur_usd = 1.0 / usd_eur if usd_eur > 0 else 0.0
                eur_pen = usd_pen / usd_eur if usd_eur > 0 else 0.0
                rates = {
                    'base': 'EUR',
                    'USD': eur_usd,
                    'EUR': 1.0,
                    'PEN': eur_pen,
                    'timestamp': timestamp,
                    'date': date_str
                }
            elif base_currency == 'PEN':
                # Convert from USD base to PEN base
                pen_usd = 1.0 / usd_pen if usd_pen > 0 else 0.0
                pen_eur = usd_eur / usd_pen if usd_pen > 0 else 0.0
                rates = {
                    'base': 'PEN',
                    'USD': pen_usd,
                    'EUR': pen_eur,
                    'PEN': 1.0,
                    'timestamp': timestamp,
                    'date': date_str
                }
        else:
            error = f"API returned error: {data.get('error', {}).get('info', 'Unknown error')}"
            
    except requests.exceptions.RequestException as e:
        logger.error(f"Error fetching exchange rates: {str(e)}")
        error = f"Failed to fetch exchange rates: {str(e)}"
    except Exception as e:
        logger.error(f"Unexpected error in exchange route: {str(e)}")
        error = f"An unexpected error occurred: {str(e)}"
    
    return render_template('exchange.html', rates=rates, error=error, base_currency=base_currency)

@app.route('/production/vehicles')
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
                'price_formatted': f"{float(row[4]):,.2f}" if row[4] else "0.00",
                'availability': bool(row[5]) if len(row) > 5 else False
            }
            for row in rows
        ]
        
        cursor.close()
        
    except psycopg2.OperationalError as e:
        logger.error(f"Database connection error in vehicles route: {str(e)}")
        error = "Unable to connect to the database. This may be because the database is in a private VPC. Please check your connection settings or deploy to AWS Lambda."
    except psycopg2.Error as e:
        logger.error(f"Database error: {str(e)}")
        error = f"Database error: {str(e)}"
    except ValueError as e:
        # Missing configuration
        logger.error(f"Configuration error: {str(e)}")
        error = f"Configuration error: {str(e)}"
    except Exception as e:
        logger.error(f"Unexpected error in vehicles route: {str(e)}")
        error = f"An unexpected error occurred: {str(e)}"
    finally:
        if conn:
            return_db_connection(conn)
    
    return render_template('vehicles.html', vehicles=vehicles_list, error=error)

@app.route('/production/api/conversions', methods=['POST'])
def save_conversion():
    """Save a conversion to the database."""
    try:
        data = request.get_json()
        amount = float(data.get('amount', 0))
        from_currency = data.get('from_currency', '').upper()
        to_currency = data.get('to_currency', '').upper()
        converted_amount = float(data.get('converted_amount', 0))
        base_currency = data.get('base_currency', 'USD').upper()
        
        # Validate input
        if not from_currency or not to_currency or from_currency not in ['USD', 'EUR', 'PEN'] or to_currency not in ['USD', 'EUR', 'PEN']:
            return jsonify({'success': False, 'error': 'Invalid currency'}), 400
        
        conn = None
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            query = """
                INSERT INTO conversions (amount, from_currency, to_currency, converted_amount, base_currency)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING id, created_at
            """
            cursor.execute(query, (amount, from_currency, to_currency, converted_amount, base_currency))
            result = cursor.fetchone()
            conn.commit()
            cursor.close()
            
            return jsonify({
                'success': True,
                'id': result[0],
                'created_at': result[1].isoformat() if result[1] else None
            })
        except psycopg2.OperationalError as e:
            logger.error(f"Database connection error saving conversion: {str(e)}")
            if conn:
                conn.rollback()
            # Return success but indicate database unavailable
            return jsonify({'success': False, 'error': 'Database connection unavailable', 'use_localStorage': True}), 503
        except psycopg2.Error as e:
            logger.error(f"Database error saving conversion: {str(e)}")
            if conn:
                conn.rollback()
            # Return success but indicate database unavailable
            return jsonify({'success': False, 'error': 'Database unavailable', 'use_localStorage': True}), 503
        except ValueError as e:
            # Missing configuration
            logger.error(f"Configuration error saving conversion: {str(e)}")
            return jsonify({'success': False, 'error': str(e), 'use_localStorage': True}), 500
        except Exception as e:
            logger.error(f"Unexpected error saving conversion: {str(e)}")
            if conn:
                conn.rollback()
            return jsonify({'success': False, 'error': 'Unexpected error', 'use_localStorage': True}), 500
        finally:
            if conn:
                return_db_connection(conn)
    except Exception as e:
        logger.error(f"Error in save_conversion: {str(e)}")
        return jsonify({'success': False, 'error': str(e), 'use_localStorage': True}), 500

@app.route('/production/api/conversions', methods=['GET'])
def get_conversions():
    """Get conversion history from the database."""
    limit = request.args.get('limit', 50, type=int)
    if limit > 100:
        limit = 100
    
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        query = """
            SELECT id, amount, from_currency, to_currency, converted_amount, base_currency, created_at
            FROM conversions
            ORDER BY created_at DESC
            LIMIT %s
        """
        cursor.execute(query, (limit,))
        rows = cursor.fetchall()
        cursor.close()
        
        conversions = [
            {
                'id': row[0],
                'amount': float(row[1]),
                'from_currency': row[2],
                'to_currency': row[3],
                'converted_amount': float(row[4]),
                'base_currency': row[5],
                'created_at': row[6].isoformat() if row[6] else None
            }
            for row in rows
        ]
        
        return jsonify({'success': True, 'conversions': conversions})
    except psycopg2.OperationalError as e:
        logger.error(f"Database connection error getting conversions: {str(e)}")
        return jsonify({'success': False, 'error': 'Database connection unavailable', 'use_localStorage': True}), 503
    except psycopg2.Error as e:
        logger.error(f"Database error getting conversions: {str(e)}")
        return jsonify({'success': False, 'error': 'Database unavailable', 'use_localStorage': True}), 503
    except ValueError as e:
        # Missing configuration
        logger.error(f"Configuration error getting conversions: {str(e)}")
        return jsonify({'success': False, 'error': str(e), 'use_localStorage': True}), 500
    except Exception as e:
        logger.error(f"Unexpected error getting conversions: {str(e)}")
        return jsonify({'success': False, 'error': 'Unexpected error', 'use_localStorage': True}), 500
    finally:
        if conn:
            return_db_connection(conn)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5001)

