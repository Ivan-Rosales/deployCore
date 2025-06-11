# Nombre de los servicios
project:
	@DIR="$$(pwd)"; \
	BASENAME="$$(basename $$DIR )"; \
	echo "$$BASENAME"

# Comandos Docker
up:
	docker compose up -d --build

down:
	docker compose down

logs:
	docker compose logs -f

clean:
	docker-compose down -v --remove-orphans

rebuild:
	docker-compose build --no-cache

# Hooks
setup-webhook:
	@echo "🔓 Otorgando permisos de ejecución al script..."
	sudo chmod +x setup-webhook.sh
	@echo "🚧 Ejecutando script de setup webhook..."
	sudo ./setup-webhook.sh

