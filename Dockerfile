FROM alpine:3.7

LABEL com.ragedunicorn.maintainer="Michael Wiesendanger <michael.wiesendanger@gmail.com>"

#    __  ___           _       ____  ____
#   /  |/  /___ ______(_)___ _/ __ \/ __ )
#  / /|_/ / __ `/ ___/ / __ `/ / / / __  |
# / /  / / /_/ / /  / / /_/ / /_/ / /_/ /
#/_/  /_/\__,_/_/  /_/\__,_/_____/_____/

ENV \
  MARIADB_SERVER_VERSION=10.1.32-r0 \
  MARIADB_CLIENT_VERSION=10.1.32-r0 \
  SU_EXEC_VERSION=0.2-r0

ENV \
  MARIADB_USER=mysql \
  MARIADB_GROUP=mysql \
  MARIADB_BASE_DIR=/usr \
  MARIADB_DATA_DIR=/var/lib/mysql \
  MARIADB_RUN_DIR=/run/mysqld \
  MARIADB_ROOT_PASSWORD=root \
  MARIADB_APP_USER=app \
  MARIADB_APP_PASSWORD=app

# explicitly set user/group IDs
RUN addgroup -S "${MARIADB_GROUP}" -g 9999 && adduser -S -G "${MARIADB_GROUP}" -u 9999 "${MARIADB_USER}"

RUN \
  set -ex; \
  apk add --no-cache \
    su-exec="${SU_EXEC_VERSION}" \
    mariadb="${MARIADB_SERVER_VERSION}" \
    mariadb-client="${MARIADB_CLIENT_VERSION}"

# add custom mysql config
COPY config/my.cnf config/mysqld_charset.cnf /etc/mysql/

# add init scripts for mysql
COPY config/user.sql /home/user.sql

# add healthcheck script
COPY docker-healthcheck.sh /

# add launch script
COPY docker-entrypoint.sh /

RUN \
  chmod 644 /etc/mysql/my.cnf && \
  chown "${MARIADB_USER}":"${MARIADB_GROUP}" /etc/mysql/my.cnf && \
  chmod 644 /etc/mysql/mysqld_charset.cnf && \
  chown "${MARIADB_USER}":"${MARIADB_GROUP}" /etc/mysql/mysqld_charset.cnf && \
  chmod 755 docker-entrypoint.sh && \
  chmod 755 docker-healthcheck.sh

EXPOSE 3306

VOLUME ["${MARIADB_DATA_DIR}"]

ENTRYPOINT ["/docker-entrypoint.sh"]
