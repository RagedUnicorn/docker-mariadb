#!/bin/sh
# @author Michael Wiesendanger <michael.wiesendanger@gmail.com>
# @description launch script for mariadb

# abort when trying to use unset variable
set -o nounset

mariadb_root_password="/run/secrets/com.ragedunicorn.mariadb.root_password"
mariadb_app_user="/run/secrets/com.ragedunicorn.mariadb.app_user"
mariadb_app_user_password="/run/secrets/com.ragedunicorn.mariadb.app_user_password"

create_data_dir() {
  echo "$(date) [INFO]: Creating data directory ${MARIADB_DATA_DIR} and setting permissions"
  mkdir -p "${MARIADB_DATA_DIR}"
  chmod -R 0700 "${MARIADB_DATA_DIR}"
  chown -R "${MARIADB_USER}":"${MARIADB_USER}" "${MARIADB_DATA_DIR}"
}

create_run_dir() {
  echo "$(date) [INFO]: Creating run directory ${MARIADB_RUN_DIR} and setting permissions"
  mkdir -p "${MARIADB_RUN_DIR}"
  chown -R "${MARIADB_USER}":"${MARIADB_USER}" "${MARIADB_RUN_DIR}"
}

# replicating what mysql_secure_installation is doing
mysql_secure() {
  echo "$(date) [INFO]: Running MariaDB secure installation"
  # set password for root user
  mysql -e "UPDATE mysql.user SET Password = PASSWORD('${mariadb_root_password}') WHERE User = 'root'"
  # remove anonymous user
  mysql -e "DROP USER ''@'localhost'"
  # remove hostname anonymous user
  mysql -e "DROP USER ''@'$(hostname)'"
  # remove demo database
  mysql -e "DROP DATABASE test"
  # flush changes
  mysql -e "FLUSH PRIVILEGES"
}

set_init_done() {
  touch "${MARIADB_DATA_DIR}/.init"
  echo "$(date) [INFO]: Init script done"
}

init() {
  if `test -f "${MARIADB_DATA_DIR}/.init"`; then
    echo "$(date) [INFO]: Init script already run - starting MariaDB"
    # check if run directory exists
    create_run_dir
    # start mariadb in foreground with base- and datadir set
    exec su-exec ${MARIADB_USER} /usr/bin/mysqld_safe  --basedir="${MARIADB_BASE_DIR}" --datadir="${MARIADB_DATA_DIR}"
  else
    echo "$(date) [INFO]: First time setup - running init script"
    create_data_dir
    create_run_dir

    if [ -f "${mariadb_app_user}" ] && [ -f "${mariadb_app_user_password}" ] && [ -f "${mariadb_root_password}" ]; then
      echo "$(date) [INFO]: Found docker secrets - using secrets to setup mariadb"

      mariadb_app_user="$(cat ${mariadb_app_user})"
      mariadb_app_user_password="$(cat ${mariadb_app_user_password})"
      mariadb_root_user="$(cat ${mariadb_root_password})"

    else
      echo "$(date) [INFO]: No docker secrets found - using environment variables"

      mariadb_root_password="${MARIADB_ROOT_PASSWORD}"
      mariadb_app_user="${MARIADB_APP_USER}"
      mariadb_app_user_password="${MARIADB_APP_PASSWORD}"

      unset "${MARIADB_ROOT_PASSWORD}"
      unset "${MARIADB_APP_USER}"
      unset "${MARIADB_APP_PASSWORD}"
    fi

    # mariadb will not start if standard database is not initialzed
    /usr/bin/mysql_install_db --user="${MARIADB_USER}" --basedir="${MARIADB_BASE_DIR}" --datadir="${MARIADB_DATA_DIR}"

    # do not listen to external connections during setup. This helps while orchestarting
    # with other containers. They will only receive a response after the initialisation
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
    echo "$(date) [INFO]: Creating new user ${mariadb_app_user}"
    sed -e "s/{{password}}/${mariadb_app_user_password}/g" \
      -e "s/{{user}}/${mariadb_app_user}/g" /home/user.sql | mysql -uroot;

    mysql_secure

    if [ $? -ne 0 ]; then
      echo "$(date) [ERROR]: Failed to create new user";
      exit 1
    else
      echo "$(date) [INFO]: Created new app user"
    fi

    echo "$(date) [INFO]: Finished database setup"

    mysqladmin -uroot -p"${mariadb_root_password}" shutdown

    set_init_done
    # start mariadb in foreground
    exec su-exec ${MARIADB_USER} /usr/bin/mysqld_safe --basedir="${MARIADB_BASE_DIR}" --datadir="${MARIADB_DATA_DIR}"
  fi
}

init
