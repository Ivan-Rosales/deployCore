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

ports:
	@echo "🔓 Otorgando permisos de ejecución al script..."
	sudo chmod +x free-port.sh	
	@echo "🚧 Ejecutando script de free ports..."
	sudo ./free-port.sh;

site-nginx:
	@if [ "$(filter-out $@,$(MAKECMDGOALS))" = "" ]; then \
		echo "❌ Uso correcto: make site <nombre_sitio> <puerto_externo> <puerto_local>"; \
		exit 1; \
	fi
	@nombre_sitio=$(word 1, $(MAKECMDGOALS)); \
	puerto_externo=$(word 2, $(MAKECMDGOALS)); \
	puerto_local=$(word 3, $(MAKECMDGOALS)); \
	if [ -z "$$nombre_sitio" ] || [ -z "$$puerto_externo" ] || [ -z "$$puerto_local" ]; then \
		echo "❌ Faltan argumentos. Uso: make site <nombre_sitio> <puerto_externo> <puerto_local>"; \
		exit 1; \
	fi; \
	echo "🔓 Otorgando permisos de ejecución al script..."; \
	sudo chmod +x activate-site.sh; \
	echo "🚧 Ejecutando script de activar sitio..."; \
	sudo ./activate-site.sh $$nombre_sitio $$puerto_externo $$puerto_local

%:
	@:
# Hooks
setup-webhook:
	@echo "🔓 Otorgando permisos de ejecución al script..."
	sudo chmod +x setup-webhook.sh
	@echo "🚧 Ejecutando script de setup webhook..."
	@if [ -z "$(branch)" ]; then \
		echo "Usando rama por defecto: main"; \
		sudo ./setup-webhook.sh; \
	else \
		echo "Usando rama: $(branch)"; \
		sudo ./setup-webhook.sh $(branch); \
	fi