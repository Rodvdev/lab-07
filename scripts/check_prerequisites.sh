#!/bin/bash

# Script para verificar todos los prerrequisitos antes del despliegue

set -e

echo "🔍 Verificando prerrequisitos para el despliegue"
echo "================================================"
echo ""

ERRORS=0

# Verificar Python
echo -n "✅ Python: "
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo "$PYTHON_VERSION"
else
    echo "❌ NO INSTALADO"
    ERRORS=$((ERRORS + 1))
fi

# Verificar pip
echo -n "✅ pip: "
if command -v pip3 &> /dev/null || python3 -m pip --version &> /dev/null; then
    echo "INSTALADO"
else
    echo "❌ NO INSTALADO"
    ERRORS=$((ERRORS + 1))
fi

# Verificar AWS CLI
echo -n "✅ AWS CLI: "
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version)
    echo "$AWS_VERSION"
    
    # Verificar credenciales
    echo -n "✅ AWS Credentials: "
    if aws sts get-caller-identity &> /dev/null; then
        AWS_ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text)
        echo "CONFIGURADAS (Account: $AWS_ACCOUNT)"
    else
        echo "❌ NO CONFIGURADAS (ejecuta: aws configure)"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "❌ NO INSTALADO (ejecuta: ./scripts/setup_aws.sh)"
    ERRORS=$((ERRORS + 1))
fi

# Verificar entorno virtual
echo -n "✅ Virtual Environment: "
if [ -d "venv" ]; then
    echo "CREADO"
    
    # Verificar dependencias
    echo -n "✅ Dependencias: "
    if [ -f "venv/bin/activate" ]; then
        source venv/bin/activate
        if python3 -c "import flask, zappa, psycopg2" &> /dev/null; then
            echo "INSTALADAS"
        else
            echo "⚠️  INCOMPLETAS (ejecuta: pip install -r requirements.txt)"
        fi
        deactivate
    else
        echo "❌ NO CONFIGURADO CORRECTAMENTE"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "⚠️  NO CREADO (ejecuta: python3 -m venv venv)"
fi

# Verificar archivos del proyecto
echo -n "✅ app.py: "
if [ -f "app.py" ]; then
    echo "EXISTE"
else
    echo "❌ NO ENCONTRADO"
    ERRORS=$((ERRORS + 1))
fi

echo -n "✅ zappa_settings.json: "
if [ -f "zappa_settings.json" ]; then
    echo "EXISTE"
    
    # Verificar bucket S3
    S3_BUCKET=$(python3 -c "import json; print(json.load(open('zappa_settings.json'))['production']['s3_bucket'])" 2>/dev/null || echo "")
    if [ -n "$S3_BUCKET" ] && [ "$S3_BUCKET" != "zappa-deployments" ]; then
        echo "   📦 Bucket S3: $S3_BUCKET"
    else
        echo "   ⚠️  Bucket S3 no configurado (valor por defecto)"
    fi
else
    echo "❌ NO ENCONTRADO"
    ERRORS=$((ERRORS + 1))
fi

echo -n "✅ requirements.txt: "
if [ -f "requirements.txt" ]; then
    echo "EXISTE"
else
    echo "❌ NO ENCONTRADO"
    ERRORS=$((ERRORS + 1))
fi

echo -n "✅ schema.sql: "
if [ -f "schema.sql" ]; then
    echo "EXISTE"
else
    echo "⚠️  NO ENCONTRADO (necesario para configurar la base de datos)"
fi

echo ""
echo "================================================"
if [ $ERRORS -eq 0 ]; then
    echo "✅ Todos los prerrequisitos están listos"
    echo ""
    echo "📋 Próximos pasos:"
    echo "1. Crear bucket S3: ./scripts/create_s3_bucket.sh [nombre-unico]"
    echo "2. Crear RDS Aurora PostgreSQL en AWS Console"
    echo "3. Configurar VPC y Security Groups"
    echo "4. Ejecutar schema.sql en la base de datos"
    echo "5. Actualizar zappa_settings.json con VPC config"
    echo "6. Desplegar: ./scripts/deploy.sh"
else
    echo "❌ Se encontraron $ERRORS error(es)"
    echo "   Por favor corrige los errores antes de continuar"
    exit 1
fi

