# 📘 Documentación del Proyecto
<h4>
Este proyecto proporciona una plantilla base para implementar CI/CD en APIs desarrolladas con Django, enfocada en despliegues automatizados, seguros y repetibles utilizando Docker, Docker Compose, y sistemas de webhooks con GitHub o GitLab.

Su objetivo es acelerar la integración y despliegue continuo de servicios backend estandarizados, con una estructura clara y reutilizable para nuevos proyectos.
</h4>

---

## 📑 Índice

1. [📁 Estructura del Proyecto](#estructura-del-proyecto)
2. [🛠️ Comandos disponibles (Makefile)](#comandos-disponibles-makefile)
3. [📦 Requisitos Previos](#requisitos-previos)
4. [⚙️ Instalación del Proyecto](#instalacion-del-proyecto)
5. [📌 Notas](#notas)
6. [✅ Buenas Prácticas en Commits](#buenas-practicas-en-commits)
7. [🧑‍💻 Autor](#autor)

---

## 📁 Estructura del Proyecto <a name="estructura-del-proyecto"></a>

A continuación se describe la estructura principal de un proyecto de apis con Django:

```
myproject/              # Proyecto Django
├── apps-api/                      # Aplicación principal de Django
│   ├── admin.py              # Configuración del panel de administración
│   ├── apps.py               # Configuración de la app para Django
│   ├── models.py             # Modelos de base de datos
│   ├── serializers.py        # Serializadores para la API REST
│   ├── tests.py              # Pruebas unitarias
│   ├── urls.py               # Rutas específicas de esta app
│   └── views.py              # Vistas (funciones o clases) de la app
│
├── myproject/                # Configuración global del proyecto
│   ├── __init__.py
│   ├── asgi.py               # Configuración para despliegues con ASGI
│   ├── router.py             # Enrutador central de la API
│   ├── settings.py           # Configuración principal de Django
│   ├── urls.py               # Rutas generales del proyecto
│   └── wsgi.py               # Configuración para despliegues con WSGI
│
├── .gitignore                # Archivos y carpetas ignoradas por Git
├── db.sqlite3                # Base de datos SQLite (modo local/desarrollo)
├── manage.py                 # Herramienta CLI de Django
├── poetry.lock               # Dependencias bloqueadas por Poetry
├── pyproject.toml            # Configuración del proyecto y dependencias
├── README.md                 # Documentación principal del proyecto
├── .env.template             # Plantilla para el archivo de variables de entorno (.env)
├── Makefile                  # Archivo Makefile para automatizar tareas comunes (build, test, deploy, etc.)
├── setup-webhook.sh          # Script para configurar el webhook (instalación o configuración)
└── setup-webhook.sh.sig      # Firma criptográfica del script setup-webhook.sh para verificar integridad
```

---

## 🛠️ Comandos disponibles (Makefile) <a name="comandos-disponibles-makefile"></a>

| Comando              | Descripción                                         |
|----------------------|-----------------------------------------------------|
| `make project`        | Muestra el nombre del proyecto                      |
| `make up`             | Levanta los contenedores Docker                     |
| `make down`           | Detiene los contenedores                            |
| `make logs`           | Muestra logs en tiempo real                         |
| `make clean`          | Limpia volúmenes y contenedores huérfanos           |
| `make rebuild`        | Reconstruye imágenes Docker sin caché               |
| `make setup-webhook`  | Instala Webhook para redeploy de app                |

---


## 📦 Requisitos Previos <a name="requisitos-previos"></a>

Antes de iniciar la instalación en modo **Desarrollo** o **Producción**, asegúrate de:

1. Ejecutar la actualización de paquetes en tu servidor o equipo:

   ```bash
   sudo apt update
   ```

2. Tener instalado el paquete `make`, necesario para ejecutar comandos definidos en el `Makefile`.  
   Puedes instalarlo con:

   ```bash
   sudo apt install make
   ```

3. Verificar que tu proyecto incluya un archivo `docker-compose.yml` en la **raíz del proyecto**.  
   Este archivo es indispensable para permitir los despliegues automáticos mediante `Makefile` y `setup-webhook.sh`.

4. Asegurarte de que los siguientes archivos también estén ubicados en la **ruta raíz del proyecto**:

   - `.env.template`
   - `Makefile`
   - `README.md`
   - `setup-webhook.sh`
   - `setup-webhook.sh.sig`

---


## ⚙️ Instalación del Proyecto <a name="instalacion-del-proyecto"></a>

### 1. Configurar el archivo `.env`

- Usa el archivo `.env.template` como base:

   ```bash
   cp .env.template ../.env
   ```

- Completa los valores necesarios en `.env`.
    - Usuario (`ISAPI_USER`)
    - Contraseña (`ISAPI_PASSWORD`)
    - Host (`ISAPI_HOST`)
    - Nombre de la base de datos (`ISAPI_NAME`)
    - Modo (`ISAPI_DEBUG`)
    - Motor de base de datos (`ISAPI_ENGINE`)

---

### 2. Levantar contenedores con Docker

```bash
make up
```

---

### 3. Instalar Webhook para despliegue automático

```bash
make setup-webhook
```

---

### 4. Configurar Webhook en GitHub-GitLab

- Dirígete a tu repositorio en GitHub o GitLab → **Settings** → **Webhooks** → **Add webhook**
- Configura los siguientes valores:

  - **Payload URL**: `http://<tu-dominio-o-ip>:<puerto-configurado>/webhook`
  - **Content type**: `application/json`
  - **Secret**: Usa el token definido en tu Makefile (`make setup-webhook`)
  - **Events**: Selecciona `Just the push event`

---

## 📌 Notas <a name="notas"></a>
Este proyecto está pensado como punto de partida. Puedes extenderlo con pruebas automatizadas, análisis de calidad, o integración con servicios en la nube.

El script de setup-webhook.sh puede personalizarse para soportar diferentes repositorios o autenticación avanzada.

---

## ✅ Buenas Prácticas en Commits <a name="buenas-practicas-en-commits"></a>

Basado en el flujo de trabajo [GitFlow](https://www.atlassian.com/es/git/tutorials/comparing-workflows/gitflow-workflow):

- 👾 `FIX:` Correcciones a bugs, fallas de integridad o errores de programación.
- ♻️ `REFACTOR:` Refactorización o mejora de funcionalidades existentes.
- ➕ `FEAT:` Nueva funcionalidad implementada.
- 📝 `SQL:` Cambios en base de datos, archivos `.sql`, migraciones.
- 👔 `STYLE:` Cambios relacionados a estilo o estética.
- 📚 `DOCS:` Documentación, minutas, acuerdos.
- 🧪 `TEST:` Adición o modificación de pruebas sin afectar el código base.
- 🔩 `CHORE:` Mantenimiento general del código.
- ☠️ `DELETE:` Eliminación de funciones o archivos.
- 🔄 `CI:` Cambios en integración continua.

---

## 🧑‍💻 Autor <a name="autor"></a>
Desarrollado por:
- [Giovanni Trujillo Silvas](https://github.com/GtrujilloTS)
- Contribuciones y mejoras son bienvenidas.

---