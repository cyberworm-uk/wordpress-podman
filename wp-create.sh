#!/usr/bin/env bash

DB_PASSWORD="$(head -c 32 /dev/urandom | base64 | tr -cd "[a-zA-Z0-9]")"
PREFIX=${1:-$(head -c 8 /dev/urandom | hexdump -e'"%x"')}

printf "%s" "${DB_PASSWORD}" | podman secret create "${PREFIX}" -

SQL_CONTAINER="[Unit]
Description=${PREFIX} SQL container

[Container]
Image=docker.io/library/mariadb:latest
AutoUpdate=registry

Volume=${PREFIX}-sql.volume:/var/lib/mysql
Secret=${PREFIX}
Network=${PREFIX}.network

Environment=MARIADB_ROOT_PASSWORD_FILE=/run/secrets/${PREFIX}
Environment=MARIADB_DATABASE=blog

[Service]
Restart=always
TimeoutStartSec=900

[Install]
WantedBy=systemd-${PREFIX}-wordpress.service"

WORDPRESS_CONTAINER="[Unit]
Description=${PREFIX} Wordpress container

[Container]
Image=docker.io/library/wordpress:fpm-alpine
AutoUpdate=registry

Volume=${PREFIX}-wordpress.volume:/var/www/html
Secret=${PREFIX}
Network=${PREFIX}.network

Environment=WORDPRESS_DB_HOST=systemd-${PREFIX}-sql
Environment=WORDPRESS_DB_USER=root
Environment=WORDPRESS_DB_PASSWORD_FILE=/run/secrets/${PREFIX}
Environment=WORDPRESS_DB_NAME=blog

[Service]
Restart=always
TimeoutStartSec=900

[Install]
WantedBy=systemd-${PREFIX}-nginx.service"

NGINX_CONTAINER="[Unit]
Description=${PREFIX} Nginx container

[Container]
Image=docker.io/library/nginx:alpine
AutoUpdate=registry

Volume=${PREFIX}-wordpress.volume:/var/www/html
Volume=${PREFIX}-nginx.volume:/etc/nginx/conf.d
Network=${PREFIX}.network

Environment=MARIADB_ROOT_PASSWORD_FILE=/run/secrets/${PREFIX}
Environment=MARIADB_DATABASE=blog

[Service]
Restart=always
TimeoutStartSec=900

[Install]
WantedBy=default.target"

NGINX_CONFIG="server {
  listen 80;
  listen [::]:80;
  root /var/www/html;
  index index.php;
  server_name _;
  server_tokens off;
  location / {
    try_files \$uri \$uri/ /index.php?\$args;
  }
  location ~ \.php$ {
    fastcgi_split_path_info ^(.+\.php)(/.+)$;
    fastcgi_pass systemd-${PREFIX}-wordpress:9000;
    fastcgi_index index.php;
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    fastcgi_param SCRIPT_NAME \$fastcgi_script_name;
  }
}"

NETWORK_CONFIG="[Network]
IPv6=true"

# create this manually, to we can inject our config to use the php-fpm.
podman volume create "systemd-${PREFIX}-nginx" && \
  echo "${NGINX_CONFIG}" > $(podman volume inspect -f '{{ .Mountpoint }}' "systemd-${PREFIX}-nginx")/default.conf

echo "${SQL_CONTAINER}" > "${PREFIX}-sql.container"
echo "${WORDPRESS_CONTAINER}" > "${PREFIX}-wordpress.container"
echo "${NGINX_CONTAINER}" > "${PREFIX}-nginx.container"
echo "[Volume]" | tee "${PREFIX}-sql.volume" | tee "${PREFIX}-wordpress.volume" | tee "${PREFIX}-nginx.volume"
echo "${NETWORK_CONFIG}" > "${PREFIX}.network"
