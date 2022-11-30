#!/bin/bash
function conflict_fail() {
  printf "FAIL: Conflicting %s (%s)\n" "${1}" "${2}"
  exit 1
}

# setup environment variables...
DB_PASSWORD="$(head -c 32 /dev/urandom | base64 | tr -cd "[a-zA-Z0-9]")"
PREFIX=${1:-blog}

# check for conflicts...
podman pod exists "${PREFIX}" && conflict_fail pod "${PREFIX}"
podman volume exists "${PREFIX}-var-www-html" && conflict_fail volume "${PREFIX}-var-www-html"
podman volume exists "${PREFIX}-mariadb" && conflict_fail volume "${PREFIX}-mariadb"
podman volume exists "${PREFIX}-nginx-conf" && conflict_fail volume "${PREFIX}-nginx-conf"
podman container exists "${PREFIX}-db" && conflict_fail container "${PREFIX}-db"
podman container exists "${PREFIX}-fpm" && conflict_fail container "${PREFIX}-fpm"
podman container exists "${PREFIX}-nginx" && conflict_fail container "${PREFIX}-nginx"

# create storage volumes...
podman volume create "${PREFIX}-var-www-html"
podman volume create "${PREFIX}-mariadb"
podman volume create "${PREFIX}-nginx-conf"

# create resources (optionally publish on port 80)...
podman pod create --name "${PREFIX}" #--publish 80:80/tcp
# create a secret to store mysql password...
printf "%s" "${DB_PASSWORD}" | podman secret create "${PREFIX}-mysql-root" -
# generate basic nginx config...
echo 'server {
  listen 80;
  listen [::]:80;
  root /var/www/html;
  index index.php;
  server_name _;
  server_tokens off;
  location / {
    try_files $uri $uri/ /index.php?$args;
  }
  location ~ \.php$ {
    fastcgi_split_path_info ^(.+\.php)(/.+)$;
    fastcgi_pass 127.0.0.1:9000;
    fastcgi_index index.php;
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    fastcgi_param SCRIPT_NAME $fastcgi_script_name;
  }
}' > $(podman volume inspect -f '{{ .Mountpoint }}' "${PREFIX}-nginx-conf")/blog.conf
# spawn mariadb instance...
podman run --pod ${PREFIX} --rm -d --label io.containers.autoupdate=registry \
  --name "${PREFIX}-db" \
  --secret "${PREFIX}-mysql-root" \
  --env MARIADB_ROOT_PASSWORD_FILE="/run/secrets/${PREFIX}-mysql-root" \
  --env MARIADB_DATABASE=blog \
  --volume "${PREFIX}-mariadb:/var/lib/mysql" \
  docker.io/library/mariadb:latest
# spawn fpm instance to execute requests...
podman run --pod ${PREFIX} --rm -d --label io.containers.autoupdate=registry \
  --name "${PREFIX}-fpm" \
  --secret "${PREFIX}-mysql-root" \
  --env WORDPRESS_DB_HOST=127.0.0.1 \
  --env WORDPRESS_DB_USER=root \
  --env WORDPRESS_DB_PASSWORD_FILE="/run/secrets/${PREFIX}-mysql-root" \
  --env WORDPRESS_DB_NAME=blog \
  --volume "${PREFIX}-var-www-html:/var/www/html" \
  docker.io/library/wordpress:fpm-alpine
# spawn nginx instance to serve requests...
podman run --pod ${PREFIX} --rm -d --label io.containers.autoupdate=registry \
  --name "${PREFIX}-nginx" \
  --volume "${PREFIX}-nginx-conf:/etc/nginx/conf.d" \
  --volume "${PREFIX}-var-www-html:/var/www/html" \
  docker.io/library/nginx:alpine
