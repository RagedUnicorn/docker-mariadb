#!/bin/sh
# @author Michael Wiesendanger <michael.wiesendanger@gmail.com>
# @description launch script for mariadb

# abort when trying to use unset variable
set -o nounset

create_data_dir() {
  if [ ! -d "${MARIADB_DATA_DIR}" ]; then
    echo "$(date) [INFO]: Creating data directory ${MARIADB_DATA_DIR} and setting permissions"
    mkdir -p "${MARIADB_DATA_DIR}"
    chmod -R 0700 "${MARIADB_DATA_DIR}"
    chown -R "${MARIADB_USER}":"${MARIADB_USER}" "${MARIADB_DATA_DIR}"
  fi
}

create_run_dir() {
  if [ ! -d "${MARIADB_RUN_DIR}" ]; then
    echo "$(date) [INFO]: Creating run directory ${MARIADB_RUN_DIR} and setting permissions"
    mkdir -p "${MARIADB_RUN_DIR}"
    chown -R "${MARIADB_USER}":"${MARIADB_USER}" "${MARIADB_RUN_DIR}"
  fi
}

set_init_done() {
  touch "${MARIADB_DATA_DIR}"/setup.d
  echo "$(date) [INFO]: Init script done"
}

init() {
  if `test -f "${MARIADB_DATA_DIR}/setup.d"`; then
    echo "$(date) [INFO]: Init script already run - starting MariaDB"

    # check if run directory exists
    create_run_dir
    # start mysql in foreground with base- and datadir set
    exec gosu ${MARIADB_USER} /usr/bin/mysqld_safe  --basedir="${MARIADB_BASE_DIR}" --datadir="${MARIADB_DATA_DIR}"
  else
    echo "$(date) [INFO]: First time setup - running init script"
    create_data_dir
    create_run_dir

    # mysql will not start if standard database is not initialzed
    /usr/bin/mysql_install_db --user="${MARIADB_USER}" --basedir="${MARIADB_BASE_DIR}" --datadir="${MARIADB_DATA_DIR}"

    # do not listen to external connections during setup. This helps while orchestarting
    # with other containers. They will only receive a response after the initialistation
    # is finished.
    /usr/bin/mysqld_safe --bind-address=localhost --basedir="${MARIADB_BASE_DIR}" --datadir="${MARIADB_DATA_DIR}" &

    LOOP_LIMIT=13
    i=0

    while true
    do
        if [ ${i} -eq ${LOOP_LIMIT} ]; then
            echo "$(date) [ERROR]: Timeout error, failed to start MariaDB server"
            exit 1
        fi
        echo "$(date) [INFO]: Waiting for confirmation of MariaDB service startup, trying ${i}/${LOOP_LIMIT} ..."
        sleep 5
        mysql -uroot -e "status" > /dev/null 2>&1 && break
        i=`expr $i + 1`
    done

    # create new user and grant remote access
    echo "$(date) [INFO]: Creating new user ${MARIADB_APP_USER}"
    sed -e "s/{{password}}/${MARIADB_APP_PASSWORD}/g" \
        -e "s/{{user}}/${MARIADB_APP_USER}/g" /home/user.sql | mysql -uroot;

    if [ $? -ne 0 ]; then
      echo "$(date) [ERROR]: Failed to create new user";
      exit 1
    else
      echo "$(date) [INFO]: Created user:"
      echo "$(date) [INFO]: Username: ${MARIADB_APP_USER}"
      echo "$(date) [INFO]: Password: ${MARIADB_APP_PASSWORD}"
    fi

    echo "$(date) [INFO]: Finished database setup"

    mysqladmin -uroot shutdown

    unset "${MARIADB_APP_USER}"
    unset "${MARIADB_APP_PASSWORD}"

    set_init_done
    # start mysql in foreground
    exec gosu ${MARIADB_USER} /usr/bin/mysqld_safe --basedir="${MARIADB_BASE_DIR}" --datadir="${MARIADB_DATA_DIR}"
  fi
}

init
