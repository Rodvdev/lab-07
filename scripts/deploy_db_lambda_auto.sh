#!/bin/bash

# Script automatizado para desplegar DB en Lambda usando AWS CLI
# Uso: ./scripts/deploy_db_lambda_auto.sh [DB_PASSWORD]
# O: DB_PASS=tu_password ./scripts/deploy_db_lambda_auto.sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

FUNCTION_NAME="flask-lambda-app-production"
AWS_REGION="us-east-2"

echo "🗄️  Despliegue Automatizado de Base de Datos en Lambda"
echo "====================================================="
echo ""

# Verificar AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI no está instalado"
    exit 1
fi

# Verificar credenciales
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Error: No se pudieron validar las credenciales de AWS"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "✅ AWS Account: $ACCOUNT_ID"
echo "✅ Región: $AWS_REGION"
echo ""

# Verificar función Lambda
if ! aws lambda get-function --function-name "$FUNCTION_NAME" --region "$AWS_REGION" &> /dev/null; then
    echo "❌ La función Lambda '$FUNCTION_NAME' no existe"
    echo "   Ejecuta primero: ./scripts/deploy.sh"
    exit 1
fi

echo "✅ Función Lambda encontrada"
echo ""

# Obtener información de RDS
echo "📋 Obteniendo información de RDS..."
RDS_CLUSTER="database-lab-07"

DB_HOST=$(aws rds describe-db-clusters \
    --db-cluster-identifier "$RDS_CLUSTER" \
    --region "$AWS_REGION" \
    --query 'DBClusters[0].Endpoint' \
    --output text 2>/dev/null || echo "")

if [ -z "$DB_HOST" ] || [ "$DB_HOST" == "None" ]; then
    echo "❌ No se pudo obtener el endpoint de RDS"
    exit 1
fi

DB_NAME=$(aws rds describe-db-clusters \
    --db-cluster-identifier "$RDS_CLUSTER" \
    --region "$AWS_REGION" \
    --query 'DBClusters[0].DatabaseName' \
    --output text 2>/dev/null || echo "postgres")

# Si DatabaseName es None, usar valor por defecto
if [ -z "$DB_NAME" ] || [ "$DB_NAME" == "None" ]; then
    DB_NAME="postgres"
fi

DB_USER=$(aws rds describe-db-clusters \
    --db-cluster-identifier "$RDS_CLUSTER" \
    --region "$AWS_REGION" \
    --query 'DBClusters[0].MasterUsername' \
    --output text 2>/dev/null || echo "postgres")

if [ -z "$DB_USER" ] || [ "$DB_USER" == "None" ]; then
    DB_USER="postgres"
fi

echo "✅ RDS Cluster: $RDS_CLUSTER"
echo "✅ DB Endpoint: $DB_HOST"
echo "✅ Database: $DB_NAME"
echo "✅ Username: $DB_USER"
echo ""

# Obtener contraseña
if [ ! -z "$1" ]; then
    DB_PASS="$1"
elif [ ! -z "$DB_PASS" ]; then
    # Ya está en variable de entorno
    :
elif [ -f ".env.deployment" ]; then
    source .env.deployment
fi

if [ -z "$DB_PASS" ]; then
    echo "🔐 Necesitas proporcionar la contraseña de RDS"
    echo ""
    echo "Opciones:"
    echo "1. Como parámetro: ./scripts/deploy_db_lambda_auto.sh TU_PASSWORD"
    echo "2. Como variable de entorno: DB_PASS=TU_PASSWORD ./scripts/deploy_db_lambda_auto.sh"
    echo "3. En archivo .env.deployment: DB_PASS=TU_PASSWORD"
    echo ""
    read -s -p "Ingresa la contraseña ahora: " DB_PASS
    echo ""
    
    if [ -z "$DB_PASS" ]; then
        echo "❌ Error: La contraseña no puede estar vacía"
        exit 1
    fi
fi

# Obtener API Key
if [ -f ".env.deployment" ]; then
    source .env.deployment
fi

# Si la contraseña viene como parámetro o variable de entorno, omitir API key interactivo
if [ -z "$API_KEY_EXCHANGE" ] && [ -z "$1" ] && [ -z "$DB_PASS" ]; then
    echo ""
    read -p "API Key de ExchangeRates (opcional, Enter para omitir): " API_KEY_EXCHANGE
