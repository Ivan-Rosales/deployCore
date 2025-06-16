#!/bin/bash

# Verificar que se pasó un argumento
if [ "$#" -ne 1 ]; then
    echo "Uso: $0 <nombre_sitio>"
    exit 1
fi

# Nombre del sitio pasado como argumento
SITE_NAME=$1

# Crear enlace simbólico
sudo ln -s /etc/nginx/sites-available/$SITE_NAME /etc/nginx/sites-enabled/

# Verificar configuración de Nginx
sudo nginx -t
if [ $? -ne 0 ]; then
    echo "Error en la configuración de Nginx. Verifica los archivos de configuración."
    exit 1
fi

# Recargar Nginx
sudo systemctl reload nginx

# Confirmación de éxito
echo "El sitio $SITE_NAME se ha habilitado y Nginx se ha recargado correctamente."