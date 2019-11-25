# Docker Commands

This document highlights some important docker commands. Find more on it in the [Docker Documentation]().

## Docker Core

### Show Log

Shows the log of a single container

```
docker logs -f <container-name>
```

### Stopping a container

To stop a container, run the following command

```
docker stop <container-name>
```

The container is only stopped, but will still be around and could be started again. You can use `docker ps -a` to view also containers, which are stopped.

### Running a command inside a running container

To run a command in a running container

```
docker exec -ti <container-name> bash
```

### Remove all unused local volumes

```
docker volume prune
```

### Stop all running containers

```
docker volume prune
```


## Docker Compose

### Start a Docker Compose stack from Scratch

The following command starts the docker compose stack in the background (option `d`), which is recommended. You have to be in the folder where the `docker-compose.yml` is located.

```
docker-compose up -d
```

If your docker-compose file has another name, you can add the `-f` flag

```
docker-compose -f <docker-compose-filename> up -d
```

### Stop a Docker Compose stack

For stopping the containers of the stack

```
docker-compose stop
```

After that, the containers are in stopped state and can be restarted. If you want to get rid of them, you have to remove them. 

### Starting a Docker Compose stack in Stopped State

```
docker-compose start
```

### Stop and Remove the Stack

```
docker-compose down
```

### Showing Log Files of the Stack

To get the logs for all of the services running inside the docker compose environment, perform

```
docker-compose logs -f
```

if you only want to see the logs for one of the services, say of `connect-1`, perform


```
docker-compose logs -f connect-1
```

To see the log of multiple services, just list them as shown below

```
docker-compose logs -f connect-1 connect-2
```

