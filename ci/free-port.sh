#!/bin/bash
read -p "¿Qué ambiente deseas usar? (qa/prod): " ambiente

ambiente=$(echo "$ambiente" | tr '[:upper:]' '[:lower:]')

if [[ "$ambiente" == "qa" ]]; then
    PORT_LOCAL_START=8001
    PORT_LOCAL_END=8999
    PORT_EXTERNAL_START=60100
    PORT_EXTERNAL_END=60199
elif [[ "$ambiente" == "prod" ]]; then
    PORT_LOCAL_START=9000
    PORT_LOCAL_END=9999
    PORT_EXTERNAL_START=60200
    PORT_EXTERNAL_END=60299
else
    echo "❌ Ambiente no válido. Usa 'qa' o 'prod'."
    exit 1
fi

# Buscar un puerto libre
find_free_port_in_range() {
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

# Obtener puerto local y externo
PORT_LOCAL=$(find_free_port_in_range $PORT_LOCAL_START $PORT_LOCAL_END)
PORT_EXTERNAL=$(find_free_port_in_range $PORT_EXTERNAL_START $PORT_EXTERNAL_END)

echo "📡 Puerto local disponible encontrado: $PORT_LOCAL"
echo "🌐 Puerto externo disponible encontrado: $PORT_EXTERNAL"