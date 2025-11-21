#!/bin/bash

# Script completo para desplegar la base de datos en Lambda usando AWS CLI
# Este script automatiza todo el proceso de configuración

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

FUNCTION_NAME="flask-lambda-app-production"
AWS_REGION="us-east-2"

echo "🗄️  Despliegue Completo de Base de Datos en Lambda"
echo "=================================================="
echo ""

# Verificar AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI no está instalado"
    echo "   Instala AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Verificar credenciales
echo "🔍 Verificando credenciales de AWS..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Error: No se pudieron validar las credenciales de AWS"
    echo "   Ejecuta: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "✅ Credenciales válidas (Account: $ACCOUNT_ID)"
echo ""

# Verificar que la función Lambda existe
echo "🔍 Verificando función Lambda..."
if ! aws lambda get-function --function-name "$FUNCTION_NAME" --region "$AWS_REGION" &> /dev/null; then
    echo "❌ Error: La función Lambda '$FUNCTION_NAME' no existe"
    echo ""
    echo "💡 Primero despliega la aplicación:"
    echo "   ./scripts/deploy.sh"
    exit 1
fi

echo "✅ Función Lambda encontrada: $FUNCTION_NAME"
echo ""

# Paso 1: Obtener información de RDS
echo "📋 Paso 1: Obteniendo información de RDS"
echo "----------------------------------------"

echo "🔍 Buscando clusters RDS disponibles..."
CLUSTERS=$(aws rds describe-db-clusters \
    --region "$AWS_REGION" \
    --query 'DBClusters[*].[DBClusterIdentifier,Endpoint,Status,DatabaseName]' \
    --output table 2>/dev/null || echo "")

if [ -z "$CLUSTERS" ] || [ "$CLUSTERS" == "None" ]; then
    echo "❌ No se encontraron clusters RDS"
    echo "   Asegúrate de tener un cluster RDS Aurora PostgreSQL creado"
    exit 1
fi

echo "$CLUSTERS"
echo ""

# Obtener el primer cluster disponible (o permitir selección)
CLUSTER_COUNT=$(aws rds describe-db-clusters \
    --region "$AWS_REGION" \
    --query 'length(DBClusters)' \
    --output text 2>/dev/null || echo "0")

if [ "$CLUSTER_COUNT" -eq "1" ]; then
    RDS_CLUSTER=$(aws rds describe-db-clusters \
        --region "$AWS_REGION" \
        --query 'DBClusters[0].DBClusterIdentifier' \
        --output text)
    echo "✅ Usando cluster único encontrado: $RDS_CLUSTER"
else
    echo "Se encontraron múltiples clusters. Usando el primero disponible."
    RDS_CLUSTER=$(aws rds describe-db-clusters \
        --region "$AWS_REGION" \
        --query 'DBClusters[0].DBClusterIdentifier' \
        --output text)
    echo "✅ Usando cluster: $RDS_CLUSTER"
fi

# Obtener endpoint de RDS
echo ""
echo "🔍 Obteniendo endpoint de RDS..."
DB_HOST=$(aws rds describe-db-clusters \
    --db-cluster-identifier "$RDS_CLUSTER" \
    --region "$AWS_REGION" \
    --query 'DBClusters[0].Endpoint' \
    --output text 2>/dev/null || echo "")

if [ -z "$DB_HOST" ] || [ "$DB_HOST" == "None" ]; then
    echo "❌ No se pudo obtener el endpoint del cluster"
    exit 1
fi

echo "✅ Endpoint obtenido: $DB_HOST"

# Obtener nombre de la base de datos
DB_NAME=$(aws rds describe-db-clusters \
    --db-cluster-identifier "$RDS_CLUSTER" \
    --region "$AWS_REGION" \
    --query 'DBClusters[0].DatabaseName' \
    --output text 2>/dev/null || echo "vehicledb")

if [ -z "$DB_NAME" ] || [ "$DB_NAME" == "None" ]; then
    DB_NAME="vehicledb"
