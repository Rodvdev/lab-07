#!/bin/bash

# Script para configurar variables de entorno en Lambda
# Uso: ./scripts/set_lambda_env_vars.sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

FUNCTION_NAME="flask-lambda-app-production"

echo "🔧 Configurando Variables de Entorno en Lambda"
echo "=============================================="
echo ""

# Verificar que existe .env.deployment
if [ ! -f ".env.deployment" ]; then
    echo "❌ No se encontró .env.deployment"
    echo "   Ejecuta primero: ./scripts/configure_deployment.sh"
    exit 1
fi

# Leer variables del archivo
source .env.deployment

echo "Función Lambda: $FUNCTION_NAME"
echo ""
echo "Variables a configurar:"
echo "  - DB_HOST: $DB_HOST"
echo "  - DB_NAME: $DB_NAME"
echo "  - DB_USER: $DB_USER"
echo "  - DB_PASS: [oculto]"
echo "  - API_KEY_EXCHANGE: [oculto]"
echo ""

read -p "¿Deseas continuar? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

echo ""
echo "📝 Configurando variables de entorno..."

# Construir el JSON de variables de entorno
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

# Intentar actualizar usando AWS CLI
if aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --environment "$ENV_VARS" &> /dev/null; then
    echo "✅ Variables de entorno configuradas exitosamente"
else
    echo "⚠️  No se pudieron configurar las variables desde CLI (puede ser un problema de permisos)"
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
    echo "   API_KEY_EXCHANGE = $API_KEY_EXCHANGE"
    echo ""
    echo "5. Click en 'Save'"
fi

echo ""
echo "✅ Proceso completado"

