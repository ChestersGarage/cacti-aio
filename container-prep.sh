#!/bin/sh

# Check for existing configs, and
# copy in any that are missing or unrecognized
BACKUPDIR="/root/default-configs"

if [[ ! -f /etc/apache2/httpd.conf ]]
then
	SERVERFQDN=$(hostname)
	echo "ServerName ${SERVERFQDN}" | tee /root/default-configs/apache/conf.d/fqdn.conf
	cp -rpf ${BACKUPDIR}/apache/* /etc/apache2/
fi

if [[ ! -f /etc/php7/php.ini ]]
then
	sed -i "s|\;date.timezone =|date.timezone = \"${TZ}\"|" /root/default-configs/php7/php.ini
	cp -rpf ${BACKUPDIR}/php7/* /etc/php7/
fi

if [[ ! -f /etc/mysql/my.cnf ]]
then
	cp -pf ${BACKUPDIR}/mysql/my.cnf /etc/mysql/my.cnf
fi

if [[ ! -d /var/lib/mysql/cacti ]]
then
	/etc/init.d/mariadb setup
	nohup /usr/bin/mysqld_safe --datadir="/var/lib/mysql" &
	sleep 3
	mysqladmin -u root password ${MYPW}
	mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root -p${MYPW} mysql
	echo 'default-time-zone = '$TZ >> /etc/mysql/my.cnf
	mysqladmin -u root -p${MYPW} reload
	mysqladmin -u root -p${MYPW} create cacti
	echo "GRANT ALL ON cacti.* TO cactiuser@localhost IDENTIFIED BY 'cactiuser'; flush privileges; " | mysql -u root -p${MYPW}
	echo "GRANT ALL ON cacti.* TO cactiuser@${DBHOST} IDENTIFIED BY 'cactiuser'; flush privileges; " | mysql -u root -p${MYPW}
	echo "GRANT SELECT ON mysql.time_zone_name TO cactiuser@localhost IDENTIFIED BY 'cactiuser'; flush privileges; " | mysql -u root -p${MYPW}
	mysql -u root -p${MYPW} cacti < /usr/share/webapps/cacti/cacti.sql
	mysqladmin -u root -p${MYPW} shutdown
fi

