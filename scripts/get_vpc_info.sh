#!/bin/bash

# Script para obtener información de VPC, Subnets y Security Groups
# Útil para configurar zappa_settings.json

set -e

echo "🔍 Obteniendo información de VPC..."

echo ""
echo "📋 VPCs disponibles:"
echo "==================="
aws ec2 describe-vpcs \
    --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
    --output table

echo ""
read -p "Ingresa el VPC ID donde está tu RDS: " VPC_ID

if [ -z "$VPC_ID" ]; then
    echo "❌ VPC ID no puede estar vacío"
    exit 1
fi

echo ""
echo "📋 Subnets en VPC $VPC_ID:"
echo "=========================="
aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]' \
    --output table

echo ""
echo "📋 Security Groups en VPC $VPC_ID:"
echo "=================================="
aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'SecurityGroups[*].[GroupId,GroupName,Description]' \
    --output table

echo ""
echo "✅ Información obtenida"
echo ""
echo "💡 Usa estos valores para actualizar zappa_settings.json:"
echo "   - VPC ID: $VPC_ID"
echo "   - Subnet IDs: (selecciona al menos 2 de diferentes zonas)"
echo "   - Security Group ID: (del security group de Lambda)"

