#!/bin/bash

# Script para configurar acceso público a RDS y Security Groups
# Uso: ./scripts/fix_rds_access.sh

CLUSTER_ID="database-lab-07"
REGION="us-east-2"

echo "🔧 Configurando acceso a RDS..."

# 1. Habilitar acceso público
echo "📡 Habilitando acceso público..."
aws rds modify-db-cluster \
    --db-cluster-identifier $CLUSTER_ID \
    --region $REGION \
    --publicly-accessible \
    --apply-immediately

# 2. Obtener tu IP pública
MY_IP=$(curl -s ifconfig.me)
echo "📍 Tu IP pública: $MY_IP"

# 3. Obtener Security Group ID de RDS
echo "🔍 Buscando Security Group de RDS..."
RDS_SG_ID=$(aws rds describe-db-clusters \
    --db-cluster-identifier $CLUSTER_ID \
    --region $REGION \
    --query 'DBClusters[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
    --output text)

if [ -z "$RDS_SG_ID" ] || [ "$RDS_SG_ID" == "None" ]; then
    echo "❌ No se encontró Security Group. Verifica en AWS Console."
    exit 1
fi

echo "✓ Security Group encontrado: $RDS_SG_ID"

# 4. Agregar regla de inbound para tu IP
echo "🔐 Agregando regla de seguridad para tu IP..."
aws ec2 authorize-security-group-ingress \
    --group-id $RDS_SG_ID \
    --protocol tcp \
    --port 5432 \
    --cidr "$MY_IP/32" \
    --region $REGION 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Regla agregada exitosamente para $MY_IP"
else
    echo "⚠️  La regla puede que ya exista o hubo un error. Verifica manualmente."
fi

echo ""
echo "✅ Configuración completada!"
echo "⏳ Espera 2-3 minutos para que los cambios se apliquen."
echo ""
echo "📝 Para probar la conexión:"
echo "psql -h database-lab-07.cluster-c92uuqwoiml2.us-east-2.rds.amazonaws.com -U postgres -d postgres"

