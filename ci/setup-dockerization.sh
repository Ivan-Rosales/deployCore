#!/bin/bash
############################################################
# Script Name:      setup-dockerization.sh
# Author:           Giovanni Trujillo Silvas (gtrujill0@outlook.com)
# Created:          2025-05-24
# Last Modified:    2025-05-26
# Description:      Automate Dockerization of Projects
############################################################

DOCKERFILE="Dockerfile"
COMPOSEFILE="docker-compose.yml"
DOCKERIGNORE=".dockerignore"
# Obtener nombre de la app basado en la carpeta
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# BASE_DIR es una carpeta atrás de donde está el script (la raíz del proyecto)
BASE_DIR="$(dirname "$SCRIPT_DIR")"
API_ID="$(basename "$BASE_DIR" | sed 's/[^a-zA-Z0-9_]/_/g')"
PORT_START=8000
PORT_END=8999

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

# Buscar un puerto libre
find_free_port() {
    local start=$1
    local end=$2
    for ((port=start; port<=end; port++)); do
        if ! ss -tuln | grep -q ":$port\b"; then
            echo "$port"
            return
        fi
    done
    echo "❌ No se encontró puerto libre entre $start y $end" >&2
    exit 1
}

PORT_LOCAL=$(find_free_port $PORT_START $PORT_END)
echo "📡 Puerto local disponible encontrado: $PORT_LOCAL"

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

WORKDIR /$API_ID

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

WORKDIR /$API_ID/openssl-3.0.2
RUN ./config
RUN make -j$(nproc)
RUN make install
WORKDIR /$API_ID

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
RUN rm -rf /$API_ID/openssl-3.0.2/
RUN rm /$API_ID/openssl-3.0.2.tar.gz

RUN pip install gunicorn
RUN pip install --upgrade pip


EOF

# Insertar el bloque COPY con saltos reales
echo -e "$REQUIREMENTS"

cat <<EOF

EXPOSE $PORT_LOCAL

CMD ["gunicorn", "$API_ID.wsgi:application", "--bind", "0.0.0.0:$PORT_LOCAL", "--workers", "3"]

EOF
} > "$DOCKERFILE"

echo "✅ Dockerfile generado."

# Docker Compose
echo "🛠️ Generando archivo $COMPOSEFILE..."

cat <<EOF > $COMPOSEFILE
services:
  api:
    container_name: "$API_ID"
    network_mode: host
    build: .
    command: gunicorn $API_ID.wsgi:application --bind 0.0.0.0:$PORT_LOCAL
    volumes:
      - .:/$API_ID
    env_file:
      - ../.env
EOF

echo "✅ docker-compose.yml generado con puerto: $PORT_LOCAL"
echo "🚀 Ejecuta desde el directorio donde está este script:"
echo "   make up"
echo "   o"
echo "   docker-compose up -d --build"
