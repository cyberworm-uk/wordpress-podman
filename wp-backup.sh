#!/bin/bash
function exist_fail() {
  printf "FAIL: Pod %s doesn't exist\n" "${1}"
  exit 1
}

function cleanup() {
  rm "${1}-db.sql" "${1}-var-www-html.tar"
}

# setup environment variables...
PREFIX=${1:-blog}
# check it exists...
podman pod exists "${PREFIX}" || exist_fail ${PREFIX}
PASSWORD=`podman exec "${PREFIX}-db" cat "/run/secrets/${PREFIX}-mysql-root"`

# export database...
podman exec "${PREFIX}-db" mysqldump -uroot -p"${PASSWORD}" --databases blog > "${PREFIX}-db.sql"
# export wordpress files...
podman volume export "${PREFIX}-var-www-html" > "${PREFIX}-var-www-html.tar"
# compress exports...
tar zcf "${PREFIX}-backup.tar.gz" "${PREFIX}-db.sql" "${PREFIX}-var-www-html.tar" && cleanup ${PREFIX}
