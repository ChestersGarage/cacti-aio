#!/bin/sh -x

# Set cacti database user's password
# If you don't provide one, we'll set it for you by grabbing some random data (27 alpha-numeric chars of it)
CACTI=${CACTI:-$(base64 /dev/urandom | tr -dc 'a-zA-Z-09' | fold -w 27 | head -n1)}
echo "Cacti db user pw - ${CACTI}"
echo "MySQL root pw - ${MYSQL}"

# Check for existing configs, and
# copy in any that are missing, mal-formed or unrecognized
# IMPORTANT: If you provide broken configs, we may overwrite them with defaults.
BACKUPDIR="/root/default-configs"

# It's who we are
# And that's used a lot later
CONTAINERFQDN=$(hostname)

# Look for the main httpd.conf because 
# if it's missing, the rest doesn't matter
if [[ ! -f /etc/apache2/httpd.conf ]]
then
	echo "ServerName ${CONTAINERFQDN}" > /root/default-configs/apache/conf.d/fqdn.conf
	cp -rpf ${BACKUPDIR}/apache/* /etc/apache2/
fi

# Same for PHP as Apache above.
# Just look for the key config file.
if [[ ! -f /etc/php7/php.ini ]]
then
	sed -i "s|\;date.timezone =|date.timezone = \"${TZ}\"|" /root/default-configs/php7/php.ini
	cp -rpf ${BACKUPDIR}/php7/* /etc/php7/
fi

# MySQL only has one config file
if [[ ! -f /etc/mysql/my.cnf ]]
then
	cat > /etc/mysql/my.cnf <<EOF
[mysqld]
collation_server = utf8mb4_unicode_ci
character_set_server = utf8mb4
max_heap_table_size = 1024M
max_allowed_packet = 16M
tmp_table_size = 128M
join_buffer_size = 128M
innodb_buffer_pool_size = 4096M
innodb_doublewrite = OFF
innodb_flush_log_at_timeout = 10
innodb_read_io_threads = 32
innodb_write_io_threads = 16
EOF
fi

# Checking for the presence of a cacti database folder in the mysql data
# Again, no cacti means this is a fresh installation
# and initialize MySQL/MariaDB.
# Everything else will be overwritten or ignored.
if [[ ! -d /var/lib/mysql/cacti ]]
then
	# Start from fresh
	# Initialize the database
	/etc/init.d/mariadb setup
	# Start MySQL/MariaDB
	nohup /usr/bin/mysqld_safe --datadir="/var/lib/mysql" &
	sleep 3
	# Set the MySQL root password
	mysqladmin -u root password ${MYSQL}
	# Ingest timezone data from the O/S
	mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root -p${MYSQL} mysql
	# Set the current timezone for MySQL 
	echo 'default-time-zone = '$TZ >> /etc/mysql/my.cnf
	# Refresh the running MySQL server
	mysqladmin -u root -p${MYSQL} reload
	# Create the cacti databse
	mysqladmin -u root -p${MYSQL} create cacti
	# Set up cacti application access to the database
	# Every time the container starts, this gets set. You could end up with a lot if you don't use the same one each time.
	echo "GRANT ALL ON cacti.* TO cactiuser@${CONTAINERFQDN} IDENTIFIED BY '${CACTI}';" | mysql -uroot -p${MYSQL}
	echo "GRANT SELECT ON mysql.time_zone_name TO cactiuser@${CONTAINERFQDN} IDENTIFIED BY '${CACTI}';" | mysql -uroot -p${MYSQL}
	#echo "GRANT ALL ON cacti.* TO cactiuser@localhost IDENTIFIED BY '${CACTI}';" | mysql -u root -p${MYSQL}
	#echo "GRANT SELECT ON mysql.time_zone_name TO cactiuser@localhost IDENTIFIED BY '${CACTI}'; flush privileges;" | mysql -u root -p${MYSQL}
	# Ingest the cacti initialization script
	mysql -uroot -p${MYSQL} cacti < /usr/share/webapps/cacti/cacti.sql
	# Must make sure MySQL isn't running before we transition to service startup.
	mysqladmin -uroot -p${MYSQL} shutdown
else
	# Existing data to use and become.
	# First, make sure authgentication and access are cleaned up
	nohup /usr/bin/mysqld_safe --skip-grant-tables &
	sleep 3
	echo "UPDATE mysql.user SET plugin = 'mysql_native_password' WHERE user = 'root'; flush privileges;" | mysql -uroot
	echo "UPDATE mysql.user SET plugin = 'mysql_native_password' WHERE user = 'cacti'; flush privileges;" | mysql -uroot
	echo "UPDATE mysql.user SET password=PASSWORD(\"${MYSQL}\") WHERE User='root';" | mysql -uroot

	#nohup /usr/bin/mysqld_safe --datadir="/var/lib/mysql" &
	#sleep 3

	# As mentioned above, use the same one, or you'll end up with a lot.
	# Feel free to clean out old ones externally.
	echo "GRANT ALL ON cacti.* TO cactiuser@${CONTAINERFQDN} IDENTIFIED BY '${CACTI}'; flush privileges; " | mysql -uroot
	echo "GRANT SELECT ON mysql.time_zone_name TO cactiuser@${CONTAINERFQDN} IDENTIFIED BY '${CACTI}'; flush privileges; " | mysql -uroot
	#echo "GRANT ALL ON cacti.* TO cactiuser@localhost IDENTIFIED BY '${CACTI}'; flush privileges; " | mysql -u root -p${MYSQL}
	#echo "GRANT SELECT ON mysql.time_zone_name TO cactiuser@localhost IDENTIFIED BY '${CACTI}'; flush privileges; " | mysql -u root -p${MYSQL}
	# Must make sure MySQL isn't running before we transition to service startup.
	mysqladmin -uroot shutdown
fi

# Set the spine.conf with current info
# The docs say to use DB_Password, but actually DB_Pass is correct.
cat > /usr/local/spine/bin/spine.conf <<EOF
DB_Host ${CONTAINERFQDN}
DB_Database cacti
DB_User cactiuser
DB_Pass ${CACTI}
DB_Port 3306
EOF

# These don't work, but I'm keeping them here as a reminder to figure out a way to make them work.
# The problem is these are set prior to cacti's first-run process, which overwrites them.
# I could force these in a cron job, but it would lock out recovery other than killing the container.
#echo "INSERT INTO cacti.settings VALUES ("path_spine","/usr/local/spine/bin/spine");" | mysql -uroot -p${MYSQL}
#echo "INSERT INTO cacti.settings VALUES ("path_spine_config","/usr/local/spine/bin/spine.conf");" | mysql -uroot -p${MYSQL}
#echo "UPDATE cacti.settings SET value = "2" WHERE settings.name = 'poller_type';" | mysql -uroot -p${MYSQL}

# Set the DB info for cacti.
# Many characters can disrupt this.
# Avoid & and ! and possibly others in passwords.
sed -i "s/database_hostname = 'localhost'/database_hostname = '${CONTAINERFQDN}'/" /usr/share/webapps/cacti/include/config.php
sed -i "s/database_password = 'cactiuser'/database_password = '${CACTI}'/" /usr/share/webapps/cacti/include/config.php

# I use ll all the time.
echo "alias ll='ls -l'" >> /root/.bashrc

# This gets reset to root:root for some reason, so I set it back.
# Probably caused by host permissions. (to-do)
chown -R cacti:cacti /var/lib/cacti/rra
chown -R mysql:mysql /var/lib/mysql

# Now start all the services.
/init-services.sh