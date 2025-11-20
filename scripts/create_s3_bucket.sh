#!/bin/bash

# Script para crear bucket S3 para Zappa
# Uso: ./scripts/create_s3_bucket.sh [bucket-name]

set -e

REGION="us-east-1"
BUCKET_NAME=${1:-"zappa-deployments-$(date +%s)"}

echo "🪣 Creando bucket S3 para Zappa..."
echo "Bucket name: $BUCKET_NAME"
echo "Region: $REGION"
echo ""

# Crear bucket
aws s3 mb s3://$BUCKET_NAME --region $REGION

echo ""
echo "✅ Bucket creado exitosamente: $BUCKET_NAME"
echo ""
echo "📝 Actualizando zappa_settings.json..."

# Actualizar zappa_settings.json con el nombre del bucket
cd "$(dirname "$0")/.."

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/\"s3_bucket\": \".*\"/\"s3_bucket\": \"$BUCKET_NAME\"/" zappa_settings.json
else
    # Linux
    sed -i "s/\"s3_bucket\": \".*\"/\"s3_bucket\": \"$BUCKET_NAME\"/" zappa_settings.json
fi

echo "✅ zappa_settings.json actualizado"
echo ""
echo "Verifica el bucket con:"
echo "  aws s3 ls s3://$BUCKET_NAME"