fi

echo "✅ Database name: $DB_NAME"

# Obtener información del master username
DB_USER=$(aws rds describe-db-clusters \
    --db-cluster-identifier "$RDS_CLUSTER" \
    --region "$AWS_REGION" \
    --query 'DBClusters[0].MasterUsername' \
    --output text 2>/dev/null || echo "admin")

if [ -z "$DB_USER" ] || [ "$DB_USER" == "None" ]; then
    DB_USER="admin"
fi

echo "✅ DB Username: $DB_USER"
echo ""

# Obtener contraseña (puede venir de parámetro, variable de entorno o .env.deployment)
if [ ! -z "$1" ]; then
    DB_PASS="$1"
    echo "✅ Contraseña proporcionada como parámetro"
elif [ ! -z "$DB_PASS" ]; then
    echo "✅ Contraseña encontrada en variable de entorno"
elif [ -f ".env.deployment" ]; then
    source .env.deployment
    if [ ! -z "$DB_PASS" ]; then
        echo "✅ Contraseña encontrada en .env.deployment"
    fi
fi

# Si aún no hay contraseña, solicitarla
if [ -z "$DB_PASS" ]; then
    echo "🔐 Necesitamos la contraseña de la base de datos"
    read -s -p "Ingresa la contraseña de RDS para el usuario '$DB_USER': " DB_PASS
    echo ""
    
    if [ -z "$DB_PASS" ]; then
        echo "❌ Error: La contraseña no puede estar vacía"
        exit 1
    fi
fi

# Solicitar API Key (opcional, puede estar en .env.deployment)
API_KEY_EXCHANGE=""
if [ -f ".env.deployment" ]; then
    source .env.deployment
    if [ ! -z "$API_KEY_EXCHANGE" ]; then
        echo "✅ API Key encontrada en .env.deployment"
    fi
fi

if [ -z "$API_KEY_EXCHANGE" ]; then
    read -p "API Key de ExchangeRates (opcional, presiona Enter para omitir): " API_KEY_EXCHANGE
fi

echo ""
echo "📋 Resumen de configuración:"
echo "  - DB_HOST: $DB_HOST"
echo "  - DB_NAME: $DB_NAME"
echo "  - DB_USER: $DB_USER"
echo "  - DB_PASS: [oculto]"
if [ ! -z "$API_KEY_EXCHANGE" ]; then
    echo "  - API_KEY_EXCHANGE: [oculto]"
fi
echo ""

# Paso 2: Configurar Security Groups
echo "📋 Paso 2: Verificando Security Groups"
echo "----------------------------------------"

# Obtener Security Group de Lambda desde zappa_settings.json
LAMBDA_SG=$(python3 -c "import json; print(json.load(open('zappa_settings.json'))['production']['vpc_config']['SecurityGroupIds'][0]" 2>/dev/null || echo "")

if [ -z "$LAMBDA_SG" ]; then
    echo "⚠️  No se encontró Security Group de Lambda en zappa_settings.json"
else
    echo "✅ Security Group de Lambda: $LAMBDA_SG"
fi

# Obtener Security Groups de RDS
echo ""
echo "🔍 Obteniendo Security Groups de RDS..."
RDS_SGS=$(aws rds describe-db-clusters \
    --db-cluster-identifier "$RDS_CLUSTER" \
    --region "$AWS_REGION" \
    --query 'DBClusters[0].VpcSecurityGroups[*].VpcSecurityGroupId' \
    --output text 2>/dev/null || echo "")

