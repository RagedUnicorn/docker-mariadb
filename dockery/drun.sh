#!/bin/bash
# @author Michael Wiesendanger <michael.wiesendanger@gmail.com>
# @description run script for docker-mariadb container

# abort when trying to use unset variable
set -o nounset

# variable setup
DOCKER_MARIADB_TAG="com.ragedunicorn/mariadb"
DOCKER_MARIADB_NAME="mariadb"
DOCKER_MARIADB_DATA_VOLUME="mariadb_data"
DOCKER_MARIADB_ID=0

# get absolute path to script and change context to script folder
SCRIPTPATH="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
cd "${SCRIPTPATH}"

# check if there is already an image created
docker inspect ${DOCKER_MARIADB_NAME} &> /dev/null

if [ $? -eq 0 ]; then
  # start container
  docker start "${DOCKER_MARIADB_NAME}"
else
  ## run image:
  # -v mount volume
  # -d run in detached mode
  # --name define a name for the container(optional)
  DOCKER_MARIADB_ID=$(docker run \
  -v ${DOCKER_MARIADB_DATA_VOLUME}:/var/lib/mysql \
  -d \
  --name "${DOCKER_MARIADB_NAME}" "${DOCKER_MARIADB_TAG}")
fi

if [ $? -eq 0 ]; then
  # print some info about containers
  echo "$(date) [INFO]: Container info:"
  docker inspect -f '{{ .Config.Hostname }} {{ .Name }} {{ .Config.Image }} {{ .NetworkSettings.IPAddress }}' ${DOCKER_MARIADB_NAME}
else
  echo "$(date) [ERROR]: Failed to start container - ${DOCKER_MARIADB_NAME}"
fi
