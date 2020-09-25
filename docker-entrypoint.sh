#!/bin/bash
# @author Michael Wiesendanger <michael.wiesendanger@gmail.com>
# @description launch script for mariadb

set -euo pipefail

mariadb_root_password="/run/secrets/com.ragedunicorn.mariadb.root_password"
mariadb_app_user="/run/secrets/com.ragedunicorn.mariadb.app_user"
mariadb_app_password="/run/secrets/com.ragedunicorn.mariadb.app_user_password"

function create_data_dir() {
  echo "$(date) [INFO]: Creating data directory ${MARIADB_DATA_DIR} and setting permissions"
  mkdir -p "${MARIADB_DATA_DIR}"
  chmod -R 0700 "${MARIADB_DATA_DIR}"
  chown -R "${MARIADB_USER}":"${MARIADB_GROUP}" "${MARIADB_DATA_DIR}"
}

function create_run_dir() {
  echo "$(date) [INFO]: Creating run directory ${MARIADB_RUN_DIR} and setting permissions"
  mkdir -p "${MARIADB_RUN_DIR}"
  chown -R "${MARIADB_USER}":"${MARIADB_GROUP}" "${MARIADB_RUN_DIR}"
}

# replicating what mysql_secure_installation is doing
function mysql_secure() {
  echo "$(date) [INFO]: Running MariaDB secure installation"
  # set password for root user
  mysql -e "UPDATE mysql.user SET Password = PASSWORD('${mariadb_root_password}') WHERE User = 'root'"
  # remove demo database
  mysql -e "DROP DATABASE test"
  # flush changes
  mysql -e "FLUSH PRIVILEGES"
}

function set_init_done() {
  touch "${MARIADB_DATA_DIR}/.init"
  echo "$(date) [INFO]: Init script done"
}

function init() {
  if [ -f  "${MARIADB_DATA_DIR}/.init" ]; then
    echo "$(date) [INFO]: Init script already run - starting MariaDB"
    # check if run directory exists
    create_run_dir
    # start mariadb in foreground with base- and datadir set
    exec gosu "${MARIADB_USER}" /usr/bin/mysqld_safe  --basedir="${MARIADB_BASE_DIR}" --datadir="${MARIADB_DATA_DIR}"
  else
    echo "$(date) [INFO]: First time setup - running init script"
    create_data_dir
    create_run_dir

    if [ $? -ne 0 ]; then
      echo "$(date) [ERROR]: Failed to initialize mysqld - aborting...";
      exit 1
    fi

    if [ -f "${mariadb_app_user}" ] && [ -f "${mariadb_app_password}" ] && [ -f "${mariadb_root_password}" ]; then
      echo "$(date) [INFO]: Found docker secrets - using secrets to setup mariadb"

      mariadb_root_password="$(cat ${mariadb_root_password})"
      mariadb_app_user="$(cat ${mariadb_app_user})"
      mariadb_app_password="$(cat ${mariadb_app_password})"
    else
      echo "$(date) [INFO]: No docker secrets found - using environment variables"

      mariadb_root_password="${MARIADB_ROOT_PASSWORD:?Missing environment variable MARIADB_ROOT_PASSWORD}"
      mariadb_app_user="${MARIADB_APP_USER:?Missing environment variable MARIADB_APP_USER}"
      mariadb_app_password="${MARIADB_APP_PASSWORD:?Missing environment variable MARIADB_APP_PASSWORD}"
    fi

    unset "${MARIADB_ROOT_PASSWORD}"
    unset "${MARIADB_APP_USER}"
    unset "${MARIADB_APP_PASSWORD}"

    # mariadb will not start if standard database is not initialzed
    /usr/bin/mysql_install_db --user="${MARIADB_USER}" --basedir="${MARIADB_BASE_DIR}" --datadir="${MARIADB_DATA_DIR}"

    # do not listen to external connections during setup. This helps while orchestarting
    # with other containers. They will only receive a response after the initialisation
    # is finished.
    /usr/bin/mysqld_safe --bind-address=localhost --basedir="${MARIADB_BASE_DIR}" --datadir="${MARIADB_DATA_DIR}" &

    LOOP_LIMIT=13
    i=1

    while true
    do
      if [ ${i} -gt ${LOOP_LIMIT} ]; then
        echo "$(date) [ERROR]: Timeout error, failed to start MariaDB server"
        exit 1
      fi
      echo "$(date) [INFO]: Waiting for confirmation of MariaDB service startup, trying ${i}/${LOOP_LIMIT} ..."
      sleep 5
      mysql -uroot -e "status" > /dev/null 2>&1 && break
      i=$((i + 1))
    done

    # create new user and grant remote access
    echo "$(date) [INFO]: Creating new user ${mariadb_app_user}"
    sed -e "s/{{password}}/${mariadb_app_password}/g" \
      -e "s/{{user}}/${mariadb_app_user}/g" /home/user.sql | mysql -uroot;

    if [ $? -ne 0 ]; then
      echo "$(date) [ERROR]: Failed to create new user";
      exit 1
    else
      echo "$(date) [INFO]: Created new user: ${mariadb_app_user}"
    fi

    mysql_secure

    echo "$(date) [INFO]: Finished database setup"

    mysqladmin -uroot -p"${mariadb_root_password}" shutdown

    set_init_done

    # start mariadb in foreground
    exec gosu "${MARIADB_USER}" /usr/bin/mysqld_safe --basedir="${MARIADB_BASE_DIR}" --datadir="${MARIADB_DATA_DIR}"
  fi
}

init
