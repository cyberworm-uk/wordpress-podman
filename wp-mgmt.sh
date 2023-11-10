#!/bin/bash

# setup environment variables...
PREFIX=${1:-blog}

# spawn an instance of wp-cli linked to the existing pod
podman run --rm -it --secret "${PREFIX}" -v "systemd-${PREFIX}-wordpress:/var/www/html" -e WORDPRESS_DB_USER=root -e "WORDPRESS_DB_PASSWORD_FILE=/run/secrets/${PREFIX}" -e WORDPRESS_DB_NAME=blog -e WORDPRESS_DB_HOST="systemd-${PREFIX}-sql" --entrypoint /bin/bash docker.io/library/wordpress:cli

# once the shell is spawned, manage it with the wp command, e.g.:
# wp core verify-checksums
# wp core check-update
# wp theme update --all
# wp plugin update --all
# wp help
# wp help <subcommand>