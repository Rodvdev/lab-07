#!/bin/bash

# Script para configurar variables de entorno en Lambda
# Uso: ./scripts/set_lambda_env_vars.sh [--interactive]

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

FUNCTION_NAME="flask-lambda-app-production"

echo "🔧 Configurando Variables de Entorno en Lambda"
echo "=============================================="
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
    echo "   Primero despliega la aplicación: ./scripts/deploy.sh"
    exit 1
fi

echo "✅ Función Lambda encontrada: $FUNCTION_NAME"
echo ""

# Intentar leer desde .env.deployment
if [ -f ".env.deployment" ]; then
    echo "📋 Leyendo configuración desde .env.deployment..."
    source .env.deployment
    USE_EXISTING=true
else
    USE_EXISTING=false
    echo "⚠️  No se encontró .env.deployment"
    echo ""
fi

# Modo interactivo si se solicita o si no hay .env.deployment
if [ "$1" == "--interactive" ] || [ "$USE_EXISTING" == false ]; then
    echo "📝 Modo interactivo - Ingresa la información de la base de datos:"
    echo ""
    
    # Obtener endpoint de RDS
    echo "🔍 Buscando clusters RDS disponibles..."
    CLUSTERS=$(aws rds describe-db-clusters --query 'DBClusters[*].[DBClusterIdentifier,Endpoint,Status]' --output table 2>/dev/null || echo "")
    
    if [ ! -z "$CLUSTERS" ] && [ "$CLUSTERS" != "None" ]; then
        echo "$CLUSTERS"
        echo ""
        read -p "Ingresa el DB Cluster Identifier (o presiona Enter para ingresar endpoint manualmente): " RDS_CLUSTER
        
        if [ ! -z "$RDS_CLUSTER" ]; then
            DB_HOST=$(aws rds describe-db-clusters \
                --db-cluster-identifier "$RDS_CLUSTER" \
                --query 'DBClusters[0].Endpoint' \
                --output text 2>/dev/null || echo "")
            
            if [ ! -z "$DB_HOST" ] && [ "$DB_HOST" != "None" ]; then
                echo "✅ Endpoint obtenido: $DB_HOST"
            else
                echo "⚠️  No se pudo obtener el endpoint automáticamente"
                read -p "Ingresa el DB Endpoint manualmente: " DB_HOST
            fi
        else
            read -p "Ingresa el DB Endpoint: " DB_HOST
        fi
    else
        read -p "Ingresa el DB Endpoint: " DB_HOST
    fi
    
    read -p "Database Name (ej: vehicledb): " DB_NAME
    read -p "DB Username (ej: admin): " DB_USER
    read -s -p "DB Password: " DB_PASS
    echo ""
    
    # API Key
    if [ -z "$API_KEY_EXCHANGE" ]; then
        read -p "API Key de ExchangeRates (apilayer.com): " API_KEY_EXCHANGE
    fi
fi

# Validar que todas las variables estén definidas
if [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
    echo "❌ Error: Faltan variables requeridas"
    echo "   Requeridas: DB_HOST, DB_NAME, DB_USER, DB_PASS"
    exit 1
fi

echo ""
echo "📋 Variables a configurar:"
echo "  - DB_HOST: $DB_HOST"
echo "  - DB_NAME: $DB_NAME"
echo "  - DB_USER: $DB_USER"
echo "  - DB_PASS: [oculto]"
if [ ! -z "$API_KEY_EXCHANGE" ]; then
    echo "  - API_KEY_EXCHANGE: [oculto]"
fi
echo ""

read -p "¿Deseas continuar? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

echo ""
echo "📝 Configurando variables de entorno en Lambda..."

# Construir el JSON de variables de entorno
if [ ! -z "$API_KEY_EXCHANGE" ]; then
    ENV_VARS=$(cat <<EOF
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
    ENV_VARS=$(cat <<EOF
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

# Intentar actualizar usando AWS CLI
echo "🔄 Actualizando configuración de Lambda..."
if aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --environment "$ENV_VARS" 2>&1 | tee /tmp/lambda_update.log; then
    echo ""
    echo "✅ Variables de entorno configuradas exitosamente"
    echo ""
    
    # Verificar la configuración
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
    echo "2. Prueba tu aplicación: zappa status production"
    echo "3. Accede a la URL de API Gateway para probar los endpoints"
else
    ERROR=$(cat /tmp/lambda_update.log)
    echo ""
    echo "⚠️  No se pudieron configurar las variables desde CLI"
    echo "   Error: $ERROR"
    echo ""
    echo "📋 Configura las variables manualmente en AWS Console:"
    echo "1. Ve a AWS Console > Lambda > $FUNCTION_NAME"
    echo "2. Configuration > Environment variables"
    echo "3. Click en 'Edit'"
    echo "4. Agrega las siguientes variables:"
    echo ""
    echo "   DB_HOST = $DB_HOST"
    echo "   DB_NAME = $DB_NAME"
    echo "   DB_USER = $DB_USER"
    echo "   DB_PASS = $DB_PASS"
    if [ ! -z "$API_KEY_EXCHANGE" ]; then
        echo "   API_KEY_EXCHANGE = $API_KEY_EXCHANGE"
    fi
    echo ""
    echo "5. Click en 'Save'"
fi

echo ""

