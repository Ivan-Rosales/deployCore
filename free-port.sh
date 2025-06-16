#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FOLDER_NAME="$(basename "$SCRIPT_DIR")"
API_ID="django$FOLDER_NAME.service"
PORT_START=8000
PORT_END=8999
SERVICE_FILE="/etc/systemd/system/$API_ID"

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
