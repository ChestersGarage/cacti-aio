# Cacti

An all-in-one implementation of the Cacti (https://www.cacti.net) network monitoring and graphing system, built on Alpine Linux (https://alpinelinux.org/). This Docker image aims to provide a highly fault-tolerant and self-recovering instance of Cacti, while reducing the required steps to becoming operational. It includes the Spine poller, configured and operational. And it contains all the components needed to run Cacti, including PHP, MySQL/MariaDB, Apache 2, dependent packages, and some management scripts.

## This image is still highly in flux

I'm actively refining, updating and adding major changes to this image, and commonly update it in ways that may cause loss of data.

My current focus is on solidifying the backup and restore processes, so that there is some sort of path that wont lose data through changes.

## Usage

### My setup

This is how I run this Cacti container.  It sets up all of the configuration and data folders in one place.  I'm running this on my unRAID server, which keeps persistent data on the unRAID cache disk (/mnt/cache).  

```
docker run -d --rm \
--net='bridge' \
-p 1984:80/tcp \
-v '/mnt/cache/appdata/Cacti/backups':'/var/backups':'rw' \
-v '/mnt/cache/appdata/Cacti/mysql-data':'/var/lib/mysql':'rw' \
-v '/mnt/cache/appdata/Cacti/mysql-conf':'/etc/mysql':'rw' \
-v '/mnt/cache/appdata/Cacti/cacti-data':'/var/lib/cacti/rra':'rw' \
-v '/mnt/cache/appdata/Cacti/apache-conf':'/etc/apache2':'rw' \
-v '/mnt/cache/appdata/Cacti/php-conf':'/etc/php7':'rw' \
-e TZ="America/Los_Angeles" \
-e MYSQL='<mysql root password>' \
--name Cacti \
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


The bridged network connection maps TCP port 80 from the container and exposes it at port 1984 on the host IP.

```
-p 1984:80/tcp \

```


These are all the various places we might need to keep or control the data and configurations outside of the container. You don't need to mount all these volumes in your implementation. The image will install the default configurations anywhere you do not provide your own data. But only the volumes you create here will maintain persistent data. Make sure you at least mount /var/lib/mysql and /var/lib/cacti/rra.

```
-v '/mnt/cache/appdata/Cacti/backups':'/var/backups':'rw' \
-v '/mnt/cache/appdata/Cacti/mysql-data':'/var/lib/mysql':'rw' \
-v '/mnt/cache/appdata/Cacti/mysql-conf':'/etc/mysql':'rw' \
-v '/mnt/cache/appdata/Cacti/cacti-data':'/var/lib/cacti/rra':'rw' \
-v '/mnt/cache/appdata/Cacti/apache-conf':'/etc/apache2':'rw' \
-v '/mnt/cache/appdata/Cacti/php-conf':'/etc/php7':'rw' \

```


Set your time zone or suffer the frustration of your graphs' data being in weird places, and backups starting at the wrong time.
See the "TZ" column here: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones

```
-e TZ="America/Los_Angeles" \

```


The controversial part!  Feed in your passwords here. In a future version of this image, I will add other, more secure ways to feed in passwords.

UPDATE: You must know and provide the correct MySQL root password now, or the container will fail to start.  I've removed the logic that sets the MySQL root password, as part of my security updates.

```
-e MYSQL='<mysql root password>' \

```


It's a Cacti container, so I figured we could call it that.

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

If you do not specify, the default is every hour, 2 minutes past the hour. The backup file name contains the day of the week, hour and minute, creating a rolling hourly 7 day backup archive. Any backup you make manually will also have the same w-hh-mm time stamp in the file name.

```
-e CRON_PATTERN="2 * * * *"

``` 

Run at 3:15 AM every day.

```
-e CRON_PATTERN="15 3 * * *"

```

## Interacting

### Accessing Cacti

* The container takes about 20 seconds to start up.
* Browse to...

```
http://<your_docker_host>:1984/cacti

```

* Follow the installation wizard.
* Log in and set your admin password. Default: admin/admin
* Navigate to Console -> Configuration -> Settings -> Paths
* Set the Spine Config File Path

```
/usr/local/spine/etc/spine.conf

```

* Save
* Click the Poller tab
* Change the Poller Type to spine
* Set the Maximum Threads per Process, if desired
* Save
* Give it at least 10 minutes to start showing data.

### Getting a shell

```
docker exec -it cacti /bin/bash

```

### Backup and restore

In addition to running regular scheduled backups, you can trigger a full backup at any time with the following. This will write a backup file to /var/backups inside the container.

```
docker exec cacti /backup

```

If you need to restore from a backup, place the backup file in the folder mounted as /var/backups. Then run the restore command with the file name as an argument.

```
docker exec cacti /restore <file-name>

```

Once the restore completes, you must stop and remove the cacti container, and then re-run it.

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
