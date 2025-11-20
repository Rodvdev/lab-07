#!/bin/bash

# Script para obtener el endpoint de RDS Aurora
# Uso: ./scripts/get_rds_endpoint.sh [cluster-identifier]

set -e

CLUSTER_ID=${1:-"flask-lambda-db-cluster"}

echo "🔍 Obteniendo endpoint de RDS Aurora..."
echo "Cluster identifier: $CLUSTER_ID"
echo ""

ENDPOINT=$(aws rds describe-db-clusters \
    --db-cluster-identifier $CLUSTER_ID \
    --query 'DBClusters[0].Endpoint' \
    --output text 2>/dev/null)

if [ -z "$ENDPOINT" ] || [ "$ENDPOINT" == "None" ]; then
    echo "❌ No se pudo obtener el endpoint del cluster: $CLUSTER_ID"
    echo ""
    echo "Clusters disponibles:"
    aws rds describe-db-clusters \
        --query 'DBClusters[*].[DBClusterIdentifier,Endpoint,Status]' \
        --output table
    exit 1
fi

echo "✅ Endpoint de RDS:"
echo "   $ENDPOINT"
echo ""
echo "💡 Usa este endpoint como DB_HOST en las variables de entorno de Lambda"

