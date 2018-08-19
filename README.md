# cacti

A containerized implementation of the well-known cacti network monitoring and graphing system. This image aims to provide a highly tolerant and self-recovering instance of cacti, while reducing the required steps to becoming operational. It includes the Spine poller, configured and operational. And it contains all the components needed to run cacti, including PHP, MySQL/MariaDB, Apache 2, and all dependent packages.

## Usage

### My Setup

This is how I run this cacti container.  It sets up all of the configuration and data folders in one place.  And it launches with the "--rm" option to remove the container when it's stopped.

```
docker run -d --rm \
--net='bridge' \
-p 1984:80/tcp \
-v '/mnt/cache/appdata/cacti/backups':'/var/backups':'rw' \
-v '/mnt/cache/appdata/cacti/mysql-data':'/var/lib/mysql':'rw' \
-v '/mnt/cache/appdata/cacti/mysql-conf':'/etc/mysql':'rw' \
-v '/mnt/cache/appdata/cacti/cacti-data':'/var/lib/cacti/rra':'rw' \
-v '/mnt/cache/appdata/cacti/apache-conf':'/etc/apache2':'rw' \
-v '/mnt/cache/appdata/cacti/php-conf':'/etc/php7':'rw' \
-e TZ="America/Los_Angeles" \
-e MYSQL='\<mysql root password\>' \
-e CACTI='\<cacti user db password\>' \
--name cacti \
chestersgarage/cacti:latest
```


### Lets break it down...

We're going to run as a daemon and disappear when stopped.

```
docker run -d --rm \
```


Bridging the network means this service is bound to the IP address of the host computer, not on its own IP address.

```
--net='bridge' \
```


That bridged connection comes from port 80 in the container and is exposed at port 1984 on the host IP.

```
-p 1984:80/tcp \
```


These are all the various places we might need to keep or control the data and configurations outside of the container.

```
-v '/mnt/cache/appdata/cacti/backups':'/var/backups':'rw' \
-v '/mnt/cache/appdata/cacti/mysql-data':'/var/lib/mysql':'rw' \
-v '/mnt/cache/appdata/cacti/mysql-conf':'/etc/mysql':'rw' \
-v '/mnt/cache/appdata/cacti/cacti-data':'/var/lib/cacti/rra':'rw' \
-v '/mnt/cache/appdata/cacti/apache-conf':'/etc/apache2':'rw' \
-v '/mnt/cache/appdata/cacti/php-conf':'/etc/php7':'rw' \
```


Time zone! Set your time zone or suffer the frustration of you graphs' data being in weird places.

```
-e TZ="America/Los_Angeles" \
```


The controversial part!  Feed in your passwords here.

```
-e MYSQL='\<mysql root password\>' \
-e CACTI='\<cacti user db password\>' \
```


It's a cacti container, so I figured we could call it that.

```
--name cacti \
```


I built this container on alpine:latest, so every time it starts, it will come on line with the latest version of everything used to build the application. I'll start versioning the containers in future updates (before I call it usable by people other than me).

```
chestersgarage/cacti:latest
```


## Interacting

### Accessing cacti

* The container takes a good 15-20 seconds to start up.
* Browse to ...

```
http://<your_docker_host>:1984/cacti
```


* Follow the installation wizard.
* Log in and set your admin password. Default: admin/admin
* Go into Console -> Configuration -> Settings -> Paths
* Set the Spine Config File Path

```
/usr/local/spine/bin/spine.conf
```


* Save
* Click the Poller tab
* Change the Poller Type to spine
* Set the Maximum Threads per Process, if desired
* Save
* Go to Utilities -> System Utilities
* Run each of Rebuild Poller Cache, Rebuild Resource Cache, Rebuild SNMPAgent Cache
* Give it at least 10 minutes to start showing data.

### Getting a shell

```
docker exec -it cacti /bin/sh
```
