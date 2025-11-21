# Guía Rápida de Despliegue

Esta guía proporciona los comandos esenciales para desplegar la aplicación en AWS Lambda. Para instrucciones detalladas, consulta `GUIA_DESPLIEGUE_AWS.md`.

## 🚀 Inicio Rápido

### 1. Verificar Prerrequisitos

```bash
./scripts/check_prerequisites.sh
```

### 2. Instalar y Configurar AWS CLI (si no está instalado)

```bash
./scripts/setup_aws.sh
```

### 3. Crear Bucket S3

```bash
./scripts/create_s3_bucket.sh zappa-deployments-tu-nombre-unico
```

**Importante**: El nombre del bucket debe ser único globalmente.

### 4. Crear RDS Aurora PostgreSQL

Ve a AWS Console > RDS > Create database y crea un cluster Aurora PostgreSQL Serverless v2 con:

- **Engine**: Amazon Aurora PostgreSQL-Compatible Edition
- **DB cluster identifier**: `flask-lambda-db-cluster`
- **Master username**: `admin`
- **Database name**: `vehicledb`
- **VPC**: Tu VPC existente o nueva
- **Public access**: No (recomendado)

### 5. Obtener Información de VPC

```bash
./scripts/get_vpc_info.sh
```

Anota los Subnet IDs y Security Group IDs.

### 6. Configurar zappa_settings.json

Edita `zappa_settings.json` y actualiza:

- `SubnetIds`: Al menos 2 subnets de diferentes zonas
- `SecurityGroupIds`: Security group de Lambda

### 7. Configurar Base de Datos

Conéctate a RDS y ejecuta el schema:

```bash
# Si RDS tiene acceso público temporal
psql -h [DB_ENDPOINT] -U admin -d vehicledb -f schema.sql

# Obtener endpoint con:
./scripts/get_rds_endpoint.sh flask-lambda-db-cluster
```

### 8. Configurar Security Groups

1. RDS Security Group: Permitir inbound en puerto 5432 desde Lambda Security Group
2. Lambda Security Group: Asegurar que esté en la misma VPC

### 9. Desplegar en Lambda

```bash
./scripts/deploy.sh
```

### 10. Configurar Variables de Entorno en Lambda

1. Ve a AWS Console > Lambda > flask-lambda-app-production
2. Configuration > Environment variables
3. Agregar:
   - `API_KEY_EXCHANGE`: Tu clave de ExchangeRates API
   - `DB_HOST`: Endpoint de RDS
   - `DB_NAME`: `vehicledb`
   - `DB_USER`: `admin`
   - `DB_PASS`: Tu contraseña de RDS

### 11. Verificar Despliegue

```bash
# Obtener URL
zappa status production

# Ver logs
zappa tail production

# Probar endpoints
curl $(zappa status production | grep "API Gateway URL" | awk '{print $4}')
```

## 📋 Checklist

- [ ] AWS CLI instalado y configurado
- [ ] Bucket S3 creado
- [ ] RDS Aurora PostgreSQL creado
- [ ] Base de datos configurada (schema.sql ejecutado)
- [ ] VPC y Security Groups configurados
- [ ] zappa_settings.json actualizado con VPC config
- [ ] Despliegue completado
- [ ] Variables de entorno configuradas en Lambda
- [ ] Aplicación funcionando

## 🔧 Scripts Disponibles

- `scripts/setup_aws.sh` - Instalar y configurar AWS CLI
- `scripts/check_prerequisites.sh` - Verificar prerrequisitos
- `scripts/create_s3_bucket.sh` - Crear bucket S3
- `scripts/get_vpc_info.sh` - Obtener información de VPC
- `scripts/get_rds_endpoint.sh` - Obtener endpoint de RDS
- `scripts/deploy.sh` - Desplegar en Lambda

## ❓ Problemas Comunes

Ver sección "Solución de Problemas" en `GUIA_DESPLIEGUE_AWS.md`

