# Cacti

An implementation of the Cacti (https://www.cacti.net) network monitoring and graphing system, built on Alpine Linux (https://alpinelinux.org/). This Docker image aims to provide a highly fault-tolerant and self-recovering instance of Cacti, while reducing the required steps to becoming operational. It includes the Spine poller, configured and operational. And it contains all the components needed to run Cacti, including PHP, MySQL/MariaDB, Apache 2, dependent packages, and some management scripts.

## Usage

### My setup

This is how I run this cacti container.  It sets up all of the configuration and data folders in one place.  I'm runing this on my unRAID server, which keeps persistent data on the unRAID cache disk (/mnt/cache).  

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


### Lets break it down

Run as a daemon, i.e. disconnect from the container after starting, and destroy the container when stopped.

```
docker run -d --rm \

```


Bridging the network means this service is bound to the IP address of the host computer, not on its own IP address.

```
--net='bridge' \

```


The bridged network connection maps port 80 from the container and exposes it at port 1984 on the host IP.

```
-p 1984:80/tcp \

```


These are all the various places we might need to keep or control the data and configurations outside of the container. You don't need to mount all these volumes in your implementation.  The image will install the default configurations anywhere you do not provide your own data.

```
-v '/mnt/cache/appdata/cacti/backups':'/var/backups':'rw' \
-v '/mnt/cache/appdata/cacti/mysql-data':'/var/lib/mysql':'rw' \
-v '/mnt/cache/appdata/cacti/mysql-conf':'/etc/mysql':'rw' \
-v '/mnt/cache/appdata/cacti/cacti-data':'/var/lib/cacti/rra':'rw' \
-v '/mnt/cache/appdata/cacti/apache-conf':'/etc/apache2':'rw' \
-v '/mnt/cache/appdata/cacti/php-conf':'/etc/php7':'rw' \

```


Set your time zone or suffer the frustration of your graphs' data being in weird places.
See the "TZ" column here: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones

```
-e TZ="America/Los_Angeles" \

```


The controversial part!  Feed in your passwords here. In a future version of this image, I will add other, more secure ways to feed in passwords.

```
-e MYSQL='<mysql root password>' \
-e CACTI='<cacti user db password>' \

```


It's a cacti container, so I figured we could call it that.

```
--name Cacti \

```


I built this container on alpine:latest, and so far, I've only published a "latest" tag for this image. Every time it starts, it will come on line with the latest version of everything used to build the application. I'll start versioning the containers in future updates, before I call it usable by people other than myself.

```
chestersgarage/cacti:latest

```

### Backup schedule

Set the backup schedule with CRON_PATTERN (https://linux.die.net/man/5/crontab)

Make sure your TZ variable is set correctly, too. Cron runs in local time.

The default is every hour, 2 minutes past the hour. The backup file name contains the hour and minute, creating a rolling 24-hour backup archive. Any backup you make manually will also have the same hh-mm time stamp.
```
-e CRON_PATTERN="2 * * * *"

``` 

Run at 2:15 AM every day.
```
-e CRON_PATTERN="15 2 * * *"

```

## Interacting

### Accessing Cacti

* The container takes at least 20 seconds to start up.
* Browse to ...

```
http://<your_docker_host>:1984/cacti

```


* Follow the installation wizard.
* Log in and set your admin password. Default: admin/admin
* Navigate to Console -> Configuration -> Settings -> Paths
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
docker exec -it cacti /bin/bash

```

## Migrating between Cacti instances

If you want to migrate (or just copy for testing) from another Cacti installation, start the container fresh, then dump ONLY the cacti database from your old installation, and package up the cacti RRD files. Then stuff it all into the new container.  It is safe to run more than one Cacti container at a time, provided you specify non-conflicting settings in each container.

Do this between polling periods or disable polling to avoid the poller running while you are in the process of migrating.

* On the source installation...
* Open a console to the container, if applicable.
* Dump out a backup of the necessary data:

```
mysqldump -uroot -pmysql_root_password cacti > /var/backups/cacti-mysql-data.sql
cd /path/to/cacti/rra/
tar -zcvf /var/backups/cacti-rrd-data.tgz *

```

* Copy the files from the source to the target installation.
* On the target installation...
* Start with a fresh container.
* Run through the Cacti startup wizard.
* Open a console to the container:

```
docker exec -it cacti /bin/bash

```

* Ingest the data from the source installation:

```
mysql -uroot -p${MYSQL} < /var/backups/cacti-mysql-data.sql
cd /path/to/cacti/rra/
tar -zxvf /var/backups/cacti-rrd-data.tgz

```

* Restart the target container, just to be sure everything starts up clean.
* Rebuild the Poller, Resource and SNMPAgent caches in order to get data. It takes a while for data to start populating again.  In my testing, it would miss at least a couple polls, sometimes three or four, before it starts logging data again.
* Voila!

## To-Do

* Integrate with unRAID Docker implementation
* Provide for more secure injection or retrieval of passwords
* Add LetsEncrypt SSL support
* Try to verify the container supports distributed and large-scale implementations.
* Make detection of existing configs move anything old/exiting to a separate folder before copying in the defaults.
