#!/bin/bash

function cleanup() {
  rm "${1}.sql" "${1}-wordpress.tar"
}

# setup environment variables...
PREFIX=${1:-blog}
PASSWORD=`podman exec "systemd-${PREFIX}-sql" cat "/run/secrets/${PREFIX}"`

# export database...
podman exec "systemd-${PREFIX}-sql" mariadb-dump -uroot -p"${PASSWORD}" --databases blog > "${PREFIX}.sql"
# export wordpress files...
podman volume export "systemd-${PREFIX}-wordpress" -o "${PREFIX}-wordpress.tar"
# compress exports...
tar zcf "${PREFIX}-backup.tar.gz" "${PREFIX}.sql" "${PREFIX}-wordpress.tar" && cleanup ${PREFIX}