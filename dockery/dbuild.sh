#!/bin/bash
# @author Michael Wiesendanger <michael.wiesendanger@gmail.com>
# @description build script for docker-mariadb container

# abort when trying to use unset variable
set -o nounset

# variable setup
DOCKER_MARIADB_TAG="ragedunicorn/mariadb"
DOCKER_MARIADB_NAME="mariadb"
DOCKER_MARIADB_DATA_VOLUME="mariadb_data"

WD="${PWD}"

# get absolute path to script and change context to script folder
SCRIPTPATH="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
cd "${SCRIPTPATH}"

echo "$(date) [INFO]: Building container: ${DOCKER_MARIADB_NAME}"

# build mariadb container
docker build -t "${DOCKER_MARIADB_TAG}" ../

# check if mariadb data volume already exists
docker volume inspect "${DOCKER_MARIADB_DATA_VOLUME}" > /dev/null 2>&1

if [ $? -eq 0 ]; then
  echo "$(date) [INFO]: Reusing existing volume: ${DOCKER_MARIADB_DATA_VOLUME}"
else
  echo "$(date) [INFO]: Creating new volume: ${DOCKER_MARIADB_DATA_VOLUME}"
  docker volume create --name "${DOCKER_MARIADB_DATA_VOLUME}" > /dev/null
fi

cd "${WD}"
