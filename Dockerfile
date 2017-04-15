FROM alpine:3.5

LABEL com.ragedunicorn.maintainer="Michael Wiesendanger <michael.wiesendanger@gmail.com>" \
  com.ragedunicorn.version="1.0"

#    __  ___           _       ____  ____
#   /  |/  /___ ______(_)___ _/ __ \/ __ )
#  / /|_/ / __ `/ ___/ / __ `/ / / / __  |
# / /  / / /_/ / /  / / /_/ / /_/ / /_/ /
#/_/  /_/\__,_/_/  /_/\__,_/_____/_____/

ENV \
  MARIADB_USER=mysql \
  MARIADB_BASE_DIR=/usr \
  MARIADB_DATA_DIR=/var/lib/mysql \
  MARIADB_RUN_DIR=/run/mysqld \
  MARIADB_APP_USER=app \
  MARIADB_APP_PASSWORD=app

ENV \
  GOSU_VERSION=1.10 \
  MARIADB_SERVER_VERSION=10.1.22-r0 \
  MARIADB_CLIENT_VERSION=10.1.22-r0

# explicitly set user/group IDs
RUN addgroup -S "${MARIADB_USER}" -g 9999 && adduser -S -G "${MARIADB_USER}" -u 9999 "${MARIADB_USER}"

RUN \
  apk add --no-cache --virtual .gosu-deps dpkg gnupg openssl && \
  dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" && \
  wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" && \
  wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc" && \
  export GNUPGHOME && \
  GNUPGHOME="$(mktemp -d)" && \
  gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && \
  gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu && \
  rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc && \
  chmod +x /usr/local/bin/gosu && \
  gosu nobody true && \
  apk del .gosu-deps

# using no-cache option to avoid apk update and removing of /var/chache/apk/*
RUN \
  apk add --no-cache mariadb="${MARIADB_SERVER_VERSION}" mariadb-client="${MARIADB_CLIENT_VERSION}"

# add custom mysql conf
COPY conf/my.cnf conf/mysqld_charset.cnf /etc/mysql/

# add init scripts for mysql
COPY conf/user.sql /home/user.sql

# add launch script
COPY docker-entrypoint.sh /

RUN \
  chmod 644 /etc/mysql/my.cnf && \
  chown mysql /etc/mysql/my.cnf && \
  chmod 644 /etc/mysql/mysqld_charset.cnf && \
  chown mysql /etc/mysql/mysqld_charset.cnf && \
  chmod 755 docker-entrypoint.sh

EXPOSE 3306

VOLUME ["${MARIADB_DATA_DIR}"]

ENTRYPOINT ["/docker-entrypoint.sh"]
