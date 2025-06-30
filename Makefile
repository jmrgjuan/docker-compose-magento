PROJECT_NAME=magento247ee
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

init-db:
	@echo "🗄️  Creando base de datos y usuario en MySQL..."
	@export $$(grep -vE '^\s*#|^\s*$$' env/db.env | xargs) && \
	docker compose exec db mysql -uroot -p$$MYSQL_ROOT_PASSWORD -e "\
	DROP DATABASE IF EXISTS \`$$MYSQL_DATABASE\`; \
	CREATE DATABASE IF NOT EXISTS \`$$MYSQL_DATABASE\`; \
	CREATE USER IF NOT EXISTS \`$$MYSQL_USER\`@'%' IDENTIFIED BY '$$MYSQL_PASSWORD'; \
	GRANT ALL PRIVILEGES ON \`$$MYSQL_DATABASE\`.* TO \`$$MYSQL_USER\`@'%'; \
	FLUSH PRIVILEGES;"

setup-composer:
	@echo "🛒️  Descargando Magento en el contenedor via composer..."
	@docker compose exec $(PHP_CONTAINER) bash -c '\
	set -e; \
	env_file1=$$1; \
	for f in $$env_file1; do \
	while IFS== read -r key value; do export "$$key=$$value"; done < "$$f"; \
	done; \
	cd $(BASE_PATH); \
	echo "🔐  Configurando auth repo.magento.com"; \
	composer config --global http-basic.repo.magento.com $$REPO_USERNAME $$REPO_PASSWORD; \
	echo "📦  Descargando Magento versión $$MAGENTO_VERSION..."; \
	composer create-project --repository-url=https://repo.magento.com/ $$MAGENTO_VERSION $(PROJECT_NAME) ; \
	echo "✅  Proyecto composer descargado correctamente en $(PROJECT_NAME)"; \
	echo "";' _ /var/www/env/magento.env

setup-magento:
	@echo "🛒️  Instalando Magento en el contenedor..."
	@docker compose exec $(PHP_CONTAINER) bash -c '\
	set -e; \
	env_file1=$$1; env_file2=$$2; env_file3=$$3; \
	for f in $$env_file1 $$env_file2 $$env_file3; do \
	while IFS== read -r key value; do export "$$key=$$value"; done < "$$f"; \
	done; \
	cd $(PROJECT_NAME); \
	echo "🔐  Configurando auth repo.magento.com"; \
	composer config --global http-basic.repo.magento.com $$REPO_USERNAME $$REPO_PASSWORD; \
	echo "⚙️  Ejecutando setup:install..."; \
	bin/magento setup:install --base-url=$$MAGENTO_BASE_URL \
	--db-host=$$MYSQL_HOST --db-name=$$MYSQL_DATABASE \
	--db-user=$$MYSQL_USER --db-password=$$MYSQL_PASSWORD \
	--search-engine=opensearch \
	--opensearch-host=$$OPENSEARCH_HOST --opensearch-port=$$OPENSEARCH_PORT \
	--opensearch-index-prefix=$$OPENSEARCH_PREFIX --opensearch-enable-auth=0 \
	--admin-firstname=Admin --admin-lastname=User \
	--admin-email=admin@example.com --admin-user=admin \
	--admin-password=$$MAGENTO_ADMIN_PASSWORD \
	--language=es_ES --currency=EUR --timezone=Europe/Madrid --use-rewrites=1; \
	echo "🚫 Desactivando Two-Factor Authentication..."; \
	bin/magento module:disable Magento_TwoFactorAuth Magento_AdminAdobeImsTwoFactorAuth; \
	echo "🛒 Instalando eshopworld (**arreglar auth composer**)..."; \
	echo "   --> revisar /var/www/html/magento247ee/var/composer_home/auth.json"; \
	echo "composer require $$ESHOPWORLD_VERSION"; \
	echo "🎁 Instalando datos de muestra..."; \
	bin/magento sampledata:deploy; \
	bin/magento setup:upgrade; \
	chmod -R 777 var pub generated; \
	echo "✅  Magento instalado correctamente en $(BASE_PATH)"; \
	echo "";' _ /var/www/env/db.env /var/www/env/magento.env /var/www/env/opensearch.env

install:
	make setup-composer
	make init-db
	make setup-magento

shell:
	@docker compose exec phpfpm bash
