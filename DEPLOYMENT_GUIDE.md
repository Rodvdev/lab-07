# Guía de Despliegue en Lambda con RDS

Esta guía te ayudará a desplegar tu aplicación en Lambda y conectarla a RDS.

## 📋 Información que Necesitas

Antes de comenzar, asegúrate de tener esta información:

### 1. Bucket S3
- **Nombre del bucket S3** para Zappa (debe ser único globalmente)
- Si no tienes uno, créalo en AWS Console > S3 > Create bucket
- Región: `us-east-1`

### 2. Información de RDS Aurora
- **DB Cluster Identifier** (nombre del cluster, ej: `flask-lambda-db-cluster`)
- **DB Endpoint** (ej: `cluster-xxxxx.us-east-1.rds.amazonaws.com`)
  - Lo encuentras en: RDS Console > Databases > Tu cluster > Connectivity & security > Endpoint
- **Database Name** (ej: `vehicledb`)
- **DB Username** (ej: `admin`)
- **DB Password** (la que configuraste al crear el cluster)

### 3. Información de VPC
- **VPC ID** donde está tu RDS (ej: `vpc-xxxxx`)
  - Lo encuentras en: RDS Console > Databases > Tu cluster > Connectivity & security > VPC
- **Subnet IDs** (necesitas al menos 2 en diferentes zonas)
  - Lo encuentras en: EC2 Console > Subnets (filtra por tu VPC)
  - Ejemplo: `subnet-xxxxx`, `subnet-yyyyy`
- **Security Group ID para Lambda** (ej: `sg-xxxxx`)
  - Si no tienes uno, créalo en: EC2 Console > Security Groups > Create security group
  - Debe estar en la misma VPC que RDS

### 4. API Key
- **API Key de ExchangeRates** (de apilayer.com)

## 🚀 Pasos para Desplegar

### Paso 1: Configurar Información

Ejecuta el script interactivo:

```bash
./scripts/configure_deployment.sh
```

Este script te pedirá toda la información anterior y actualizará `zappa_settings.json` automáticamente.

**Alternativa Manual**: Si prefieres configurar manualmente, edita `zappa_settings.json`:

```json
{
    "production": {
        "s3_bucket": "tu-bucket-s3-unico",
        "vpc_config": {
            "SubnetIds": ["subnet-xxxxx", "subnet-yyyyy"],
            "SecurityGroupIds": ["sg-xxxxx"]
        }
    }
}
```

### Paso 2: Configurar Security Groups

**IMPORTANTE**: El Security Group de RDS debe permitir tráfico desde el Security Group de Lambda.

1. Ve a **EC2 Console** > **Security Groups**
2. Selecciona el Security Group de tu RDS
3. Pestaña **Inbound rules** > **Edit inbound rules**
4. Agregar regla:
   - **Type**: PostgreSQL
   - **Protocol**: TCP
   - **Port**: 5432
   - **Source**: Selecciona el Security Group de Lambda (el que configuraste en `zappa_settings.json`)
   - **Description**: Allow Lambda access
5. Click **Save rules**

### Paso 3: Verificar Base de Datos

Asegúrate de que tu base de datos tenga el schema ejecutado:

```bash
# Si RDS tiene acceso público temporal
psql -h [DB_ENDPOINT] -U [DB_USER] -d [DB_NAME] -f schema.sql
```

Si no tienes acceso público, puedes:
- Habilitar acceso público temporalmente solo para configurar
- O usar un bastion host / EC2 instance

### Paso 4: Desplegar en Lambda

```bash
./scripts/deploy.sh
```

Este script:
- Verifica prerrequisitos
- Activa el entorno virtual
- Instala dependencias
- Despliega en Lambda usando Zappa

**Nota**: Si es la primera vez, esto creará la función Lambda. Si ya existe, la actualizará.

### Paso 5: Configurar Variables de Entorno en Lambda

Después del despliegue, configura las variables de entorno:

**Opción A: Usando el script** (si tienes permisos):

```bash
./scripts/set_lambda_env_vars.sh
```

**Opción B: Manualmente en AWS Console**:

1. Ve a **AWS Console** > **Lambda**
2. Busca y selecciona la función `flask-lambda-app-production`
3. Scroll hacia abajo a **Configuration** > **Environment variables**
4. Click **Edit**
5. Agrega las siguientes variables:
   - `DB_HOST`: [Tu RDS endpoint]
   - `DB_NAME`: [Nombre de tu base de datos]
   - `DB_USER`: [Usuario de RDS]
   - `DB_PASS`: [Contraseña de RDS]
   - `API_KEY_EXCHANGE`: [Tu API key de ExchangeRates]
6. Click **Save**

**Nota**: Los valores están guardados en `.env.deployment` si usaste el script de configuración.

### Paso 6: Verificar Despliegue

```bash
# Ver estado
zappa status production

# Obtener URL
zappa status production | grep "API Gateway URL"

# Probar endpoints
curl $(zappa status production | grep "API Gateway URL" | awk '{print $4}')
curl $(zappa status production | grep "API Gateway URL" | awk '{print $4}')/vehicles
```

## 🔍 Verificar Conexión a RDS

Para verificar que Lambda se conecta correctamente a RDS:

1. Ve a **Lambda Console** > Tu función > **Monitor** > **Logs**
2. Busca errores de conexión
3. Prueba el endpoint `/vehicles` - debería mostrar los vehículos de la base de datos

## ❗ Problemas Comunes

### Error: Timeout al conectar a RDS

**Causa**: Lambda no puede alcanzar RDS

**Soluciones**:
1. Verifica que Lambda esté en la misma VPC que RDS
2. Verifica Security Groups (RDS debe permitir tráfico desde Lambda SG en puerto 5432)
3. Verifica que las subnets tengan route a internet (si Lambda necesita acceso externo)
4. Aumenta timeout en `zappa_settings.json`: `"timeout_seconds": 60`

### Error: No se muestran vehículos

**Causa**: Problema de conexión o datos

**Soluciones**:
1. Verifica variables de entorno en Lambda
2. Verifica que el schema.sql se haya ejecutado en RDS
3. Verifica logs de Lambda para ver errores específicos
4. Verifica que la tabla `vehicles` exista y tenga datos

### Error: Module not found

**Causa**: Dependencias faltantes

**Soluciones**:
1. Verifica que `requirements.txt` tenga todas las dependencias
2. Reinstala y redespliega:
   ```bash
   pip install -r requirements.txt
   zappa update production
   ```

## 📝 Checklist Final

- [ ] Bucket S3 creado y configurado en `zappa_settings.json`
- [ ] RDS Aurora PostgreSQL creado y disponible
- [ ] Base de datos configurada (schema.sql ejecutado)
- [ ] VPC y Security Groups configurados correctamente
- [ ] Subnets y Security Groups configurados en `zappa_settings.json`
- [ ] Función Lambda desplegada exitosamente
- [ ] Variables de entorno configuradas en Lambda
- [ ] Security Group de RDS permite tráfico desde Lambda SG
- [ ] Endpoint `/vehicles` muestra datos de la base de datos

## 🎉 ¡Listo!

Tu aplicación debería estar funcionando en Lambda con conexión a RDS. Si encuentras problemas, revisa los logs de Lambda y verifica la configuración de VPC y Security Groups.