if [ ! -z "$RDS_SGS" ]; then
    echo "✅ Security Groups de RDS: $RDS_SGS"
    
    # Verificar si RDS permite tráfico desde Lambda
    if [ ! -z "$LAMBDA_SG" ]; then
        echo ""
        echo "🔍 Verificando reglas de seguridad..."
        for RDS_SG in $RDS_SGS; do
            HAS_RULE=$(aws ec2 describe-security-groups \
                --group-ids "$RDS_SG" \
                --region "$AWS_REGION" \
                --query "SecurityGroups[0].IpPermissions[?UserIdGroupPairs[?GroupId=='$LAMBDA_SG']]" \
                --output text 2>/dev/null || echo "")
            
            if [ -z "$HAS_RULE" ]; then
                echo "⚠️  El Security Group $RDS_SG no permite tráfico desde Lambda SG $LAMBDA_SG"
                echo ""
                read -p "¿Deseas agregar la regla automáticamente? (y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    echo "📝 Agregando regla de seguridad..."
                    aws ec2 authorize-security-group-ingress \
                        --group-id "$RDS_SG" \
                        --protocol tcp \
                        --port 5432 \
                        --source-group "$LAMBDA_SG" \
                        --region "$AWS_REGION" \
                        --group-owner-id "$ACCOUNT_ID" 2>/dev/null || echo "⚠️  La regla ya existe o hubo un error"
                    echo "✅ Regla agregada"
                fi
            else
                echo "✅ El Security Group $RDS_SG ya permite tráfico desde Lambda"
            fi
        done
    fi
else
    echo "⚠️  No se encontraron Security Groups para RDS"
fi

echo ""

# Paso 3: Configurar variables de entorno en Lambda
echo "📋 Paso 3: Configurando Variables de Entorno en Lambda"
echo "------------------------------------------------------"

# Construir JSON de variables de entorno
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

echo "🔄 Actualizando configuración de Lambda..."
if aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --region "$AWS_REGION" \
    --environment "$ENV_JSON" &> /tmp/lambda_update.log; then
    echo "✅ Variables de entorno configuradas exitosamente"
else
    ERROR=$(cat /tmp/lambda_update.log)
    echo "❌ Error al configurar variables de entorno:"
    echo "$ERROR"
    exit 1
fi

# Paso 4: Verificar configuración
echo ""
echo "📋 Paso 4: Verificando Configuración"
echo "-------------------------------------"

echo "🔍 Verificando variables de entorno configuradas..."
CONFIGURED_VARS=$(aws lambda get-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --region "$AWS_REGION" \
    --query 'Environment.Variables' \
    --output table 2>/dev/null || echo "")

if [ ! -z "$CONFIGURED_VARS" ]; then
    echo "$CONFIGURED_VARS"
else
    echo "⚠️  No se pudieron obtener las variables configuradas"
fi

# Verificar VPC config
echo ""
echo "🔍 Verificando configuración de VPC..."
VPC_CONFIG=$(aws lambda get-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --region "$AWS_REGION" \
    --query 'VpcConfig' \
    --output table 2>/dev/null || echo "")

if [ ! -z "$VPC_CONFIG" ]; then
    echo "$VPC_CONFIG"
else
    echo "⚠️  No se pudo obtener la configuración de VPC"
fi

# Paso 5: Resumen final
echo ""
echo "✅ ¡Despliegue completado!"
echo "=========================="
echo ""
echo "📋 Resumen:"
echo "  - Función Lambda: $FUNCTION_NAME"
echo "  - RDS Cluster: $RDS_CLUSTER"
echo "  - DB Endpoint: $DB_HOST"
echo "  - Database: $DB_NAME"
echo "  - Variables de entorno: Configuradas"
echo ""

# Paso 6: Opciones adicionales
echo "💡 Próximos pasos:"
echo "1. Verificar que las tablas existan en la base de datos:"
echo "   ./scripts/create_tables.py --host $DB_HOST"
echo ""
echo "2. Probar tu aplicación:"
echo "   zappa status production"
echo ""
echo "3. Ver logs de Lambda:"
echo "   zappa tail production"
echo ""
echo "4. Probar endpoint de vehículos:"
echo "   curl \$(zappa status production | grep 'API Gateway URL' | awk '{print \$4}')/vehicles"
echo ""

