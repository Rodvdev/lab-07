# Flask Lambda Application

A Python Flask web application that consumes the ExchangeRates API and retrieves a catalog of vehicles stored in AWS Aurora PostgreSQL. The application is designed to be deployed serverlessly on AWS Lambda via API Gateway using Zappa.

## Overview

This application provides:
- **Home Page**: Navigation interface with links to exchange rates and vehicle catalog
- **Exchange Rates View**: Real-time currency exchange information (USD, EUR, PEN) from ExchangeRates API
- **Vehicle Catalog View**: Displays vehicles from Aurora PostgreSQL database

## Architecture

```
Client Browser
     |
     |  Flask (HTML templates, Tailwind CSS)
     |
API Gateway
     |
AWS Lambda  (Python Flask via Zappa)
     |
Aurora Serverless PostgreSQL  
     |
ExchangeRates API (External Service)
```

## Prerequisites

Before you begin, ensure you have the following:

1. **Python 3.9+** installed
2. **AWS CLI** configured with appropriate credentials
3. **AWS Account** with access to:
   - AWS Lambda
   - API Gateway
   - Aurora PostgreSQL Serverless v2
   - S3 (for Zappa deployments)
4. **ExchangeRates API Key** from [apilayer.com](https://apilayer.com/marketplace/exchangerates_data-api)
5. **Aurora PostgreSQL Database** instance created and accessible

## Project Structure

```
lab-07/
├── app.py                 # Main Flask application
├── requirements.txt       # Python dependencies
├── zappa_settings.json    # Zappa configuration for Lambda
├── schema.sql            # Database schema and sample data
├── templates/            # HTML templates
│   ├── base.html
│   ├── index.html
│   ├── exchange.html
│   └── vehicles.html
├── static/               # Static files directory
├── .env.example          # Example environment variables
├── .gitignore
└── README.md
```

## Local Development Setup

### 1. Clone and Navigate to Project

```bash
cd lab-07
```

### 2. Create Virtual Environment

```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

### 4. Configure Environment Variables

Create a `.env` file in the project root:

```bash
cp .env.example .env
```

Edit `.env` with your actual values:

```env
API_KEY_EXCHANGE=your_exchange_api_key_here
DB_HOST=your-aurora-endpoint.cluster-xxxxx.us-east-1.rds.amazonaws.com
DB_NAME=your_database_name
DB_USER=your_db_username
DB_PASS=your_db_password
```

### 5. Set Up Database

Connect to your Aurora PostgreSQL instance and run the schema:

```bash
psql -h your-aurora-endpoint.cluster-xxxxx.us-east-1.rds.amazonaws.com \
     -U your_db_username \
     -d your_database_name \
     -f schema.sql
```

Or use your preferred PostgreSQL client to execute `schema.sql`.

### 6. Run Application Locally

```bash
python app.py
```

The application will be available at `http://localhost:5000`

## Database Setup

### Create Vehicle Table

The `schema.sql` file contains:

1. **CREATE TABLE** statement for the `vehicles` table
2. **Sample INSERT** statements with 10 example vehicles
3. **Verification query** to check data insertion

Table structure:

```sql
CREATE TABLE vehicles (
    id SERIAL PRIMARY KEY,
    brand VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    year INT NOT NULL,
    price DECIMAL(10, 2) NOT NULL
);
```

## Deployment to AWS Lambda

### 1. Prerequisites

- AWS CLI configured (`aws configure`)
- Appropriate IAM permissions for Lambda, API Gateway, and S3
- Aurora PostgreSQL accessible from Lambda (consider VPC configuration)

### 2. Update Zappa Settings

Edit `zappa_settings.json` and update:
- `aws_region`: Your preferred AWS region
- `s3_bucket`: An S3 bucket name for Zappa deployments (must be globally unique)
- `vpc_config`: If your Aurora database is in a VPC, configure subnet IDs and security group IDs
- `environment_variables`: Update with your actual environment variables or configure via AWS Lambda console

**Important**: For production, set environment variables in AWS Lambda console or use AWS Secrets Manager instead of hardcoding in `zappa_settings.json`.

### 3. Deploy with Zappa

#### First Deployment

```bash
# Ensure you're in the virtual environment
source venv/bin/activate

# Initialize Zappa (if not already configured)
zappa init

# Deploy to Lambda
zappa deploy production
```

After deployment, Zappa will output the API Gateway URL.

#### Update Existing Deployment

```bash
zappa update production
```

#### Test Deployment

```bash
# Get API Gateway URL
zappa status production | grep "API Gateway URL"

# Test the endpoint
curl $(zappa status production | grep "API Gateway URL" | awk '{print $4}')
```

#### Undeploy

```bash
zappa undeploy production
```

### 4. Configure Environment Variables in Lambda

After deployment, set environment variables in AWS Lambda console:

1. Go to AWS Lambda Console
2. Select your function (named `flask-lambda-app-production`)
3. Go to **Configuration** > **Environment variables**
4. Add the following variables:
   - `API_KEY_EXCHANGE`
   - `DB_HOST`
   - `DB_NAME`
   - `DB_USER`
   - `DB_PASS`

**Security Best Practice**: For production, consider using AWS Secrets Manager instead of Lambda environment variables.

### 5. VPC Configuration (if required)

If your Aurora database is in a VPC:

1. Update `zappa_settings.json` with VPC configuration:
```json
"vpc_config": {
    "SubnetIds": ["subnet-xxx", "subnet-yyy"],
    "SecurityGroupIds": ["sg-xxx"]
}
```

2. Redeploy:
```bash
zappa update production
```

**Note**: Lambda functions in VPCs may experience increased cold start times.

### 6. Verify Deployment

1. Access the API Gateway URL provided by Zappa
2. Test all routes:
   - `/` - Home page
   - `/exchange` - Exchange rates
   - `/vehicles` - Vehicle catalog

## Testing

### Local Testing

1. Start the Flask app: `python app.py`
2. Visit `http://localhost:5000`
3. Test each route:
   - Home page navigation
   - Exchange rates display
   - Vehicle catalog display

### Post-Deployment Testing

1. Access your API Gateway URL
2. Verify all routes work correctly
3. Test all endpoints manually

## Troubleshooting

### Common Issues

#### 1. Database Connection Timeout

**Problem**: Lambda cannot connect to Aurora PostgreSQL

**Solutions**:
- Verify Lambda is in the same VPC as Aurora (if required)
- Check security group rules allow Lambda to access Aurora
- Verify database endpoint and credentials
- Increase Lambda timeout in `zappa_settings.json`

#### 2. ExchangeRates API Errors

**Problem**: Exchange rates not loading

**Solutions**:
- Verify `API_KEY_EXCHANGE` is set correctly
- Check API key is valid and has sufficient credits
- Test the API endpoint manually and check for error responses

#### 3. Cold Start Latency

**Problem**: First request is slow

**Solutions**:
- Enable provisioned concurrency in Lambda
- Reduce package size
- Optimize imports
- Consider warming requests

#### 4. Import Errors in Lambda

**Problem**: ModuleNotFoundError or import errors

**Solutions**:
- Ensure all dependencies are in `requirements.txt`
- Verify `exclude` list in `zappa_settings.json` doesn't exclude needed files
- Check Lambda runtime matches local Python version

#### 5. Template Not Found

**Problem**: Flask cannot find templates

**Solutions**:
- Verify `templates/` directory is included in deployment
- Check `zappa_settings.json` exclude patterns
- Ensure templates are in the correct location

## Environment Variables Reference

| Variable | Description | Required |
|----------|-------------|----------|
| `API_KEY_EXCHANGE` | ExchangeRates API key from apilayer.com | Yes |
| `DB_HOST` | Aurora PostgreSQL endpoint | Yes |
| `DB_NAME` | Database name | Yes |
| `DB_USER` | Database username | Yes |
| `DB_PASS` | Database password | Yes |

## API Endpoints

| Route | Method | Description |
|-------|--------|-------------|
| `/` | GET | Home page with navigation |
| `/exchange` | GET | Display exchange rates (USD, EUR, PEN) |
| `/vehicles` | GET | Display vehicle catalog from database |

## Security Considerations

1. **API Keys**: Never commit API keys to version control. Use environment variables or AWS Secrets Manager.

2. **Database Credentials**: Store database credentials securely using AWS Secrets Manager or Lambda environment variables (encrypted).

3. **HTTPS**: API Gateway provides HTTPS by default. Ensure production traffic uses HTTPS only.

4. **IAM Roles**: Ensure Lambda execution role has minimal required permissions.

5. **VPC Security**: If using VPC, configure security groups to allow only necessary traffic.

## Cost Optimization

- Aurora Serverless v2 auto-scales, minimizing idle costs
- Lambda charges per request and compute time
- API Gateway has a free tier for first million requests
- Consider provisioned concurrency only if needed for performance

## Future Enhancements

- Authentication and authorization
- CRUD operations for vehicles
- React frontend with Cognito authentication
- CI/CD pipeline with GitHub Actions
- Enhanced error handling and retry logic
- Caching for exchange rates

## License

This project is created for educational purposes.

## Owner

**Rodrigo Vásquez de Velasco**

---

For issues or questions, please check the troubleshooting section above.

