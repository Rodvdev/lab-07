#!/bin/bash

# Script principal de despliegue
# Este script guía el proceso de despliegue paso a paso

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "🚀 Iniciando despliegue en AWS Lambda"
echo "======================================"
echo ""

# Verificar que estamos en el directorio correcto
if [ ! -f "app.py" ] || [ ! -f "zappa_settings.json" ]; then
    echo "❌ Error: No se encontraron app.py o zappa_settings.json"
    echo "   Asegúrate de ejecutar este script desde el directorio raíz del proyecto"
    exit 1
fi

# Verificar AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI no está instalado"
    echo "   Ejecuta: ./scripts/setup_aws.sh"
    exit 1
fi

# Verificar credenciales AWS
echo "🔍 Verificando credenciales de AWS..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Error: No se pudieron validar las credenciales de AWS"
    echo "   Ejecuta: aws configure"
    exit 1
fi
echo "✅ Credenciales válidas"
echo ""

# Verificar entorno virtual
if [ ! -d "venv" ]; then
    echo "📦 Creando entorno virtual..."
    python3 -m venv venv
fi

echo "📦 Activando entorno virtual..."
source venv/bin/activate

# Verificar dependencias
echo "📦 Verificando dependencias..."
pip install -q -r requirements.txt

# Verificar Zappa
if ! command -v zappa &> /dev/null; then
    echo "❌ Zappa no está instalado"
    echo "   Instalando..."
    pip install zappa
fi

echo ""
echo "📋 Verificando configuración de Zappa..."

# Verificar que zappa_settings.json tenga valores válidos
S3_BUCKET=$(python3 -c "import json; print(json.load(open('zappa_settings.json'))['production']['s3_bucket'])")
if [ "$S3_BUCKET" == "zappa-deployments" ]; then
    echo "⚠️  Advertencia: El bucket S3 en zappa_settings.json es el valor por defecto"
    echo "   Debes crear un bucket único primero:"
    echo "   ./scripts/create_s3_bucket.sh [tu-nombre-unico]"
    read -p "¿Deseas continuar de todos modos? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Verificar VPC config
SUBNETS=$(python3 -c "import json; print(len(json.load(open('zappa_settings.json'))['production']['vpc_config']['SubnetIds']))")
if [ "$SUBNETS" -eq 0 ]; then
    echo "⚠️  Advertencia: No hay subnets configuradas en zappa_settings.json"
    echo "   Si tu RDS está en una VPC, necesitas configurar VPC en zappa_settings.json"
    echo "   Ejecuta: ./scripts/get_vpc_info.sh"
fi

echo ""
read -p "¿Deseas continuar con el despliegue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

echo ""
echo "🚀 Desplegando en Lambda..."
echo ""

# Verificar si ya existe el despliegue
if zappa status production &> /dev/null; then
    echo "📝 Despliegue existente detectado, actualizando..."
    zappa update production
else
    echo "🆕 Creando nuevo despliegue..."
    zappa deploy production
fi

echo ""
echo "✅ ¡Despliegue completado!"
echo ""
echo "📋 Próximos pasos:"
echo "1. Configura las variables de entorno en Lambda Console"
echo "2. Verifica la configuración de VPC en Lambda Console"
echo "3. Prueba tu aplicación con: zappa status production"
echo ""

