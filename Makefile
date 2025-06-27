# vim: set noexpandtab tabstop=4 shiftwidth=4:
PROJECT_NAME=magento247ce
PHP_CONTAINER=phpfpm
BASE_PATH=/var/www/html

prune:
	@docker image prune -a

stop_containers:
	@docker compose down

reset_volumes: stop_containers
    @docker compose down --volumes --remove-orphans

start:
	@docker compose up -d

setup:
	@docker compose exec $(PHP_CONTAINER) bash -c '\
	set -e; \
	env_file1=$$1; \
	env_file2=$$2; \
	while IFS== read -r key value; do export "$$key=$$value"; done < $$env_file1; \
	while IFS== read -r key value; do export "$$key=$$value"; done < $$env_file2; \
	echo "🔎  Variables cargadas:" $$MYSQL_DATABASE $$REPO_USERNAME $$MAGENTO_VERSION; \
	echo "🔐  Configurando autenticación con repo.magento.com → $$REPO_USERNAME"; \
	composer config --global http-basic.repo.magento.com $$REPO_USERNAME $$REPO_PASSWORD; \
	echo "📦  Descargando Magento versión $$MAGENTO_VERSION..."; \
	composer create-project --repository-url=https://repo.magento.com/ $$MAGENTO_VERSION $(BASE_PATH) ; \
	echo "✅  Magento descargado correctamente en $(BASE_PATH)"; \
	echo "";' _ /var/www/env/db.env /var/www/env/magento.env

init-db:
    @echo "🗄️  Creando base de datos y usuario en MySQL..."
    @export $$(grep -vE '^\s*#|^\s*$$' env/db.env | xargs) && \
    export $$(grep -vE '^\s*#|^\s*$$' env/magento.env | xargs) && \
    docker compose exec db mysql -uroot -p$$MYSQL_ROOT_PASSWORD -e "\
    CREATE DATABASE IF NOT EXISTS \`$$MYSQL_DATABASE\`; \
    CREATE USER IF NOT EXISTS \`$$MYSQL_USER\`@'%' IDENTIFIED BY '$$MYSQL_PASSWORD'; \
    GRANT ALL PRIVILEGES ON \`$$MYSQL_DATABASE\`.* TO \`$$MYSQL_USER\`@'%'; \
    FLUSH PRIVILEGES;"
	
install-magento:
	@echo "🛒️  Instalando Magento en el contenedor..."
	@docker compose exec $(PHP_CONTAINER) bash -c '\
	set -e; \
	env_file1=$$1; \
	env_file2=$$2; \
	while IFS== read -r key value; do export "$$key=$$value"; done < $$env_file1; \
	while IFS== read -r key value; do export "$$key=$$value"; done < $$env_file2; \
	cd $(BASE_PATH); \
	echo "⚙️  Ejecutando setup:install..."; \
	bin/magento setup:install \
	--base-url=http://localhost:8000 \
	--db-host=$$MYSQL_HOST \
	--db-name=$$MYSQL_DATABASE \
	--db-user=$$MYSQL_USER \
	--db-password=$$MYSQL_PASSWORD \
	--admin-firstname=Admin \
	--admin-lastname=User \
	--admin-email=admin@example.com \
	--admin-user=admin \
	--admin-password=admin123 \
	--language=es_ES \
	--currency=EUR \
	--timezone=Europe/Madrid \
	--use-rewrites=1; \
	echo "🎁 Instalando datos de muestra..."; \
	bin/magento sampledata:deploy; \
	bin/magento setup:upgrade; \
	bin/magento deploy:mode:set developer; \
	chmod -R 777 var pub generated; \
	echo "✅ Magento ha sido instalado correctamente.";' _ /var/www/env/db.env /var/www/env/magento.env

install:
    make up
    make setup
	make init-db
	make install-magento
	
shell:
	@docker compose exec phpfpm bash
