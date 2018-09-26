# Cacti

An all-in-one implementation of the Cacti (https://www.cacti.net) network monitoring and graphing system, built on Alpine Linux (https://alpinelinux.org/). This Docker image aims to provide a highly fault-tolerant and self-recovering instance of Cacti, while reducing the required steps to becoming operational. It includes the Spine poller, configured and operational. And it contains all the components needed to run Cacti, including PHP, MySQL/MariaDB, Apache 2, dependent packages, and some management scripts.

I've decided to focus this image on the unRAID server platform.  Due to the local hardware-specific goals of this image, it doesn't make sense to configure it for general usage. I'll build a generally applicable image in the near future, which won't be as rigid in some configurations.

## This image is not yet mature

I'm still refining, updating and adding features to this image, and may update it in ways that cause loss of data. Make sure your data and backups are being written to persistent storage, if you want to use the image reliably.

## Versions

Not sure yet how I want to handle versioning.  Right now, I'm just pinning a point across currently available versions, keeping increments small for now. Probably will maintain "latest" and two past versions at most, depending on how fast Cacti revs. 

* latest - Runs the latest Cacti and Spine versions on the latest Alpine Linux, as of the image build time.
* 0.0.1 - Runs Cacti and Spine 1.1.38 on Alpine Linux 3.8, fully updated as of the image build time.

## Usage

### My setup

The command below is how I run this Cacti container.  It sets up all of the configuration and data folders in one place on my persistent storage.  I'm running this on my unRAID server, which keeps persistent data on the unRAID cache disk (/mnt/cache).

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
-v '/mnt/cache/appdata/Cacti/logs':'/var/log':'rw' \
-e UNRAID_HOST='<unraid hostname or ip address>'
-e TZ="America/Los_Angeles" \
-e MYSQL='<mysql_root_password>' \
--name Cacti \
chestersgarage/cacti:latest

```

### Let's break it down

Run as a Daemon, i.e. Disconnect from the container after starting, and ReMove the container when stopped.

```
docker run -d --rm \

```


Bridging the network means this container is bound to the IP address of the host computer, not on its own IP address.

```
--net='bridge' \

```


The bridged network connection maps TCP port 80 from the container and exposes it at port 1984 on the host IP.

```
-p 1984:80/tcp \

```


These are all the various places we might need to keep or control data and configurations outside of the container. You don't need to mount all of these volumes in your implementation. The image will install the default configurations anywhere you do not provide your own data. But only the volumes you create here will maintain persistent data. Make sure you at least mount /var/lib/mysql, /var/lib/cacti/rra, /var/log and /var/backups.

```
-v '/mnt/cache/appdata/Cacti/backups':'/var/backups':'rw' \
-v '/mnt/cache/appdata/Cacti/mysql-data':'/var/lib/mysql':'rw' \
-v '/mnt/cache/appdata/Cacti/mysql-conf':'/etc/mysql':'rw' \
-v '/mnt/cache/appdata/Cacti/cacti-data':'/var/lib/cacti/rra':'rw' \
-v '/mnt/cache/appdata/Cacti/apache-conf':'/etc/apache2':'rw' \
-v '/mnt/cache/appdata/Cacti/php-conf':'/etc/php7':'rw' \
-v '/mnt/cache/appdata/Cacti/logs':'/var/log':'rw' \

```


Some variables we need for Cacti to set up all the default graphs:

```
-e UNRAID_HOST='<unraid hostname or ip address>'
-e 

```


Set your time zone or suffer the frustration of your graphs' data being in weird places, and backups starting at the wrong time.
See the "TZ\*" column here: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones

```
-e TZ="America/Los_Angeles" \

```


The controversial part!  Feed in your MySQL root password here. In a future version of this image, I will add other, more secure ways to feed in passwords.

The first time the container starts up on new/default data, this variable sets the MySQL root password. On subsequent starts against that data, this variable must match the existing MySQL root password in order for the container to start successfully.  If the root password does not match, the container will tell you and exit early.  Restoring from a backup will require you to provide the root password for the restored databases, immediately upon completion.


```
-e MYSQL='<mysql root password>' \

```


It's a Cacti container, so I figured we could call it that.

```
--name Cacti \

```


See the versioning section at the top of this document for details. For the purpose of demonstration, we're using the "latest" version.

```
chestersgarage/cacti:latest

```

### Backup schedule

Set the backup schedule with CRON_PATTERN (https://linux.die.net/man/5/crontab)

Make sure your TZ variable is set correctly, too. Cron runs in local time.

If you do not specify, the default is every hour, at 2 minutes past the hour.

```
-e CRON_PATTERN="2 * * * *"

``` 

Run at 3:15 AM every day.

```
-e CRON_PATTERN="15 3 * * *"

```

The backup file name contains the day of the week, hour and minute, creating a rolling hourly 7 day backup archive. Any backup you make manually will also have the same w-hh-mm time stamp in the file name.

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

If you need to restore from a backup, place the backup file in the folder mounted as /var/backups inside the container. Then run the restore command with the file name as an argument. Do not include the directory path when specifying the file name.

```
docker exec cacti /restore <file-name>

```

Once the restore completes, you must terminate the cacti container, and re-run it. 

Make sure you set the MySQL root password correctly after restoring from backup.

## Migrating between Cacti instances

If you want to migrate (or just copy for testing) from another Cacti installation, start the container fresh, then dump ONLY the cacti database from your old installation, and package up the cacti RRD files. Then stuff it all into the new container.  It is safe to run more than one Cacti container at a time, provided you specify non-conflicting settings in each container's startup command.

Perform the migration between polling periods or disable polling to avoid the poller running while you are in the process of migrating.

* On the source installation...
* Open a console to the container.
* Dump out a backup of the necessary data:

```
mysqldump -uroot -p<mysql_root_password> cacti > /var/backups/cacti-mysql-data.sql
cd /path/to/cacti/rra/
tar -zcvf /var/backups/cacti-rrd-data.tgz *

```

* Copy the files from the source to the target installation.
* On the target installation...
* Run a fresh container.
* Run through the Cacti startup wizard.
* Open a console to the container:

```
docker exec -it cacti /bin/bash

```

* Ingest the data from the source installation:

```
mysql -uroot -p<mysql_root_password> < /var/backups/cacti-mysql-data.sql
cd /path/to/cacti/rra/
tar -zxvf /var/backups/cacti-rrd-data.tgz

```

* Restart the target container, just to be sure everything starts up clean.
* Rebuild the Poller, Resource and SNMPAgent caches in order to get data. It takes a while for data to start populating again.  In my testing, it would miss at least a couple polls, sometimes three or four, before it starts logging data again.

## To-Do

* Integrate with unRAID Docker implementation
* Provide for more secure injection or retrieval of passwords
* Add LetsEncrypt SSL support
* Try to verify the container supports distributed and large-scale implementations.
