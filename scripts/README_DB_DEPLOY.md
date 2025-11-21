# Despliegue de Base de Datos en Lambda - Guía Rápida

## Scripts Disponibles

### 1. `deploy_db_lambda_auto.sh` (Recomendado - Más Automatizado)
Este script obtiene automáticamente la información de RDS y configura Lambda.

**Uso:**
```bash
# Opción 1: Proporcionar contraseña como parámetro
./scripts/deploy_db_lambda_auto.sh TU_PASSWORD

# Opción 2: Usar variable de entorno
DB_PASS=TU_PASSWORD ./scripts/deploy_db_lambda_auto.sh

# Opción 3: Crear archivo .env.deployment
echo "DB_PASS=TU_PASSWORD" > .env.deployment
./scripts/deploy_db_lambda_auto.sh
```

### 2. `deploy_db_to_lambda.sh` (Interactivo Completo)
Script más completo que te guía paso a paso.

**Uso:**
```bash
./scripts/deploy_db_to_lambda.sh mjot~UlHL*?3g2iqoxxfR|vd>LOX
```

## Información Detectada Automáticamente

El script detecta automáticamente:
- ✅ RDS Cluster: `database-lab-07`
- ✅ DB Endpoint: `database-lab-07.cluster-c92uuqwoiml2.us-east-2.rds.amazonaws.com`
- ✅ Database Name: `vehicledb`
- ✅ Username: `postgres`
- ✅ Lambda Function: `flask-lambda-app-production`
- ✅ AWS Region: `us-east-2`

## Lo que Necesitas Proporcionar

- 🔐 **DB Password**: Contraseña de RDS para el usuario `postgres`
- 🔑 **API Key Exchange** (opcional): Clave API de ExchangeRates

## Ejecución Completa

```bash
# 1. Desplegar configuración de DB en Lambda
./scripts/deploy_db_lambda_auto.sh TU_PASSWORD_RDS

# 2. Crear tablas en la base de datos
./scripts/create_tables.py --host database-lab-07.cluster-c92uuqwoiml2.us-east-2.rds.amazonaws.com

# 3. Verificar despliegue
zappa status production

# 4. Probar endpoints
curl $(zappa status production | grep "API Gateway URL" | awk '{print $4}')/vehicles
```

## Verificación

Después del despliegue, verifica:

```bash
# Ver variables de entorno configuradas
aws lambda get-function-configuration \
    --function-name flask-lambda-app-production \
    --region us-east-2 \
    --query 'Environment.Variables' \
    --output table

# Ver logs de Lambda
zappa tail production
```

## Solución de Problemas

### Error: "Function not found"
```bash
# Primero despliega la aplicación
./scripts/deploy.sh
```

### Error: "Access Denied"
```bash
# Verifica credenciales
aws sts get-caller-identity
```

### Error: "Timeout connecting to database"
- Verifica Security Groups: RDS debe permitir tráfico desde Lambda SG en puerto 5432
- Verifica VPC: Lambda y RDS deben estar en la misma VPC

