#!/bin/bash
############################################################
# Script Name:      setup-webhook.sh
# Author:           Giovanni Trujillo Silvas (gtrujill0@outlook.com)
# Created:          2025-05-21
# Last Modified:    2025-05-23
# Description:      Automatiza la configuración de webhooks
# License:          MIT
############################################################

set -euo pipefail

# Obtener nombre de la app basado en la carpeta
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ID="webhook-$(basename "$SCRIPT_DIR" | sed 's/[^a-zA-Z0-9_]/_/g')"

# Rutas principales
HOOKS_DIR="/opt/hooks"
HOOKS_FILE="$HOOKS_DIR/hooks.json"
DEPLOY_SCRIPT="$HOOKS_DIR/${APP_ID}.sh"
ENV_FILE="$HOOKS_DIR/.env"
SERVICE_FILE="/etc/systemd/system/webhook.service"
LOG_FILE="$HOOKS_DIR/logs/${APP_ID}.log"

# Validar herramientas necesarias
for cmd in git docker docker-compose jq openssl; do
  if ! command -v $cmd &> /dev/null; then
    echo "❌ '$cmd' no está instalado. Instalalo antes de continuar."
    exit 1
  fi
done

# Crear directorios necesarios
sudo mkdir -p "$HOOKS_DIR/logs"
sudo chown root:root "$HOOKS_DIR/logs"
sudo chmod 755 "$HOOKSa_DIR/logs"

# Evitar sobreescribir hook ya existente
if [[ -e "$DEPLOY_SCRIPT" ]]; then
  echo "❌ El webhook ${APP_ID} ya existe."
  exit 1
fi

# Crear script de redeploy para esta app
cat > "$DEPLOY_SCRIPT" <<EOF
#!/bin/bash
set -euo pipefail

LOGFILE="${LOG_FILE}"
MAX_SIZE=10000
PROJECT_DIR="${SCRIPT_DIR}"

mkdir -p "\$(dirname "\$LOGFILE")"
touch "\$LOGFILE"
chmod 644 "\$LOGFILE"

# Rotar log si supera tamaño
if [ -f "\$LOGFILE" ] && [ "\$(stat -c%s "\$LOGFILE")" -ge "\$MAX_SIZE" ]; then
  mv "\$LOGFILE" "\${LOGFILE}.\$(date +%Y%m%d%H%M%S).old"
  touch "\$LOGFILE"
  chmod 644 "\$LOGFILE"
fi

# Registrar inicio del redeploy
{
  echo ""
  echo "------------------------------------------------------------------------------------------------------"
  echo "📅 \$(date '+%Y-%m-%d %H:%M:%S') - Iniciando redeploy"
  echo "------------------------------------------------------------------------------------------------------"
} >> "\$LOGFILE"

cd "\$PROJECT_DIR" || {
  echo "❌ \$(date '+%Y-%m-%d %H:%M:%S') - No se pudo cambiar al directorio \$PROJECT_DIR" >> "\$LOGFILE"
  exit 1
}

{
  echo "➡️  Haciendo pull de cambios desde Git..."
  if ! git pull origin main >> "\$LOGFILE" 2>&1; then
    echo "❌ Error en git pull" >> "\$LOGFILE"
    exit 1
  fi

  echo "➡️  Apagando contenedores Docker..."
  if ! docker compose down >> "\$LOGFILE" 2>&1; then
    echo "❌ Error al bajar contenedores Docker" >> "\$LOGFILE"
    exit 1
  fi

  echo "➡️  Reconstruyendo y levantando contenedores Docker..."
  if ! docker compose up -d --build >> "\$LOGFILE" 2>&1; then
    echo "❌ Error al levantar contenedores Docker" >> "\$LOGFILE"
    exit 1
  fi

  echo "✅ Despliegue completado correctamente."
  echo "------------------------------------------------------------------------------------------------------"
  echo ""
} >> "\$LOGFILE"

exit 0
EOF

