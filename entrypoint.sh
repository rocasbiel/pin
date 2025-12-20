#!/bin/sh
set -e

# Validar variable requerida
if [ -z "$LARAVEL_APP_URL" ]; then
    echo "ERROR: La variable LARAVEL_APP_URL es requerida."
    echo "Configúrala en las variables de entorno de Render."
    echo "Ejemplo: LARAVEL_APP_URL=https://mi-app.com"
    exit 1
fi

# Valores por defecto
PORT=${PORT:-8080}
MAX_UPLOAD_SIZE=${MAX_UPLOAD_SIZE:-100}
PROXY_TIMEOUT=${PROXY_TIMEOUT:-60}
BLOCKED_PATHS=${BLOCKED_PATHS:-.env,.git,artisan,vendor,sender}

# Generar líneas del map para rutas bloqueadas
BLOCKED_PATHS_MAP=""
IFS=','
for path in $BLOCKED_PATHS; do
    path=$(echo "$path" | xargs)  # trim spaces
    if [ -n "$path" ]; then
        BLOCKED_PATHS_MAP="${BLOCKED_PATHS_MAP}        ~*${path} 1;\n"
    fi
done
unset IFS

# Extraer el backend de LARAVEL_APP_URL
# Ejemplo: http://servidor.com:8000 -> servidor.com:8000
LARAVEL_BACKEND=$(echo $LARAVEL_APP_URL | sed -e 's|^[^/]*//||' -e 's|/$||')

# Extraer solo el hostname (sin puerto) para el header Host
# Ejemplo: https://servidor.com:443 -> servidor.com
LARAVEL_HOST=$(echo $LARAVEL_BACKEND | sed -e 's|:.*||')

# Si ALLOWED_PATHS está vacío, permitir todas las rutas
# ALLOWED_PATHS debe ser una lista separada por comas: pin,colpatria,bogota,api/telegram
if [ -z "$ALLOWED_PATHS" ]; then
    ALLOWED_PATHS_MAP="        ~* .* 1;"
    ALLOWED_DEFAULT="1"
else
    ALLOWED_DEFAULT="0"
    # Generar líneas del map para cada ruta permitida
    ALLOWED_PATHS_MAP=""
    IFS=','
    for path in $ALLOWED_PATHS; do
        path=$(echo "$path" | xargs)  # trim spaces
        if [ -n "$path" ]; then
            ALLOWED_PATHS_MAP="${ALLOWED_PATHS_MAP}        ~*^/${path}(/.*)?$ 1;\n"
        fi
    done
    unset IFS
fi

# Imprimir configuración para debugging
echo "========================================="
echo "Configuración del Proxy Reverso"
echo "========================================="
echo "Puerto: $PORT"
echo "Aplicación Laravel: $LARAVEL_APP_URL"
echo "Backend: $LARAVEL_BACKEND"
echo "Host: $LARAVEL_HOST"
echo "Rutas permitidas: $ALLOWED_PATHS"
echo "Rutas bloqueadas: $BLOCKED_PATHS"
echo "Tamaño máx. upload: ${MAX_UPLOAD_SIZE}M"
echo "Timeout: ${PROXY_TIMEOUT}s"
echo "Redirección raíz: ${ROOT_REDIRECT:-ninguna}"
echo "========================================="

# Reemplazar variables en la plantilla
export PORT
export MAX_UPLOAD_SIZE
export PROXY_TIMEOUT
export ALLOWED_DEFAULT
export LARAVEL_BACKEND
export LARAVEL_HOST
export LARAVEL_APP_URL
export ROOT_REDIRECT

# Interpretar \n en las variables de map
ALLOWED_PATHS_MAP=$(printf '%b' "$ALLOWED_PATHS_MAP")
BLOCKED_PATHS_MAP=$(printf '%b' "$BLOCKED_PATHS_MAP")
export ALLOWED_PATHS_MAP
export BLOCKED_PATHS_MAP

envsubst '${PORT} ${MAX_UPLOAD_SIZE} ${PROXY_TIMEOUT} ${BLOCKED_PATHS_MAP} ${ALLOWED_PATHS_MAP} ${ALLOWED_DEFAULT} ${LARAVEL_BACKEND} ${LARAVEL_HOST} ${LARAVEL_APP_URL} ${ROOT_REDIRECT}' \
    < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# Verificar configuración de Nginx
echo "Verificando configuración de Nginx..."
nginx -t

# Iniciar Nginx
echo "Iniciando Nginx..."
exec nginx -g "daemon off;"
