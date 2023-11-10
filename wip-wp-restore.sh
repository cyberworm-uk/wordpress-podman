#!/bin/bash

# work in progress

# to restore, first ensure that the service is ready to run.
# - the systemd-${PREFIX}-wordpress volume has been created, but service isn't running.
# - the root sql secret has been created
# - the sql server is running
# argument 1 should be prefix, argument 2 should be the tar backup of the wordpress volume, argument 3 should be the SQL dump
# e.g.
# ./wip-wp-restore blog blog-wordpress.tar blog.sql

# setup environment variables...
PREFIX=${1:-blog}
PASSWORD=`podman exec "systemd-${PREFIX}-sql" cat "/run/secrets/${PREFIX}"`
TAR=${2:-${PREFIX}-wordpress.tar}
SQL=${3:-${PREFIX}.sql}

podman volume import "systemd-${PREFIX}-wordpress" "${TAR}"

podman exec -i "systemd-${PREFIX}-sql" mariadb -u root --password="${PASSWORD}" < "${SQL}"