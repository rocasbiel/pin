FROM nginx:alpine

# Instalar gettext para envsubst
RUN apk add --no-cache gettext

# Copiar plantilla de configuración de nginx
COPY nginx.conf.template /etc/nginx/nginx.conf.template

# Copiar script de inicio
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Crear directorios para logs y cache
RUN mkdir -p /var/log/nginx /var/cache/nginx

# Exponer el puerto (Render usa la variable de entorno PORT)
EXPOSE 8080

CMD ["/entrypoint.sh"]
