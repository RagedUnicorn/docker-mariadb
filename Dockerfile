FROM ubuntu:groovy

LABEL com.ragedunicorn.maintainer="Michael Wiesendanger <michael.wiesendanger@gmail.com>"

#    __  ___           _       ____  ____
#   /  |/  /___ ______(_)___ _/ __ \/ __ )
#  / /|_/ / __ `/ ___/ / __ `/ / / / __  |
# / /  / / /_/ / /  / / /_/ / /_/ / /_/ /
#/_/  /_/\__,_/_/  /_/\__,_/_____/_____/

# image args
ARG MARIADB_USER=mysql
ARG MARIADB_GROUP=mysql
ARG MARIADB_APP_USER=app
ARG MARIADB_APP_PASSWORD=app
ARG MARIADB_ROOT_PASSWORD=root

ENV \
  MARIADB_VERSION=1:10.3.24-2 \
  WGET_VERSION=1.20.3-1ubuntu1 \
  CA_CERTIFICATES_VERSION=20200601 \
  DIRMNGR_VERSION=2.2.20-1ubuntu1 \
  GOSU_VERSION=1.10 \
  GPG_VERSION=2.2.20-1ubuntu1 \
  GPG_AGENT_VERSION=2.2.20-1ubuntu1

ENV \
  MARIADB_USER="${MARIADB_USER}" \
  MARIADB_GROUP="${MARIADB_GROUP}" \
  MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD}" \
  MARIADB_APP_USER="${MARIADB_APP_USER}" \
  MARIADB_APP_PASSWORD="${MARIADB_APP_PASSWORD}" \
  MARIADB_BASE_DIR=/usr \
  MARIADB_DATA_DIR=/var/lib/mysql \
  MARIADB_RUN_DIR=/var/run/mysqld \
  GOSU_GPGKEY="B42F6819007F00F88E364FD4036A9C25BF357DD4"

# explicitly set user/group IDs
RUN groupadd -g 9999 -r "${MARIADB_USER}" && useradd -u 9999 -r -g "${MARIADB_GROUP}" "${MARIADB_USER}"

RUN \
  set -ex; \
  apt-get update && apt-get install -y --no-install-recommends \
    dirmngr="${DIRMNGR_VERSION}" \
    ca-certificates="${CA_CERTIFICATES_VERSION}" \
    wget="${WGET_VERSION}" \
    gpg="${GPG_VERSION}" \
    gpg-agent="${GPG_AGENT_VERSION}" \
    mariadb-server="${MARIADB_VERSION}" \
    mariadb-client="${MARIADB_VERSION}" && \
  dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" && \
  if ! wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-${dpkgArch}"; then \
    echo >&2 "Error: Failed to download Gosu binary for '${dpkgArch}'"; \
    exit 1; \
  fi && \
  if ! wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-${dpkgArch}.asc"; then \
    echo >&2 "Error: Failed to download transport armor file for Gosu - '${dpkgArch}'"; \
    exit 1; \
  fi && \
  export GNUPGHOME && \
  GNUPGHOME="$(mktemp -d)" && \
  for server in \
    hkp://p80.pool.sks-keyservers.net:80 \
    hkp://keyserver.ubuntu.com:80 \
    hkp://pgp.mit.edu:80 \
  ;do \
    echo "Fetching GPG key ${GOSU_GPGKEY} from $server"; \
    gpg --keyserver "$server" --recv-keys "${GOSU_GPGKEY}" && found=yes && break; \
  done && \
  gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu && \
  rm -rf "${GNUPGHOME}" /usr/local/bin/gosu.asc && \
  chmod +x /usr/local/bin/gosu && \
  gosu nobody true && \
  apt-get purge -y --auto-remove ca-certificates wget dirmngr gpg gpg-agent && \
  rm -rf /var/lib/apt/lists/*



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
  chmod 755 /docker-entrypoint.sh && \
  chmod 755 /docker-healthcheck.sh

EXPOSE 3306

VOLUME ["${MARIADB_DATA_DIR}"]

ENTRYPOINT ["/docker-entrypoint.sh"]
