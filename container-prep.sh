#!/bin/sh -x

# Set MySQL root password
CACTI=${CACTI:-$(base64 /dev/urandom | tr -dc 'a-zA-Z-09' | fold -w 27 | head -n1)}
echo "cactu db user pw - ${CACTI}"
echo "mysql root pw - ${MYSQL}"

# Check for existing configs, and
# copy in any that are missing or unrecognized
BACKUPDIR="/root/default-configs"

# Look for the main httpd.conf because 
# if it's missing, the rest doesn't matter
if [[ ! -f /etc/apache2/httpd.conf ]]
then
	SERVERFQDN=$(hostname)
	echo "ServerName ${SERVERFQDN}" > /root/default-configs/apache/conf.d/fqdn.conf
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

# Checking for the presence of a cacti data base folder in the mysql data
# Again, no cacti means this is a fresh installation
# and initialize MySQL/MariaDB
DBHOST=$(hostname)
if [[ ! -d /var/lib/mysql/cacti ]]
then
	/etc/init.d/mariadb setup
	nohup /usr/bin/mysqld_safe --datadir="/var/lib/mysql" &
	sleep 3
	mysqladmin -u root password ${MYSQL}
	mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root -p${MYSQL} mysql
	echo 'default-time-zone = '$TZ >> /etc/mysql/my.cnf
	mysqladmin -u root -p${MYSQL} reload
	mysqladmin -u root -p${MYSQL} create cacti
	echo "GRANT ALL ON cacti.* TO cactiuser@${DBHOST} IDENTIFIED BY '${CACTI}'; flush privileges; " | mysql -u root -p${MYSQL}
	echo "GRANT SELECT ON mysql.time_zone_name TO cactiuser@${DBHOST} IDENTIFIED BY '${CACTI}'; flush privileges; " | mysql -u root -p${MYSQL}
	mysql -u root -p${MYSQL} cacti < /usr/share/webapps/cacti/cacti.sql
	mysqladmin -u root -p${MYSQL} shutdown
else
	nohup /usr/bin/mysqld_safe --datadir="/var/lib/mysql" &
	sleep 3
	echo "GRANT ALL ON cacti.* TO cactiuser@${DBHOST} IDENTIFIED BY '${CACTI}'; flush privileges; " | mysql -u root -p${MYSQL}
	mysqladmin -u root -p${MYSQL} shutdown
fi

# Set the spine.conf with current info
cat > /usr/local/spine/bin/spine.conf <<EOF
DB_Host ${DBHOST}
DB_Database cacti
DB_User cactiuser
DB_Pass ${CACTI}
DB_Port 3306
EOF

# These don't work, but I'm keeping them here as a reminder to figure out a way to make them work.
# The problem is these are set prior to cacti's first-run process, which overwrites them.
#echo "INSERT INTO cacti.settings VALUES ("path_spine","/usr/local/spine/bin/spine");" | mysql -uroot -p${MYSQL}
#echo "INSERT INTO cacti.settings VALUES ("path_spine_config","/usr/local/spine/bin/spine.conf");" | mysql -uroot -p${MYSQL}
#echo "UPDATE cacti.settings SET value = "2" WHERE settings.name = 'poller_type';" | mysql -uroot -p${MYSQL}

sed -i "s/database_hostname = 'localhost'/database_hostname = '${DBHOST}'/" /usr/share/webapps/cacti/include/config.php
sed -i "s/database_password = 'cactiuser'/database_password = '${CACTI}'/" /usr/share/webapps/cacti/include/config.php

echo "alias ll='ls -l'" >> /root/

/init-services.sh