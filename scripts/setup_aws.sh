#!/bin/bash

# Script para configurar AWS CLI
# Este script ayuda a instalar y configurar AWS CLI

set -e

echo "🔧 Configurando AWS CLI..."

# Verificar si AWS CLI está instalado
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI no está instalado"
    echo ""
    echo "Instalando AWS CLI..."
    
    # Detectar sistema operativo
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            echo "Instalando con Homebrew..."
            brew install awscli
        else
            echo "Por favor instala Homebrew primero o instala AWS CLI manualmente"
            echo "Ver: https://aws.amazon.com/cli/"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        echo "Instalando con apt-get..."
        sudo apt-get update
        sudo apt-get install -y awscli
    else
        echo "Sistema operativo no soportado. Por favor instala AWS CLI manualmente"
        echo "Ver: https://aws.amazon.com/cli/"
        exit 1
    fi
else
    echo "✅ AWS CLI ya está instalado"
    aws --version
fi

echo ""
echo "🔑 Configurando credenciales de AWS..."
echo "Por favor ingresa tus credenciales cuando se solicite:"
echo "  - AWS Access Key ID"
echo "  - AWS Secret Access Key"
echo "  - Default region: us-east-1"
echo "  - Default output format: json"
echo ""

# Configurar AWS CLI
aws configure

echo ""
echo "✅ Verificando configuración..."
aws sts get-caller-identity

echo ""
echo "✅ AWS CLI configurado exitosamente!"

