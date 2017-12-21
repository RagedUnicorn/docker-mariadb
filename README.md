# docker-mariadb

> A docker base to build a container for MariaDB based on Alpine-Linux

This container is intended to build a base for providing a database to an application stack.

### Using the image

#### Start container

The container can be easily started with `docker-compose` command.

Note that the container itself won't be very useful by itself. The default port `3306` is only
exposed to linked containers. Meaning a connection with a client to the database is not possible with the default configuration.

```
docker-compose up -d
```

#### Stop container

To stop all services from the docker-compose file

```
docker-compose down
```

### Creating a stack

To create a stack the specific `docker-compose.stack.yml` file can be used. It requires that you already built the image that is consumed by the stack or that it is available in a reachable docker repository.

```
docker-compose build --no-cache
```

**Note:** You will get a warning that external secrets are not supported by docker-compose if you try to use this file with docker-compose.

#### Join a swarm

```
docker swarm init
```

#### Create secrets
```
echo "some_password" | docker secret create com.ragedunicorn.mariadb.root_password -
echo "app_user" | docker secret create com.ragedunicorn.mariadb.app_user -
echo "app_user_password" | docker secret create com.ragedunicorn.mariadb.app_user_password -
```

#### Deploy stack
```
docker stack deploy --compose-file=docker-compose.stack.yml [stackname]
```

For a production deployment a stack should be deployed. The secret will then be taken into account and MariaDB will be setup accordingly.

## Dockery

In the dockery folder are some scripts that help out avoiding retyping long docker commands but are mostly intended for playing around with the container. For production use docker-compose or docker stack should be used.

#### Build Image

The build script builds a container with a defined name

```
sh dockery/dbuild.sh
```

#### Run container

Runs the built container. If the container was already run once it will `docker start` the already present container instead of using `docker run`

```
sh dockery/drun.sh
```

#### Attach container

Attaching to the container after it is running

```
sh dockery/dattach.sh
```

#### Stop container

Stopping the running container

```
sh dockery/dstop.sh
```

## Configuration

Most of the configuration can be changed with the `my.cnf` and `mysqld_charset.cnf`configuration files. Both of those files are copied into the container on buildtime. After a change to one of those files the container must be rebuilt.

#### Default user

First time starting up the container a user based on the values of `MARIADB_APP_USER` and `MARIADB_APP_PASSWORD` environmental values is created. This user is also allowed to make external connections and can be used by other services to interact with the database. To modify the setup of this users have a look into `conf/user.sql`.

## Healthcheck

The production and the stack image supports a simple healthcheck whether the container is healthy or not. This can be configured inside `docker-compose.yml` or `docker-compose.stack.yml`

## Development

To debug the container and get more insight into the container use the `docker-compose-dev.yml`
coniguration. This will also allow external clients to connect to the database. By default the port `3306` will be publicly exposed.

```
docker-compose -f docker-compose-dev.yml up -d
```

By default the launchscript `/docker-entrypoint.sh` will not be used to start the MariaDB process. Instead the container will be setup to keep `stdin_open` open and allocating a pseudo `tty`. This allows for connecting to a shell and work on the container. A shell can be opened inside the container with `docker attach [container-id]`. MariaDB itself can be started with `./docker-entrypoint.sh`.

## Links

Alpine Linux packages database
- https://pkgs.alpinelinux.org/packages

## License

Copyright (c) 2017 Michael Wiesendanger

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