chmod +x "$DEPLOY_SCRIPT"
sudo chmod +x "$DEPLOY_SCRIPT"
sudo chown root:root "$DEPLOY_SCRIPT"

# Crear o reutilizar token en .env
if [ ! -f "$ENV_FILE" ]; then
    echo "🔐 Generando token secreto..."
    SECRET_TOKEN=$(openssl rand -hex 32)
    echo "SECRET_TOKEN=$SECRET_TOKEN" | sudo tee "$ENV_FILE" > /dev/null
else
    SECRET_TOKEN=$(grep SECRET_TOKEN "$ENV_FILE" | cut -d '=' -f2)
    echo "🔐 Usando token existente."
fi

# Crear hook JSON para esta app
NEW_HOOK=$(jq -n \
  --arg id "$APP_ID" \
  --arg cmd "$DEPLOY_SCRIPT" \
  --arg dir "$HOOKS_DIR" \
  --arg token "$SECRET_TOKEN" \
  '{
    id: $id,
    "execute-command": $cmd,
    "command-working-directory": $dir,
    "response-message": "Deploy ejecutado"
  }')

# Actualizar hooks.json (crear o actualizar hook)
if [ -f "$HOOKS_FILE" ]; then
  if sudo jq -e --arg id "$APP_ID" '.[] | select(.id == $id)' "$HOOKS_FILE" > /dev/null; then
    echo "🔄 Actualizando hook existente..."
    TEMP_HOOKS=$(mktemp)
    sudo jq --argjson hook "$NEW_HOOK" --arg id "$APP_ID" \
      'map(if .id == $id then $hook else . end)' "$HOOKS_FILE" > "$TEMP_HOOKS" && sudo mv "$TEMP_HOOKS" "$HOOKS_FILE"
  else
    echo "➕ Agregando nuevo hook..."
    TEMP_HOOKS=$(mktemp)
    sudo jq ". += [$NEW_HOOK]" "$HOOKS_FILE" > "$TEMP_HOOKS" && sudo mv "$TEMP_HOOKS" "$HOOKS_FILE"
  fi
else
  echo "📄 Creando hooks.json..."
  echo "[$NEW_HOOK]" | sudo tee "$HOOKS_FILE" > /dev/null
fi

# Instalar webhook si no está instalado
if ! command -v webhook &> /dev/null; then
    echo "📦 Instalando webhook..."
    sudo apt install webhook -y
fi

# Crear servicio systemd global si no existe
if [ ! -f "$SERVICE_FILE" ]; then
  echo "🛠️ Creando servicio systemd global webhook..."
  sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Webhook listener global para Git auto-deploy
After=network.target
Requires=network.target

[Service]
EnvironmentFile=${ENV_FILE}
ExecStart=/usr/bin/webhook -hooks ${HOOKS_FILE} -port 60001
WorkingDirectory=${HOOKS_DIR}
Restart=always
RestartSec=3
User=sistemasweb
KillMode=process
ExecReload=/bin/kill -HUP \$MAINPID
StandardOutput=journal
StandardError=journal
SyslogIdentifier=webhook

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable webhook.service
fi

# Se añade directorio como un "safe directory" para Git, ejecutado como root
sudo -u root git config --global --add safe.directory "$SCRIPT_DIR"
sudo -u sistemasweb git config --global --add safe.directory "$SCRIPT_DIR"
sudo chown sistemasweb:sistemasweb $HOOKS_DIR
# Reiniciar servicio para cargar nuevo hook
echo "🔄 Reiniciando servicio webhook para aplicar cambios..."
sudo systemctl restart webhook.service

# Mensajes finales
echo ""
echo "✅ Webhook $APP_ID configurado y corriendo en puerto 60001."
echo "🔐 Token secreto: $SECRET_TOKEN"
echo ""
echo "Puedes probarlo con:"
echo "curl -X POST http://localhost:60001/hooks/$APP_ID \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -H 'X-Hub-Token: $SECRET_TOKEN' \\"
echo "     -d '{\"ref\": \"refs/heads/main\"}'"
