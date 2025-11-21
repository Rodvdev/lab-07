# Guía Rápida: Configurar Base de Datos en Lambda

Esta guía te ayudará a configurar las variables de entorno de la base de datos en tu función Lambda.

## Opción 1: Script Automatizado (Recomendado)

### Paso 1: Ejecutar el script

```bash
./scripts/setup_db_lambda.sh
```

Este script:
- ✅ Busca automáticamente tus clusters RDS
- ✅ Obtiene el endpoint de RDS automáticamente
- ✅ Configura las variables de entorno en Lambda
- ✅ Verifica la configuración

### Paso 2: Seguir las instrucciones

El script te pedirá:
1. **DB Cluster Identifier**: Selecciona de la lista o ingresa manualmente
2. **Database Name**: Nombre de tu base de datos (ej: `vehicledb`)
3. **DB Username**: Usuario de RDS (ej: `admin`)
4. **DB Password**: Contraseña de RDS
5. **API Key Exchange**: Clave API de ExchangeRates (opcional)

## Opción 2: Usando archivo .env.deployment

Si ya ejecutaste `configure_deployment.sh` y tienes un archivo `.env.deployment`:

```bash
./scripts/set_lambda_env_vars.sh
```

Este script leerá las variables desde `.env.deployment` y las configurará en Lambda.

## Opción 3: Modo Interactivo Avanzado

Para más control, usa el modo interactivo:

```bash
./scripts/set_lambda_env_vars.sh --interactive
```

## Opción 4: Configuración Manual en AWS Console

Si prefieres configurar manualmente:

1. Ve a **AWS Console** > **Lambda**
2. Selecciona la función `flask-lambda-app-production`
3. Ve a **Configuration** > **Environment variables**
4. Click en **Edit**
5. Agrega las siguientes variables:

   ```
   DB_HOST = [tu-rds-endpoint].cluster-xxxxx.us-east-1.rds.amazonaws.com
   DB_NAME = vehicledb
   DB_USER = admin
   DB_PASS = [tu-contraseña]
   API_KEY_EXCHANGE = [tu-api-key]
   ```

6. Click en **Save**

## Verificar Configuración

Después de configurar, verifica que todo esté correcto:

```bash
# Ver estado de Lambda
zappa status production

# Ver variables de entorno configuradas
aws lambda get-function-configuration \
    --function-name flask-lambda-app-production \
    --query 'Environment.Variables' \
    --output table
```

## Verificar Conectividad

Asegúrate de que:

1. ✅ **Security Group de RDS** permita tráfico desde el **Security Group de Lambda** en puerto **5432**
2. ✅ **Lambda esté en la misma VPC** que RDS (verificado en `zappa_settings.json`)
3. ✅ **Las subnets** en `zappa_settings.json` sean correctas

## Probar Conexión

Prueba tu aplicación después de configurar:

```bash
# Obtener URL de API Gateway
ZAPPA_URL=$(zappa status production | grep "API Gateway URL" | awk '{print $4}')

# Probar endpoint de vehículos
curl $ZAPPA_URL/vehicles
```

## Solución de Problemas

### Error: "Function not found"
- Asegúrate de haber desplegado primero: `./scripts/deploy.sh`

### Error: "Access Denied"
- Verifica tus credenciales de AWS: `aws sts get-caller-identity`
- Verifica que tengas permisos para actualizar funciones Lambda

### Error: "Timeout connecting to database"
- Verifica que el Security Group de RDS permita tráfico desde Lambda
- Verifica que Lambda esté en la misma VPC que RDS
- Verifica que las variables de entorno estén correctamente configuradas

### No se muestran vehículos
- Verifica que las tablas existan en la base de datos
- Ejecuta: `./scripts/create_tables.py` para crear las tablas
- Verifica los logs de CloudWatch para ver errores específicos

## Comandos Útiles

```bash
# Ver logs de Lambda
zappa tail production

# Ver configuración actual
aws lambda get-function-configuration \
    --function-name flask-lambda-app-production \
    --query 'Environment.Variables' \
    --output json

# Actualizar despliegue después de cambios
zappa update production
```

## Próximos Pasos

Después de configurar la base de datos:

1. ✅ Verifica que las tablas existan: `./scripts/create_tables.py`
2. ✅ Prueba los endpoints de tu aplicación
3. ✅ Verifica los logs en CloudWatch si hay problemas
4. ✅ Asegúrate de que el Security Group esté correctamente configurado

---

**¿Necesitas ayuda?** Revisa la guía completa en `GUIA_DESPLIEGUE_AWS.md`

