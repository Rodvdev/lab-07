# Guide to Create Database Tables

Since direct connection from your local machine is experiencing timeouts (likely due to VPC routing configuration), here are several options to create the tables:

## Option 1: AWS RDS Query Editor (Easiest - No Network Setup Required)

1. Go to **AWS Console** > **RDS** > **Query Editor**
2. Select your cluster: `database-lab-07`
3. Connect using:
   - **Database**: `postgres`
   - **Username**: `postgres`
   - **Password**: Your RDS password
4. Execute the SQL files one by one:
   - Copy and paste contents from `schema.sql`
   - Copy and paste contents from `schema_conversions.sql`

## Option 2: Wait for Network Changes to Propagate

The public access and security group changes may take a few more minutes to fully propagate. Wait 5-10 minutes and try again:

```bash
# Try the Python script
source venv/bin/activate
python scripts/create_tables.py

# Or try the shell script
./scripts/create_tables.sh
```

## Option 3: Use EC2 Instance in Same VPC (Bastion Host)

If you have an EC2 instance in the same VPC:

1. **SSH into the EC2 instance:**
   ```bash
   ssh -i your-key.pem ec2-user@your-ec2-instance.com
   ```

2. **On the EC2 instance, install psql:**
   ```bash
   sudo yum install postgresql15 -y  # Amazon Linux
   # or
   sudo apt-get install postgresql-client -y  # Ubuntu
   ```

3. **Copy your SQL files to the EC2 instance** (via SCP or copy-paste):
   ```bash
   scp -i your-key.pem schema.sql ec2-user@your-ec2-instance.com:~/
   scp -i your-key.pem schema_conversions.sql ec2-user@your-ec2-instance.com:~/
   ```

4. **Run the SQL from EC2:**
   ```bash
   export PGPASSWORD="your-db-password"
   psql -h database-lab-07.cluster-c92uuqwoiml2.us-east-2.rds.amazonaws.com \
        -U postgres \
        -d postgres \
        -f schema.sql
   
   psql -h database-lab-07.cluster-c92uuqwoiml2.us-east-2.rds.amazonaws.com \
        -U postgres \
        -d postgres \
        -f schema_conversions.sql
   ```

## Option 4: Use AWS Session Manager + Port Forwarding

If you have an EC2 instance with Session Manager enabled:

1. **Set up port forwarding:**
   ```bash
   aws ssm start-session \
     --target i-your-instance-id \
     --document-name AWS-StartPortForwardingSession \
     --parameters '{"portNumber":["5432"],"localPortNumber":["5432"]}'
   ```

2. **In another terminal, connect to localhost:**
   ```bash
   export PGPASSWORD="your-db-password"
   psql -h localhost -U postgres -d postgres -f schema.sql
   ```

## Option 5: Deploy to Lambda First

Since Lambda will have access to the database once properly configured, you can:

1. Deploy the application to Lambda (which has VPC access)
2. Create a temporary Lambda function that executes the SQL
3. Or wait until the app is deployed and tables will be created on first connection

## Quick SQL Reference

If using RDS Query Editor, here's what needs to be executed:

### 1. Create vehicles table:
```sql
CREATE TABLE IF NOT EXISTS vehicles (
    id SERIAL PRIMARY KEY,
    brand VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    year INT NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    availability BOOLEAN NOT NULL DEFAULT FALSE
);

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

UPDATE vehicles SET availability = TRUE WHERE id IN (1, 3, 5, 7, 9);
```

### 2. Create conversions table:
```sql
CREATE TABLE IF NOT EXISTS conversions (
    id SERIAL PRIMARY KEY,
    amount DECIMAL(18, 6) NOT NULL,
    from_currency VARCHAR(3) NOT NULL,
    to_currency VARCHAR(3) NOT NULL,
    converted_amount DECIMAL(18, 6) NOT NULL,
    base_currency VARCHAR(3) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_conversions_created_at ON conversions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversions_currencies ON conversions(from_currency, to_currency);
```

## Verification

After creating the tables, verify they exist:

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_type = 'BASE TABLE'
ORDER BY table_name;

SELECT COUNT(*) FROM vehicles;
```

## Recommended Approach

For now, **Option 1 (RDS Query Editor)** is the quickest and doesn't require any network configuration. Once the tables are created, your Lambda deployment will be able to use them.

