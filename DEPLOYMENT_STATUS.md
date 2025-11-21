# Estado del Despliegue

## ✅ Preparación Completada

### Archivos y Scripts Creados

1. **Scripts de Automatización** (`scripts/`):
   - `setup_aws.sh` - Instalar y configurar AWS CLI
   - `check_prerequisites.sh` - Verificar prerrequisitos
   - `create_s3_bucket.sh` - Crear bucket S3 para Zappa
   - `get_vpc_info.sh` - Obtener información de VPC y subnets
   - `get_rds_endpoint.sh` - Obtener endpoint de RDS Aurora
   - `deploy.sh` - Script principal de despliegue

2. **Configuración Actualizada**:
   - `zappa_settings.json` - Actualizado según la guía (sin variables de entorno iniciales)
   - `.env.example` - Archivo de ejemplo para variables de entorno

3. **Documentación**:
   - `QUICK_START.md` - Guía rápida de despliegue
   - `GUIA_DESPLIEGUE_AWS.md` - Guía completa (ya existía)

### Entorno Preparado

- ✅ Entorno virtual creado (`venv/`)
- ✅ Dependencias instaladas (Flask, Zappa, psycopg2, etc.)
- ✅ Python 3.9.6 disponible
- ✅ Estructura del proyecto lista

## 📋 Próximos Pasos

### Paso 1: Instalar y Configurar AWS CLI

```bash
./scripts/setup_aws.sh
```

O manualmente:
```bash
brew install awscli  # macOS
aws configure
```

### Paso 2: Verificar Prerrequisitos

```bash
./scripts/check_prerequisites.sh
```

### Paso 3: Crear Bucket S3

```bash
./scripts/create_s3_bucket.sh zappa-deployments-tu-nombre-unico
```

**Nota**: El nombre del bucket debe ser único globalmente. Usa un nombre personalizado.

### Paso 4: Crear RDS Aurora PostgreSQL

Ve a AWS Console y crea el cluster:

1. AWS Console > RDS > Create database
2. Configuración:
   - Engine: Amazon Aurora PostgreSQL-Compatible Edition
   - DB cluster identifier: `flask-lambda-db-cluster`
   - Master username: `admin`
   - Database name: `vehicledb`
   - VPC: Tu VPC existente o nueva
   - Public access: No (recomendado)

### Paso 5: Configurar VPC y Security Groups

```bash
./scripts/get_vpc_info.sh
```

Anota los Subnet IDs y Security Group IDs, luego actualiza `zappa_settings.json`:

```json
"vpc_config": {
    "SubnetIds": ["subnet-xxxxx", "subnet-yyyyy"],
    "SecurityGroupIds": ["sg-xxxxx"]
}
```

**Importante**: Configura los Security Groups:
- RDS SG: Permitir inbound en puerto 5432 desde Lambda SG
- Lambda SG: Asegurar que esté en la misma VPC

### Paso 6: Configurar Base de Datos

```bash
# Obtener endpoint de RDS
./scripts/get_rds_endpoint.sh flask-lambda-db-cluster

# Ejecutar schema (si RDS tiene acceso público temporal)
psql -h [DB_ENDPOINT] -U admin -d vehicledb -f schema.sql
```

### Paso 7: Desplegar en Lambda

```bash
./scripts/deploy.sh
```

O manualmente:
```bash
source venv/bin/activate
zappa deploy production
```

### Paso 8: Configurar Variables de Entorno en Lambda

1. Ve a AWS Console > Lambda > flask-lambda-app-production
2. Configuration > Environment variables > Edit
3. Agregar:
   - `API_KEY_EXCHANGE`: Tu clave de ExchangeRates API
   - `DB_HOST`: Endpoint de RDS
   - `DB_NAME`: `vehicledb`
   - `DB_USER`: `admin`
   - `DB_PASS`: Tu contraseña de RDS

### Paso 9: Verificar Despliegue

```bash
# Obtener URL
zappa status production

# Ver logs
zappa tail production

# Probar endpoints
curl $(zappa status production | grep "API Gateway URL" | awk '{print $4}')
```

## 🔍 Estado Actual

### Prerrequisitos

- ✅ Python 3.9.6 instalado
- ✅ Entorno virtual creado
- ✅ Dependencias instaladas
- ⚠️ AWS CLI no instalado (requiere instalación manual)
- ⚠️ Bucket S3 no configurado (necesita nombre único)

### Archivos del Proyecto

- ✅ `app.py` - Aplicación Flask
- ✅ `zappa_settings.json` - Configuración de Zappa
- ✅ `requirements.txt` - Dependencias Python
- ✅ `schema.sql` - Esquema de base de datos
- ✅ Templates HTML
- ✅ Scripts de automatización

## 📚 Documentación

- **Guía Completa**: `GUIA_DESPLIEGUE_AWS.md`
- **Guía Rápida**: `QUICK_START.md`
- **Estado Actual**: Este archivo

## 🚀 Comandos Rápidos

```bash
# Verificar estado
./scripts/check_prerequisites.sh

# Crear bucket S3
./scripts/create_s3_bucket.sh [nombre-unico]

# Obtener info de VPC
./scripts/get_vpc_info.sh

# Obtener endpoint de RDS
./scripts/get_rds_endpoint.sh [cluster-id]

# Desplegar
./scripts/deploy.sh

# Ver logs
source venv/bin/activate && zappa tail production
```

## ⚠️ Notas Importantes

1. **Bucket S3**: Debe tener un nombre único globalmente
2. **RDS**: Necesita estar en una VPC privada (no público para producción)
3. **VPC**: Lambda debe estar en la misma VPC que RDS
4. **Security Groups**: RDS debe permitir conexiones desde Lambda SG
5. **Variables de Entorno**: Se configuran después del primer despliegue en Lambda Console

## 🆘 Solución de Problemas

Consulta la sección "Solución de Problemas" en `GUIA_DESPLIEGUE_AWS.md` para problemas comunes.

