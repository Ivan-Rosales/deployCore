#!/bin/bash

# Verificar que se pasaron exactamente 3 argumentos
if [ "$#" -ne 3 ]; then
    echo "Uso: $0 <nombre_sitio> <puerto_externo> <puerto_local>"
    exit 1
fi

# Asignación de variables (sin espacios alrededor del "=")
SITE_NAME="$1"
PORT_NGINX="$2"
PORT_LOCAL="$3"
NGINX_AVAILABLE="/etc/nginx/sites-available/$SITE_NAME"
NGINX_ENABLED="/etc/nginx/sites-enabled/$SITE_NAME"

# Crear archivo de configuración Nginx
sudo tee "$NGINX_AVAILABLE" > /dev/null <<EOF
server {
    listen ${PORT_NGINX};

    location / {
        proxy_pass http://127.0.0.1:${PORT_LOCAL};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Crear enlace simbólico solo si no existe
if [ ! -L "$NGINX_ENABLED" ]; then
    sudo ln -s "$NGINX_AVAILABLE" "$NGINX_ENABLED"
fi

# Verificar configuración de Nginx
if ! sudo nginx -t; then
    echo "❌ Error en la configuración de Nginx. Verifica los archivos."
    exit 1
fi

# Recargar Nginx
sudo systemctl reload nginx

# Confirmación de éxito
echo "✅ El sitio '$SITE_NAME' ha sido habilitado en el puerto externo $PORT_NGINX redirigiendo al puerto local $PORT_LOCAL."
