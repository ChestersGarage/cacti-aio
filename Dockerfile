FROM alpine:latest

RUN /sbin/apk --no-cache upgrade && \
	/sbin/apk --no-cache add apache2 mariadb mariadb-client php7 cacti cacti-php7 vim php7-apache2 net-snmp curl tzdata openrc cacti-setup wget patch gd php7-dom automake libtool autoconf make gawk gcc g++ distcc binutils libressl-dev mysql-dev net-snmp-dev help2man

RUN BACKUPDIR="/root/default-configs" && \
	/bin/mkdir -p ${BACKUPDIR}/mysql && \
	/bin/mv /etc/mysql/my.cnf ${BACKUPDIR}/mysql/ && \
	/bin/mkdir -p ${BACKUPDIR}/apache && \
	/bin/mv /etc/apache2/* ${BACKUPDIR}/apache/ && \
	/bin/mkdir ${BACKUPDIR}/php7 && \
	/bin/mv /etc/php7/* ${BACKUPDIR}/php7/ && \
	/bin/mkdir -p /run/apache2 && \
	/bin/mkdir -p /run/openrc && \
	/bin/mkdir -p /usr/share/webapps/cacti/log && \
	/bin/touch /run/openrc/softlevel && \
	/bin/touch /usr/share/webapps/cacti/log/cacti.log && \
	/bin/mkdir -p /var/lib/spine/src && \
	ln -s /usr/share/webapps/cacti /var/www/localhost/htdocs/cacti && \
	chown -R cacti:cacti /usr/share/webapps/cacti/ && \
	chown -R cacti:cacti /var/lib/cacti && \
	chown -R apache:apache /usr/share/webapps/cacti/cache/ && \
	chown -R apache:apache /usr/share/webapps/cacti/resource/ && \
	chown -R apache:apache /usr/share/webapps/cacti/scripts/ && \
	chown -R apache:apache /var/log/cacti

RUN cd /var/lib/spine/src && \
	/usr/bin/wget http://www.cacti.net/downloads/spine/cacti-spine-latest.tar.gz && \
	ver=$(tar -tf cacti-spine-latest.tar.gz | head -n1 | tr -d /) && \
	/bin/tar -zxvf cacti-spine-latest.tar.gz && \
	cd /var/lib/spine/src/$ver/ && \
	/usr/bin/aclocal && \
	/usr/bin/libtoolize --force && \
	/usr/bin/autoheader && \
	/usr/bin/autoconf && \
	/usr/bin/automake --add-missing && \
	/usr/bin/aclocal && \
	/usr/bin/automake && \
	./configure && \
	/usr/bin/make && \
	/usr/bin/make install && \
	/bin/chown root:root /usr/local/spine/bin/spine && \
	/bin/chmod +s /usr/local/spine/bin/spine

RUN sed -i "s|\$ids = array()\;|\$ids = \'\'\;|" /usr/share/webapps/cacti/lib/utility.php && \
	sed -i "s|if (sizeof(\$ids))|if (strlen(\$ids))|" /usr/share/webapps/cacti/lib/utility.php

RUN DBHOST=$(hostname) && \
/bin/cat > /usr/local/spine/bin/spine.conf <<EOF
DB_Host         ${DBHOST}
DB_Database     cacti
DB_User         cactiuser
DB_Password     cactiuser
DB_Port         3306
EOF
	
RUN cat > /root/default-configs/mysql/my.cnf <<EOF
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


