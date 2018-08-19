# cacti

A containerized implementation of the well-known cacti network monitoring and graphing system. This container aims to provide a highly tolerant and self-recovering instance of cacti, while reducing the required steps to becoming operational. It includes the Spine poller, configured and operational. And it contains all the components needed to run cacti, including PHP, MySQL/MariaDB, Apache 2, and all dependent packages.

## Usage

### My Setup

This is how I run this cacti container.  It sets up all of the configuration and data folders in one place.  And it launches with the --rm option to remove the container when it's stopped.  This assures the self-recovery features a kept up to date.  (I know it's controversial to provide passwords on the command line, but that's how it staying for the near future, at least.  Later, I'll add decryption and/or file injection.)

> docker run -d --rm \
> --net='bridge' \
> -p 1984:80/tcp \
> -v '/mnt/cache/appdata/cacti/backups':'/var/backups':'rw' \
> -v '/mnt/cache/appdata/cacti/mysql-data':'/var/lib/mysql':'rw' \
> -v '/mnt/cache/appdata/cacti/mysql-conf':'/etc/mysql':'rw' \
> -v '/mnt/cache/appdata/cacti/cacti-data':'/var/lib/cacti/rra':'rw' \
> -v '/mnt/cache/appdata/cacti/apache-conf':'/etc/apache2':'rw' \
> -v '/mnt/cache/appdata/cacti/php-conf':'/etc/php7':'rw' \
> -e TZ="America/Los_Angeles" \
> -e MYSQL='<mysql root password>' \
> -e CACTI='<cacti user db password>' \
> --name cacti \
> chestersgarage/cacti:latest

### Lets break it down...

> docker run -d --rm \

We're going to run as a daemon and disappear wen stopped.

> --net='bridge' \

Bridging the network means this service is bound to the IP address of the host computer, not on its own IP address.

> -p 1984:80/tcp \

That bridged connection comes from port 80 in the container and is exposed at port 1984 on the host IP.

> -v '/mnt/cache/appdata/cacti/backups':'/var/backups':'rw' \
> -v '/mnt/cache/appdata/cacti/mysql-data':'/var/lib/mysql':'rw' \
> -v '/mnt/cache/appdata/cacti/mysql-conf':'/etc/mysql':'rw' \
> -v '/mnt/cache/appdata/cacti/cacti-data':'/var/lib/cacti/rra':'rw' \
> -v '/mnt/cache/appdata/cacti/apache-conf':'/etc/apache2':'rw' \
> -v '/mnt/cache/appdata/cacti/php-conf':'/etc/php7':'rw' \

These are all the various places we might need to keep or control the data and configurations outside of the container.

> -e TZ="America/Los_Angeles" \

Time zone! Set your time zone or suffer the frustration of you graphs' data being in weird places.

> -e MYSQL='<mysql root password>' \
> -e CACTI='<cacti user db password>' \

The controlversial part!  Feed in your passwords here.

> --name cacti \

It's a cacti container, so I figured we could call it that.

> chestersgarage/cacti:latest

I built this container on alpine:latest, so every time it starts, it will come on line with the latest version of everything used to build the application.  

### Interacting

#### Accessing cacti

Browse to ...

> http://<your_docker_host>:1984/cacti

#### Get a shell

> docker exec -it cacti /bin/sh

That's pretty much it for now