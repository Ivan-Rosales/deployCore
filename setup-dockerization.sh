#!/bin/bash
############################################################
# Script Name:      setup-dockerization.sh
# Author:           Giovanni Trujillo Silvas (gtrujill0@outlook.com)
# Created:          2025-05-24
# Last Modified:    2025-05-24
# Description:      Automate Dockerization of Projects
############################################################

DOCKERFILE="Dockerfile"
COMPOSEFILE="docker-compose.yml"
DOCKERIGNORE=".dockerignore"
DEPS="install-deps.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_ID="$(basename "$SCRIPT_DIR" | sed 's/[^a-zA-Z0-9_]/_/g')"
INTERNAL_PORT=8000
PORT_START=8001
PORT_END=8999

# Verificación de dependencias
for cmd in ss docker docker-compose curl python3; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ '$cmd' no está instalado. Instálalo antes de continuar."
        exit 1
    fi
done


# Verificación de archivos existentes
for file in "$DEPS" "$DOCKERFILE" "$COMPOSEFILE" "$DOCKERIGNORE"; do
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

# Generación del script de instalación de dependencias
echo "🛠️ Generando archivo $DEPS..."

cat <<EOF > $DEPS
#!/bin/bash
set -e

if [ -f "pyproject.toml" ] && [ -f "poetry.lock" ]; then
    echo "📦 Instalando dependencias con Poetry..."
    curl -sSL https://install.python-poetry.org | python3 -
    ln -s /root/.local/bin/poetry /usr/local/bin/poetry
    poetry config virtualenvs.create false
    poetry install --no-interaction --no-ansi
elif [ -f "requirements.txt" ]; then
    echo "📦 Instalando dependencias con pip (requirements.txt)..."
    pip install --no-cache-dir -r requirements.txt
else
    echo "❌ No se encontraron ni pyproject.toml/poetry.lock ni requirements.txt"
    exit 1
fi
EOF

chmod +x install-deps.sh
echo "✅ $DEPS generado."

# Generación del Dockerfile
echo "🛠️ Generando archivo $DOCKERFILE..."

COPY_LINE=""
[ -f "requirements.txt" ] && COPY_LINE+="COPY requirements.txt ./\n"
[ -f "pyproject.toml" ] && COPY_LINE+="COPY pyproject.toml ./\n"
[ -f "poetry.lock" ] && COPY_LINE+="COPY poetry.lock ./\n"
COPY_LINE+="COPY install-deps.sh ./\n"

{
cat <<EOF
# Imagen base
FROM python:3.12-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /$API_ID

RUN apt-get update && apt-get install -y \\
    build-essential \\
    libpq-dev \\
    curl \\
    && rm -rf /var/lib/apt/lists/*

EOF

# Insertar el bloque COPY con saltos reales
echo -e "$COPY_LINE"

cat <<EOF
COPY README.md ./
RUN chmod +x install-deps.sh && ./install-deps.sh

COPY . .

EXPOSE $INTERNAL_PORT

CMD ["gunicorn", "$API_ID.wsgi:application", "--bind", "0.0.0.0:8000"]

EOF
} > "$DOCKERFILE"

echo "✅ Dockerfile generado."

# Docker Compose
echo "🛠️ Generando archivo $COMPOSEFILE..."

cat <<EOF > $COMPOSEFILE
version: '3.9'

services:
  api:
    container_name: "$API_ID"
    network_mode: "host"
    build: .
    command: gunicorn $API_ID.wsgi:application --bind 0.0.0.0:$INTERNAL_PORT
    volumes:
      - .:/$API_ID
    ports:
      - "$PORT_LOCAL:$INTERNAL_PORT"
    env_file:
      - ../.env
EOF

echo "✅ docker-compose.yml generado con puerto: $PORT_LOCAL"
echo "🚀 Ejecuta desde el directorio donde está este script:"
echo "   make up"
echo "   o"
echo "   docker-compose up --build"
