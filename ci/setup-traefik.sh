#!/bin/bash
############################################################
# Script Name:      setup-traefik.sh
# Author:           Jesús Iván Rosales Martínez (rosmartzivan@gmail.com)
# Created:          2025-07-08
# Last Modified:    2025-07-08
# Description:      Automate Dockerization of Projects for traefik
############################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DEFAULT_NAME="$(basename "$SCRIPT_DIR")"

DOCKERFILE="Dockerfile"
COMPOSEFILE="docker-compose.yml"
DOCKERIGNORE=".dockerignore"

API_PREFIX="$1"
API_NAME="${2:-$API_DEFAULT_NAME}"

if [ -z "$API_PREFIX" ]; then
  echo "❌ Error: Debes proporcionar al menos un parámetro: el API_PREFIX"
  echo "🧾 Uso: $0 <api_prefix> [api_name]"
  exit 1
fi


# Verificación de dependencias
for cmd in ss docker docker-compose curl python3; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ '$cmd' no está instalado. Instálalo antes de continuar."
        exit 1
    fi
done


# Verificación de archivos existentes
for file in "$DOCKERFILE" "$COMPOSEFILE" "$DOCKERIGNORE"; do
    if [ -f "$file" ]; then
        read -p "⚠️  El archivo '$file' ya existe. ¿Deseas sobrescribirlo? [s/N]: " answer
        if [[ ! "$answer" =~ ^[Ss]$ ]]; then
            echo "❌ Cancelado por el usuario."
            exit 1
        fi
    fi
done


# Docker ignore
echo "🛠️ Generando archivo $DOCKERIGNORE..."
cat <<EOF > $DOCKERIGNORE
# Ignorar archivos y directorios innecesarios para Docker
__pycache__/
*.py[cod]
*.pyo
*.pyd
*.log
*.sqlite3
*.db
*.DS_Store
*.egg-info/
*.egg
*.zip
*.tar.gz
*.tar
*.gz
*.tgz
*.whl
*.pyc
*.coverage
*.mypy_cache/
*.pytest_cache/
*.tox/
*.venv/
*.env.local
EOF

echo "✅ .dockerignore generado."


# Generación del Dockerfile
echo "🛠️ Generando archivo $DOCKERFILE..."

REQUIREMENTS=""
[ -f "requirements.txt" ] && REQUIREMENTS+="RUN pip install --no-cache-dir -r requirements.txt"
[ -f "pyproject.toml" ] && REQUIREMENTS+="RUN pip install ."

{
cat <<EOF
# Imagen base
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /code

RUN apt-get update

RUN apt-get install -y \
    curl \
    wget \
    build-essential

RUN curl -sSL -O https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb

RUN apt-get update && ACCEPT_EULA=Y apt-get install -y msodbcsql17

RUN wget https://www.openssl.org/source/openssl-3.0.2.tar.gz
RUN tar -xzvf openssl-3.0.2.tar.gz

WORKDIR /code/openssl-3.0.2
RUN ./config
RUN make -j$(nproc)
RUN make install
WORKDIR /code

COPY . .

RUN sed -i 's|openssl_conf = openssl_init|openssl_conf = default_conf|' /etc/ssl/openssl.cnf
RUN sed -i 's|# \[openssl_init\]|[openssl_init]|' /etc/ssl/openssl.cnf
RUN sed -i 's|providers = provider_sect|providers = provider_sect\nssl_conf = ssl_sect|' /etc/ssl/openssl.cnf

RUN sed -i 's|# \[provider_sect\]|[provider_sect]|' /etc/ssl/openssl.cnf
RUN sed -i 's|default = default_sect|default = default_sect\nlegacy = legacy_sect|' /etc/ssl/openssl.cnf

RUN sed -i 's|# \[default_sect\]|[default_sect]|' /etc/ssl/openssl.cnf
RUN sed -i 's|# activate = 1|activate = 1|' /etc/ssl/openssl.cnf

RUN sed -i 's|# out_trusted = apps/insta.ca.crt|out_trusted = insta.ca.crt|' /etc/ssl/openssl.cnf
RUN sed -i 's|# trusted = \$insta::out_trusted|trusted = insta.ca.crt|' /etc/ssl/openssl.cnf

# Añadir las secciones [ssl_sect], [system_default_sect], [default_conf] y [system_default_sect] al final
RUN echo "[ssl_sect]" >> /etc/ssl/openssl.cnf
RUN echo "system_default = system_default_sect" >> /etc/ssl/openssl.cnf
RUN echo "[system_default_sect]" >> /etc/ssl/openssl.cnf
RUN echo "CipherString = DEFAULT:@SECLEVEL=0" >> /etc/ssl/openssl.cnf
RUN echo "[default_conf]" >> /etc/ssl/openssl.cnf
RUN echo "ssl_conf = ssl_sect" >> /etc/ssl/openssl.cnf
RUN echo "[ssl_sect]" >> /etc/ssl/openssl.cnf
RUN echo "system_default = system_default_sect" >> /etc/ssl/openssl.cnf
RUN echo "[system_default_sect]" >> /etc/ssl/openssl.cnf
RUN echo "MinProtocol = TLSv1.0" >> /etc/ssl/openssl.cnf
RUN echo "CipherString = DEFAULT:@SECLEVEL=0" >> /etc/ssl/openssl.cnf

# Limpieza
RUN rm -rf /code/openssl-3.0.2/
RUN rm /code/openssl-3.0.2.tar.gz

RUN pip install gunicorn
RUN pip install --upgrade pip


EOF

# Insertar el bloque COPY con saltos reales
echo -e "$REQUIREMENTS"

cat <<EOF

EXPOSE 8000

CMD ["gunicorn", "$API_NAME.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]

EOF
} > "$DOCKERFILE"

echo "✅ Dockerfile generado."


# Docker Compose
echo "🛠️ Generando archivo $COMPOSEFILE..."

cat <<EOF > $COMPOSEFILE
services:
  api:
    container_name: "$API_NAME"
    build: .
    env_file:
      - ../.env
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.$API_NAME.rule=PathPrefix(\`/$API_PREFIX\`)"
      - "traefik.http.services.$API_NAME.loadbalancer.server.port=8000"
      - "traefik.http.middlewares.$API_NAME-strip.stripprefix.prefixes=/$API_PREFIX"
      - "traefik.http.routers.$API_NAME.middlewares=$API_NAME-strip"
    networks:
      - traefik-net
    extra_hosts:
      - "host.docker.internal:host-gateway"

networks:
  traefik-net:
    external: true
EOF

echo "✅ docker-compose.yml"


echo "🚀 Ejecuta desde el directorio donde está este script:"
echo "   make up"
echo "   o"
echo "   docker-compose up -d --build"
