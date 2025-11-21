#!/bin/bash

# Script simplificado para configurar la base de datos en Lambda
# Uso: ./scripts/setup_db_lambda.sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

FUNCTION_NAME="flask-lambda-app-production"

echo "🗄️  Configuración de Base de Datos en Lambda"
echo "============================================="
echo ""

# Verificar AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI no está instalado"
    exit 1
fi

# Verificar credenciales
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Error: No se pudieron validar las credenciales de AWS"
    echo "   Ejecuta: aws configure"
    exit 1
fi

# Verificar que la función Lambda existe
if ! aws lambda get-function --function-name "$FUNCTION_NAME" &> /dev/null; then
    echo "❌ Error: La función Lambda '$FUNCTION_NAME' no existe"
    echo ""
    echo "💡 Primero despliega la aplicación:"
    echo "   ./scripts/deploy.sh"
    exit 1
fi

echo "✅ Función Lambda encontrada: $FUNCTION_NAME"
echo ""

# Obtener información de RDS
echo "🔍 Buscando clusters RDS disponibles..."
echo ""

CLUSTERS=$(aws rds describe-db-clusters \
    --query 'DBClusters[*].[DBClusterIdentifier,Endpoint,Status]' \
    --output table 2>/dev/null || echo "")

if [ ! -z "$CLUSTERS" ] && [ "$CLUSTERS" != "None" ]; then
    echo "$CLUSTERS"
    echo ""
    read -p "Ingresa el DB Cluster Identifier: " RDS_CLUSTER
    
    if [ ! -z "$RDS_CLUSTER" ]; then
        echo ""
        echo "🔍 Obteniendo endpoint de RDS..."
        DB_HOST=$(aws rds describe-db-clusters \
            --db-cluster-identifier "$RDS_CLUSTER" \
            --query 'DBClusters[0].Endpoint' \
            --output text 2>/dev/null || echo "")
        
        if [ ! -z "$DB_HOST" ] && [ "$DB_HOST" != "None" ]; then
            echo "✅ Endpoint obtenido: $DB_HOST"
        else
            echo "❌ No se pudo obtener el endpoint"
            read -p "Ingresa el DB Endpoint manualmente: " DB_HOST
        fi
    else
        read -p "Ingresa el DB Endpoint: " DB_HOST
    fi
else
    echo "⚠️  No se encontraron clusters RDS"
    read -p "Ingresa el DB Endpoint manualmente: " DB_HOST
fi

echo ""
read -p "Database Name (ej: vehicledb): " DB_NAME
read -p "DB Username (ej: admin): " DB_USER
read -s -p "DB Password: " DB_PASS
echo ""

# Leer API Key si existe en .env.deployment
if [ -f ".env.deployment" ]; then
    source .env.deployment
fi

if [ -z "$API_KEY_EXCHANGE" ]; then
    read -p "API Key de ExchangeRates (opcional, presiona Enter para omitir): " API_KEY_EXCHANGE
fi

# Validar variables requeridas
if [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
    echo ""
    echo "❌ Error: Faltan variables requeridas"
    exit 1
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

read -p "¿Configurar estas variables en Lambda? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

echo ""
echo "📝 Configurando variables de entorno..."

# Construir JSON de variables de entorno
if [ ! -z "$API_KEY_EXCHANGE" ]; then
    ENV_JSON=$(jq -n \
        --arg host "$DB_HOST" \
        --arg name "$DB_NAME" \
        --arg user "$DB_USER" \
        --arg pass "$DB_PASS" \
        --arg api "$API_KEY_EXCHANGE" \
        '{
            Variables: {
                DB_HOST: $host,
                DB_NAME: $name,
                DB_USER: $user,
                DB_PASS: $pass,
                API_KEY_EXCHANGE: $api
            }
        }' 2>/dev/null || cat <<EOF
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
    ENV_JSON=$(jq -n \
        --arg host "$DB_HOST" \
        --arg name "$DB_NAME" \
        --arg user "$DB_USER" \
        --arg pass "$DB_PASS" \
        '{
            Variables: {
                DB_HOST: $host,
                DB_NAME: $name,
                DB_USER: $user,
                DB_PASS: $pass
            }
        }' 2>/dev/null || cat <<EOF
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

# Actualizar Lambda
if aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --environment "$ENV_JSON" &> /dev/null; then
    echo "✅ Variables de entorno configuradas exitosamente"
    echo ""
    
    # Verificar configuración
    echo "🔍 Verificando configuración..."
    aws lambda get-function-configuration \
        --function-name "$FUNCTION_NAME" \
        --query 'Environment.Variables' \
        --output table
    
    echo ""
    echo "✅ ¡Configuración completada!"
    echo ""
    echo "💡 Próximos pasos:"
    echo "1. Verifica que el Security Group de RDS permita tráfico desde Lambda"
    echo "2. Prueba tu aplicación:"
    echo "   zappa status production"
    echo ""
else
    echo "❌ Error al configurar variables de entorno"
    echo ""
    echo "📋 Configura manualmente en AWS Console:"
    echo "1. Ve a AWS Console > Lambda > $FUNCTION_NAME"
    echo "2. Configuration > Environment variables > Edit"
    echo "3. Agrega las variables:"
    echo "   DB_HOST = $DB_HOST"
    echo "   DB_NAME = $DB_NAME"
    echo "   DB_USER = $DB_USER"
    echo "   DB_PASS = $DB_PASS"
    if [ ! -z "$API_KEY_EXCHANGE" ]; then
        echo "   API_KEY_EXCHANGE = $API_KEY_EXCHANGE"
    fi
    echo "4. Click en 'Save'"
fi

echo ""

