#!/bin/bash

# Script interactivo para configurar el despliegue en Lambda con RDS
# Este script te guiará para obtener toda la información necesaria

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "🔧 Configuración de Despliegue en Lambda con RDS"
echo "================================================"
echo ""

# Verificar AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI no está instalado"
    echo "   Ejecuta: ./scripts/setup_aws.sh"
    exit 1
fi

# Verificar credenciales
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Error: No se pudieron validar las credenciales de AWS"
    echo "   Ejecuta: aws configure"
    exit 1
fi

echo "✅ AWS CLI configurado correctamente"
echo ""

# 1. Información del bucket S3
echo "📦 Paso 1: Configuración del Bucket S3"
echo "--------------------------------------"
S3_BUCKET=$(python3 -c "import json; print(json.load(open('zappa_settings.json'))['production']['s3_bucket'])" 2>/dev/null || echo "zappa-deployments")
echo "Bucket S3 actual: $S3_BUCKET"
read -p "¿Tienes un bucket S3 creado? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Necesitas crear un bucket S3 primero:"
    echo "1. Ve a AWS Console > S3 > Create bucket"
    echo "2. Elige un nombre único (ej: zappa-deployments-tu-nombre-123)"
    echo "3. Región: us-east-1"
    echo ""
    read -p "Ingresa el nombre del bucket S3: " NEW_BUCKET
    if [ ! -z "$NEW_BUCKET" ]; then
        S3_BUCKET=$NEW_BUCKET
    fi
else
    read -p "Ingresa el nombre de tu bucket S3: " NEW_BUCKET
    if [ ! -z "$NEW_BUCKET" ]; then
        S3_BUCKET=$NEW_BUCKET
    fi
fi

# 2. Información de RDS
echo ""
echo "🗄️  Paso 2: Información de RDS"
echo "--------------------------------"
echo "Necesitamos la siguiente información de tu cluster RDS Aurora:"
echo ""
read -p "DB Cluster Identifier (nombre del cluster): " RDS_CLUSTER
read -p "DB Endpoint (ej: cluster-xxxxx.us-east-1.rds.amazonaws.com): " RDS_ENDPOINT
read -p "Database Name (ej: vehicledb): " DB_NAME
read -p "DB Username (ej: admin): " DB_USER
read -s -p "DB Password: " DB_PASS
echo ""

# 3. Información de VPC
echo ""
echo "🌐 Paso 3: Configuración de VPC"
echo "-------------------------------"
echo "Para que Lambda se conecte a RDS, necesitan estar en la misma VPC"
echo ""
read -p "VPC ID donde está tu RDS (ej: vpc-xxxxx): " VPC_ID
echo ""
echo "Necesitas al menos 2 Subnets en diferentes zonas de disponibilidad"
read -p "Subnet ID 1 (ej: subnet-xxxxx): " SUBNET_1
read -p "Subnet ID 2 (ej: subnet-yyyyy): " SUBNET_2
echo ""
read -p "Security Group ID para Lambda (crea uno nuevo o usa existente, ej: sg-xxxxx): " LAMBDA_SG

# 4. API Key
echo ""
echo "🔑 Paso 4: API Key de ExchangeRates"
echo "------------------------------------"
read -p "API Key de ExchangeRates (apilayer.com): " API_KEY

# 5. Actualizar zappa_settings.json
echo ""
echo "📝 Actualizando configuración..."
python3 << EOF
import json

with open('zappa_settings.json', 'r') as f:
    config = json.load(f)

# Actualizar bucket S3
config['production']['s3_bucket'] = '$S3_BUCKET'

# Actualizar VPC config
config['production']['vpc_config'] = {
    "SubnetIds": ['$SUBNET_1', '$SUBNET_2'],
    "SecurityGroupIds": ['$LAMBDA_SG']
}

with open('zappa_settings.json', 'w') as f:
    json.dump(config, f, indent=4)

print("✅ zappa_settings.json actualizado")
EOF

# 6. Crear archivo con variables de entorno para referencia
cat > .env.deployment << EOF
# Variables de entorno para Lambda
# Copia estos valores a Lambda Console > Configuration > Environment variables

DB_HOST=$RDS_ENDPOINT
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASS=$DB_PASS
API_KEY_EXCHANGE=$API_KEY
EOF

echo "✅ Archivo .env.deployment creado con las variables de entorno"
echo ""

# 7. Resumen
echo "📋 Resumen de Configuración"
echo "============================"
echo "Bucket S3: $S3_BUCKET"
echo "RDS Cluster: $RDS_CLUSTER"
echo "RDS Endpoint: $RDS_ENDPOINT"
echo "Database: $DB_NAME"
echo "VPC ID: $VPC_ID"
echo "Subnets: $SUBNET_1, $SUBNET_2"
echo "Lambda Security Group: $LAMBDA_SG"
echo ""
echo "✅ Configuración completada!"
echo ""
echo "📋 Próximos pasos:"
echo "1. Verifica que el Security Group de RDS permita tráfico desde $LAMBDA_SG en puerto 5432"
echo "2. Ejecuta: ./scripts/deploy.sh para desplegar"
echo "3. Después del despliegue, configura las variables de entorno en Lambda Console"
echo "   (Los valores están en .env.deployment)"
echo ""

