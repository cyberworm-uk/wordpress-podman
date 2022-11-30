#!/bin/bash
function exist_fail() {
  printf "FAIL: Pod %s doesn't exist\n" "${1}"
  exit 1
}

# setup environment variables...
PREFIX=${1:-blog}

# check it exists...
podman pod exists "${PREFIX}" || exist_fail ${PREFIX}

# spawn an instance of wp-cli linked to the existing pod
podman run --rm -it --pod "${PREFIX}" --secret "${PREFIX}-mysql-root" -v "${PREFIX}-var-www-html:/var/www/html" -e WORDPRESS_DB_USER=root -e "WORDPRESS_DB_PASSWORD_FILE=/run/secrets/${PREFIX}-mysql-root" -e WORDPRESS_DB_NAME=blog -e WORDPRESS_DB_HOST=127.0.0.1 --entrypoint /bin/bash wordpress:cli

# once the shell is spawned, try the commands:
# wp core verify-checksums
# wp help
# wp help <subcommand>