fi

echo ""
echo "📋 Configuración a aplicar:"
echo "  DB_HOST: $DB_HOST"
echo "  DB_NAME: $DB_NAME"
echo "  DB_USER: $DB_USER"
echo "  DB_PASS: [oculto]"
if [ ! -z "$API_KEY_EXCHANGE" ]; then
    echo "  API_KEY_EXCHANGE: [oculto]"
fi
echo ""

# Configurar Security Groups
echo "📋 Configurando Security Groups..."
LAMBDA_SG=$(python3 -c "import json; print(json.load(open('zappa_settings.json'))['production']['vpc_config']['SecurityGroupIds'][0])" 2>/dev/null || echo "")

if [ ! -z "$LAMBDA_SG" ]; then
    RDS_SGS=$(aws rds describe-db-clusters \
        --db-cluster-identifier "$RDS_CLUSTER" \
        --region "$AWS_REGION" \
        --query 'DBClusters[0].VpcSecurityGroups[*].VpcSecurityGroupId' \
        --output text 2>/dev/null || echo "")
    
    if [ ! -z "$RDS_SGS" ]; then
        for RDS_SG in $RDS_SGS; do
            # Verificar si ya existe la regla
            HAS_RULE=$(aws ec2 describe-security-groups \
                --group-ids "$RDS_SG" \
                --region "$AWS_REGION" \
                --query "SecurityGroups[0].IpPermissions[?UserIdGroupPairs[?GroupId=='$LAMBDA_SG']]" \
                --output text 2>/dev/null || echo "")
            
            if [ -z "$HAS_RULE" ]; then
                echo "  📝 Agregando regla de seguridad en $RDS_SG..."
                aws ec2 authorize-security-group-ingress \
                    --group-id "$RDS_SG" \
                    --protocol tcp \
                    --port 5432 \
                    --source-group "$LAMBDA_SG" \
                    --region "$AWS_REGION" \
                    --group-owner-id "$ACCOUNT_ID" 2>/dev/null && echo "  ✅ Regla agregada" || echo "  ⚠️  La regla ya existe o hubo un error"
            else
                echo "  ✅ Security Group $RDS_SG ya permite tráfico desde Lambda"
            fi
        done
    fi
fi

echo ""

# Configurar variables de entorno en Lambda
echo "📋 Configurando Variables de Entorno en Lambda..."
if [ ! -z "$API_KEY_EXCHANGE" ]; then
    ENV_JSON=$(cat <<EOF
{
  "Variables": {
    "DB_HOST": "$DB_HOST",
    "DB_NAME": "$DB_NAME",
    "DB_USER": "$DB_USER",
    "DB_PASS": "$DB_PASS",
    "API_KEY_EXCHANGE": "$API_KEY_EXCHANGE"
  }
}
EOF
)
else
    ENV_JSON=$(cat <<EOF
{
  "Variables": {
    "DB_HOST": "$DB_HOST",
    "DB_NAME": "$DB_NAME",
    "DB_USER": "$DB_USER",
    "DB_PASS": "$DB_PASS"
  }
}
EOF
)
fi

echo "🔄 Actualizando función Lambda..."
if aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --region "$AWS_REGION" \
    --environment "$ENV_JSON" &> /tmp/lambda_db_deploy.log; then
    echo "✅ Variables de entorno configuradas exitosamente"
else
    ERROR=$(cat /tmp/lambda_db_deploy.log)
    echo "❌ Error al configurar:"
    echo "$ERROR"
    exit 1
fi

# Verificar configuración
echo ""
echo "📋 Verificando configuración..."
CONFIGURED_VARS=$(aws lambda get-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --region "$AWS_REGION" \
    --query 'Environment.Variables' \
    --output table 2>/dev/null)

if [ ! -z "$CONFIGURED_VARS" ]; then
    echo "$CONFIGURED_VARS"
fi

echo ""
echo "✅ ¡Despliegue completado!"
echo ""
echo "💡 Próximos pasos:"
echo "1. Crear tablas en la base de datos:"
echo "   ./scripts/create_tables.py --host $DB_HOST"
echo ""
echo "2. Probar la aplicación:"
echo "   zappa status production"
echo ""

