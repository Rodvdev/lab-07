# Guía Completa de Despliegue en AWS Lambda con RDS Aurora PostgreSQL

Esta guía paso a paso te ayudará a desplegar completamente la aplicación Flask en AWS Lambda y conectarla con RDS Aurora PostgreSQL.

## Índice

1. [Prerrequisitos](#prerrequisitos)
2. [Paso 1: Configuración de AWS CLI](#paso-1-configuración-de-aws-cli)
3. [Paso 2: Crear Bucket S3 para Zappa](#paso-2-crear-bucket-s3-para-zappa)
4. [Paso 3: Configurar RDS Aurora PostgreSQL](#paso-3-configurar-rds-aurora-postgresql)
5. [Paso 4: Configurar VPC y Security Groups](#paso-4-configurar-vpc-y-security-groups)
6. [Paso 5: Configurar Base de Datos](#paso-5-configurar-base-de-datos)
7. [Paso 6: Configurar Zappa Settings](#paso-6-configurar-zappa-settings)
8. [Paso 7: Configurar Variables de Entorno](#paso-7-configurar-variables-de-entorno)
9. [Paso 8: Desplegar en Lambda](#paso-8-desplegar-en-lambda)
10. [Paso 9: Configurar API Gateway](#paso-9-configurar-api-gateway)
11. [Paso 10: Verificar y Probar](#paso-10-verificar-y-probar)
12. [Solución de Problemas](#solución-de-problemas)

---

## Prerrequisitos

Antes de comenzar, asegúrate de tener:

- ✅ Cuenta de AWS con permisos de administrador o permisos para:
  - Lambda
  - API Gateway
  - RDS
  - VPC
  - IAM
  - S3
- ✅ Python 3.9+ instalado
- ✅ AWS CLI instalado y configurado
- ✅ Clave API de ExchangeRates (de apilayer.com)
- ✅ Acceso SSH o terminal a tu máquina local

---

## Paso 1: Configuración de AWS CLI

### 1.1 Instalar AWS CLI (si no está instalado)

```bash
# macOS
brew install awscli

# Linux
sudo apt-get update
sudo apt-get install awscli

# Verificar instalación
aws --version
```

### 1.2 Configurar credenciales de AWS

```bash
aws configure
```

Ingresa la siguiente información cuando se solicite:

```
AWS Access Key ID: [TU_ACCESS_KEY_ID]
AWS Secret Access Key: [TU_SECRET_ACCESS_KEY]
Default region name: us-east-1
Default output format: json
```

**Nota**: Puedes obtener tus credenciales desde la consola de AWS > IAM > Users > Security credentials

### 1.3 Verificar configuración

```bash
aws sts get-caller-identity
```

Deberías ver información sobre tu cuenta AWS.

---

## Paso 2: Crear Bucket S3 para Zappa

Zappa necesita un bucket S3 para almacenar los paquetes de despliegue.

### 2.1 Crear bucket S3

```bash
# Reemplaza 'zappa-deployments-tu-nombre-unico' con un nombre único
aws s3 mb s3://zappa-deployments-tu-nombre-unico --region us-east-1
```

**Importante**: El nombre del bucket debe ser único globalmente. Usa un nombre personalizado.

### 2.2 Actualizar zappa_settings.json

Edita `zappa_settings.json` y reemplaza el nombre del bucket:

```json
{
    "production": {
        ...
        "s3_bucket": "zappa-deployments-tu-nombre-unico",
        ...
    }
}
```

### 2.3 Verificar bucket creado

```bash
aws s3 ls
```

Deberías ver tu bucket en la lista.

---

## Paso 3: Configurar RDS Aurora PostgreSQL

### 3.1 Crear Cluster de Aurora PostgreSQL Serverless v2

#### Opción A: Usando AWS Console

1. Ve a **AWS Console** > **RDS** > **Databases**
2. Click en **Create database**
3. Selecciona **Create database**
4. Configuración:
   - **Engine type**: Amazon Aurora
   - **Edition**: Amazon Aurora PostgreSQL-Compatible Edition
   - **Version**: PostgreSQL 13.x o superior
   - **Templates**: Dev/Test (para pruebas) o Production (para producción)
   - **DB cluster identifier**: `flask-lambda-db-cluster`
   - **Master username**: `admin` (o tu preferencia)
   - **Master password**: [Genera una contraseña segura]
   - **Instance class**: `db.serverless` (Serverless v2)
   - **VPC**: Selecciona tu VPC o crea una nueva
   - **Public access**: **No** (recomendado para producción)
   - **VPC security group**: Crear nuevo o usar existente
   - **Database name**: `vehicledb`
   - **Enable Enhanced monitoring**: Opcional

5. Click en **Create database**

6. Espera 5-10 minutos hasta que el estado sea **Available**

#### Opción B: Usando AWS CLI

```bash
# Crear subnet group (si no existe)
aws rds create-db-subnet-group \
    --db-subnet-group-name flask-lambda-subnet-group \
    --db-subnet-group-description "Subnet group for Flask Lambda DB" \
    --subnet-ids subnet-xxxxx subnet-yyyyy \
    --region us-east-1

# Crear security group para RDS
aws ec2 create-security-group \
    --group-name rds-aurora-sg \
    --description "Security group for Aurora PostgreSQL" \
    --vpc-id vpc-xxxxx

# Autorizar acceso desde Lambda (más adelante configuramos esto)

# Nota: Para crear el cluster de Aurora, es más fácil usar la consola web
```

### 3.2 Obtener Endpoint de RDS

Una vez creado el cluster:

1. Ve a **RDS** > **Databases** > Selecciona tu cluster
2. En la pestaña **Connectivity & security**, copia el **Endpoint** del Writer
3. Ejemplo: `flask-lambda-db-cluster.cluster-xxxxx.us-east-1.rds.amazonaws.com`

**Importante**: Guarda este endpoint, lo necesitarás para las variables de entorno.

### 3.3 Verificar conectividad

```bash
# Desde tu máquina local (si tienes acceso público temporal)
psql -h flask-lambda-db-cluster.cluster-xxxxx.us-east-1.rds.amazonaws.com \
     -U admin \
     -d vehicledb
```

Si no tienes acceso público, continúa con los siguientes pasos y configuraremos la conectividad a través de Lambda.

---

## Paso 4: Configurar VPC y Security Groups

### 4.1 Identificar tu VPC

```bash
# Listar VPCs
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' --output table
```

Anota el **VPC ID** donde está tu RDS.

### 4.2 Obtener Subnet IDs

```bash
# Listar subnets en tu VPC
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-xxxxx" \
    --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]' --output table
```

**Necesitas al menos 2 subnets** en diferentes zonas de disponibilidad.

Anota los **Subnet IDs**.

### 4.3 Configurar Security Group para Lambda

```bash
# Crear security group para Lambda
aws ec2 create-security-group \
    --group-name lambda-rds-access-sg \
    --description "Security group for Lambda to access RDS" \
    --vpc-id vpc-xxxxx

# Anota el Group ID que se retorna (ej: sg-xxxxx)
```

### 4.4 Configurar Security Group para RDS

1. Ve a **EC2** > **Security Groups**
2. Selecciona el security group de tu RDS (ej: `rds-aurora-sg`)
3. Pestaña **Inbound rules** > **Edit inbound rules**
4. Agregar regla:
   - **Type**: PostgreSQL
   - **Protocol**: TCP
   - **Port**: 5432
   - **Source**: Selecciona el security group de Lambda (`lambda-rds-access-sg`)
   - **Description**: Allow Lambda access

5. Click **Save rules**

**Alternativa usando CLI:**

```bash
# Obtener Security Group ID de Lambda
LAMBDA_SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=lambda-rds-access-sg" \
    --query 'SecurityGroups[0].GroupId' --output text)

# Obtener Security Group ID de RDS
RDS_SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=rds-aurora-sg" \
    --query 'SecurityGroups[0].GroupId' --output text)

# Autorizar acceso desde Lambda a RDS
aws ec2 authorize-security-group-ingress \
    --group-id $RDS_SG_ID \
    --protocol tcp \
    --port 5432 \
    --source-group $LAMBDA_SG_ID
```

---

## Paso 5: Configurar Base de Datos

### 5.1 Instalar psql (cliente PostgreSQL)

```bash
# macOS
brew install postgresql

# Linux (Ubuntu/Debian)
sudo apt-get install postgresql-client

# Verificar
psql --version
```

### 5.2 Crear conexión a través de EC2 Bastion (si RDS no es público)

Si tu RDS no tiene acceso público, necesitas conectarte a través de un bastion o EC2 instance.

**Opción**: Habilitar acceso público temporalmente solo para configuración inicial:

1. Ve a **RDS** > **Databases** > Tu cluster
2. Click en **Modify**
3. **Connectivity** > **Public access**: **Yes**
4. **Save changes**

**⚠️ IMPORTANTE**: Después de configurar, vuelve a deshabilitar el acceso público.

### 5.3 Ejecutar schema.sql

```bash
# Conectarte a la base de datos
psql -h flask-lambda-db-cluster.cluster-xxxxx.us-east-1.rds.amazonaws.com \
     -U admin \
     -d vehicledb \
     -f schema.sql
```

Si te pide contraseña, ingresa la que configuraste al crear el cluster.

### 5.4 Verificar datos insertados

```bash
psql -h flask-lambda-db-cluster.cluster-xxxxx.us-east-1.rds.amazonaws.com \
     -U admin \
     -d vehicledb \
     -c "SELECT COUNT(*) FROM vehicles;"
```

Deberías ver **10** vehículos.

### 5.5 Deshabilitar acceso público (si lo habilitaste temporalmente)

1. Ve a **RDS** > **Databases** > Tu cluster
2. Click en **Modify**
3. **Connectivity** > **Public access**: **No**
4. **Save changes**

---

## Paso 6: Configurar Zappa Settings

### 6.1 Editar zappa_settings.json

Abre `zappa_settings.json` y actualiza con tus valores:

```json
{
    "production": {
        "app_function": "app.app",
        "aws_region": "us-east-1",
        "profile_name": null,
        "project_name": "flask-lambda-app",
        "runtime": "python3.9",
        "s3_bucket": "zappa-deployments-tu-nombre-unico",
        "memory_size": 512,
        "timeout_seconds": 30,
        "api_gateway_stage": "production",
        "manage_roles": true,
        "role_name": "ZappaLambdaExecution",
        "role_arn": null,
        "exclude": [
            "*.pyc",
            "__pycache__",
            "*.sql",
            ".env",
            "venv/",
            ".git/",
            ".zappa/"
        ],
        "events": [],
        "environment_variables": {},
        "keep_warm": false,
        "vpc_config": {
            "SubnetIds": ["subnet-xxxxx", "subnet-yyyyy"],
            "SecurityGroupIds": ["sg-xxxxx"]
        },
        "log_level": "INFO",
        "lambda_description": "Flask Lambda Application - Vehicle Exchange App"
    }
}
```

**Reemplaza**:
- `s3_bucket`: Tu bucket S3 creado en Paso 2
- `SubnetIds`: Los Subnet IDs de Paso 4.2
- `SecurityGroupIds`: El Security Group ID de Lambda de Paso 4.3

**Importante**: `environment_variables` lo dejamos vacío aquí y lo configuramos después en Lambda console.

---

## Paso 7: Configurar Variables de Entorno

### 7.1 Preparar variables

Prepara las siguientes variables:

```bash
API_KEY_EXCHANGE=tu_clave_api_de_exchangerates
DB_HOST=flask-lambda-db-cluster.cluster-xxxxx.us-east-1.rds.amazonaws.com
DB_NAME=vehicledb
DB_USER=admin
DB_PASS=tu_contraseña_de_rds
```

### 7.2 Configurar en Lambda (después del despliegue)

Las configuraremos después del primer despliegue. Por ahora, continuemos.

---

## Paso 8: Desplegar en Lambda

### 8.1 Preparar entorno local

```bash
# Navegar al directorio del proyecto
cd /Users/rodrigovasquezdevelasco/Documents/GitHub/lab-07

# Crear y activar entorno virtual
python3 -m venv venv
source venv/bin/activate  # En Windows: venv\Scripts\activate

# Instalar dependencias
pip install -r requirements.txt

# Verificar Zappa instalado
zappa --version
```

### 8.2 Inicializar Zappa (si es necesario)

```bash
zappa init
```

Si ya tienes `zappa_settings.json`, puedes responder a las preguntas o usar las existentes.

### 8.3 Primer despliegue

```bash
zappa deploy production
```

Este proceso puede tardar varios minutos. Zappa hará lo siguiente:

1. ✅ Crear paquete de la aplicación
2. ✅ Subir a S3
3. ✅ Crear función Lambda
4. ✅ Crear API Gateway
5. ✅ Configurar permisos IAM

**Al finalizar, verás algo como**:

```
Deployment complete! https://xxxxx.execute-api.us-east-1.amazonaws.com/production
```

**Guarda esta URL** - es tu endpoint de la aplicación.

### 8.4 Verificar despliegue

```bash
# Ver estado
zappa status production

# Ver URL de API Gateway
zappa status production | grep "API Gateway URL"
```

---

## Paso 9: Configurar API Gateway y Variables de Entorno

### 9.1 Configurar Variables de Entorno en Lambda

1. Ve a **AWS Console** > **Lambda**
2. Busca y selecciona la función `flask-lambda-app-production`
3. Scroll hacia abajo a **Configuration** > **Environment variables**
4. Click **Edit**
5. Agregar variables:
   - `API_KEY_EXCHANGE`: `tu_clave_api`
   - `DB_HOST`: `flask-lambda-db-cluster.cluster-xxxxx.us-east-1.rds.amazonaws.com`
   - `DB_NAME`: `vehicledb`
   - `DB_USER`: `admin`
   - `DB_PASS`: `tu_contraseña`
6. Click **Save**

**Alternativa usando AWS CLI**:

```bash
aws lambda update-function-configuration \
    --function-name flask-lambda-app-production \
    --environment Variables="{
        API_KEY_EXCHANGE=tu_clave_api,
        DB_HOST=flask-lambda-db-cluster.cluster-xxxxx.us-east-1.rds.amazonaws.com,
        DB_NAME=vehicledb,
        DB_USER=admin,
        DB_PASS=tu_contraseña
    }"
```

### 9.2 Verificar VPC Configuration en Lambda

1. En la función Lambda, ve a **Configuration** > **VPC**
2. Verifica que esté configurado con:
   - **VPC**: Tu VPC
   - **Subnets**: Las subnets que configuraste
   - **Security groups**: El security group de Lambda

Si no está configurado, haz click en **Edit** y configúralo.

### 9.3 Actualizar función Lambda (si hiciste cambios)

```bash
zappa update production
```

Esto aplicará los cambios de código y configuración.

---

## Paso 10: Verificar y Probar

### 10.1 Probar Home Page

```bash
# Obtener URL de API Gateway
ZAPPA_URL=$(zappa status production | grep "API Gateway URL" | awk '{print $4}')

# Probar home
curl $ZAPPA_URL
```

O simplemente abre en tu navegador:
```
https://xxxxx.execute-api.us-east-1.amazonaws.com/production
```

### 10.2 Probar Exchange Rates

```bash
curl $ZAPPA_URL/exchange
```

O en el navegador:
```
https://xxxxx.execute-api.us-east-1.amazonaws.com/production/exchange
```

### 10.3 Probar Vehicle Catalog

```bash
curl $ZAPPA_URL/vehicles
```

O en el navegador:
```
https://xxxxx.execute-api.us-east-1.amazonaws.com/production/vehicles
```

### 10.4 Verificar despliegue

```bash
# Obtener URL de API Gateway
zappa status production | grep "API Gateway URL"

# Probar endpoint
curl $(zappa status production | grep "API Gateway URL" | awk '{print $4}')
```

Verifica que todas las rutas respondan correctamente.

---

## Solución de Problemas

### Problema 1: Timeout al conectar a RDS

**Síntomas**: Error `timeout` o `connection refused` en logs

**Soluciones**:
1. Verifica que Lambda esté en la misma VPC que RDS
2. Verifica Security Groups:
   - Lambda SG debe poder hacer outbound a RDS
   - RDS SG debe permitir inbound desde Lambda SG en puerto 5432
3. Verifica que las subnets tengan route a internet (NAT Gateway) si necesita acceso externo
4. Aumenta timeout en `zappa_settings.json`:
   ```json
   "timeout_seconds": 60
   ```

### Problema 2: Cold Start muy lento

**Síntomas**: Primera request tarda mucho (>5 segundos)

**Soluciones**:
1. Habilita provisioned concurrency:
   ```bash
   aws lambda put-provisioned-concurrency-config \
       --function-name flask-lambda-app-production \
       --qualifier production \
       --provisioned-concurrent-executions 1
   ```
2. Reduce el tamaño del paquete excluyendo archivos innecesarios
3. Optimiza imports en `app.py`

### Problema 3: Error "Module not found"

**Síntomas**: `ModuleNotFoundError` en logs

**Soluciones**:
1. Verifica que todas las dependencias estén en `requirements.txt`
2. Reinstala dependencias y redespliega:
   ```bash
   pip install -r requirements.txt
   zappa update production
   ```
3. Verifica que `exclude` en `zappa_settings.json` no excluya archivos necesarios

### Problema 4: Error de autenticación de ExchangeRates API

**Síntomas**: Error 401 o 403 en `/exchange`

**Soluciones**:
1. Verifica que `API_KEY_EXCHANGE` esté configurada correctamente en Lambda
2. Verifica que la clave API sea válida en apilayer.com
3. Verifica que tengas créditos disponibles en tu cuenta de ExchangeRates

### Problema 5: No se muestran vehículos

**Síntomas**: Página `/vehicles` vacía o error de base de datos

**Soluciones**:
1. Verifica conexión a RDS:
   - Prueba el endpoint `/vehicles` y verifica los mensajes de error en la respuesta
   - Verifica que las variables de entorno estén configuradas correctamente en Lambda
   - Verifica que la función Lambda tenga acceso a la VPC
2. Verifica que la tabla `vehicles` exista:
   ```bash
   psql -h [DB_HOST] -U [DB_USER] -d [DB_NAME] -c "\dt"
   ```
3. Verifica credenciales en variables de entorno de Lambda
4. Verifica que la función Lambda tenga acceso a la VPC

### Problema 6: Error de permisos IAM

**Síntomas**: Error `AccessDenied` o permisos

**Soluciones**:
1. Verifica que el rol de Lambda tenga permisos para:
   - VPC (si está en VPC)
   - Secrets Manager (si usas secrets)
   - S3 (para paquetes de despliegue)
   - API Gateway
2. Agrega políticas necesarias al rol IAM de Lambda

### Problema 7: API Gateway retorna 502 o 500

**Síntomas**: Error 502 Bad Gateway

**Soluciones**:
1. Verifica el estado del despliegue:
   ```bash
   zappa status production
   ```
2. Prueba el endpoint directamente y verifica los mensajes de error en la respuesta
2. Verifica que la función Lambda no esté excediendo timeout
3. Verifica que las rutas estén correctamente configuradas
4. Verifica que los templates HTML existan

---

## Comandos Útiles

### Ver estado del despliegue

```bash
zappa status production
```

### Verificar estado y probar endpoints

```bash
# Ver estado del despliegue
zappa status production

# Obtener URL de API Gateway
zappa status production | grep "API Gateway URL"

# Probar endpoint directamente
curl -X GET "$(zappa status production | grep 'API Gateway URL' | awk '{print $4}')"

# Probar ruta específica
curl -X GET "$(zappa status production | grep 'API Gateway URL' | awk '{print $4}')/vehicles"
```

### Actualizar despliegue

```bash
zappa update production
```

### Deshacer despliegue

```bash
zappa undeploy production
```

### Obtener URL de API Gateway

```bash
zappa status production | grep "API Gateway URL"
```

### Invocar función directamente

```bash
aws lambda invoke \
    --function-name flask-lambda-app-production \
    --payload '{"httpMethod": "GET", "path": "/"}' \
    response.json && cat response.json
```

---

## Checklist Final

Antes de considerar el despliegue completo, verifica:

- [ ] AWS CLI configurado correctamente
- [ ] Bucket S3 creado y configurado en `zappa_settings.json`
- [ ] RDS Aurora PostgreSQL creado y disponible
- [ ] Base de datos creada y `schema.sql` ejecutado
- [ ] VPC y Security Groups configurados correctamente
- [ ] Subnets y Security Groups configurados en `zappa_settings.json`
- [ ] Variables de entorno configuradas en Lambda
- [ ] Función Lambda desplegada exitosamente
- [ ] API Gateway funcionando
- [ ] Home page (`/`) accesible
- [ ] Exchange rates (`/exchange`) funcionando
- [ ] Vehicle catalog (`/vehicles`) funcionando
- [ ] Todas las rutas responden correctamente

---

## Recursos Adicionales

- [Documentación oficial de Zappa](https://github.com/Miserlou/Zappa)
- [Documentación de AWS Lambda](https://docs.aws.amazon.com/lambda/)
- [Documentación de RDS Aurora](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/)
- [Documentación de API Gateway](https://docs.aws.amazon.com/apigateway/)

---

## Soporte

Si encuentras problemas no cubiertos en esta guía:

1. Verifica el estado del despliegue:
   ```bash
   zappa status production
   ```
2. Prueba los endpoints directamente para ver mensajes de error
3. Verifica la configuración en AWS Console (Lambda, API Gateway, RDS)
4. Consulta la documentación oficial de AWS

---

**¡Despliegue completo!** 🚀

Tu aplicación Flask está ahora corriendo en AWS Lambda con conexión a RDS Aurora PostgreSQL.

