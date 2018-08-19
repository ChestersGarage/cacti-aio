FROM alpine:latest

# Install all the things we need to do everything.
RUN /sbin/apk --no-cache upgrade && \
	/sbin/apk --no-cache add apache2 mariadb mariadb-client php7 cacti cacti-php7 vim php7-apache2 net-snmp curl tzdata openrc cacti-setup wget patch gd php7-dom automake libtool autoconf make gawk gcc g++ distcc binutils libressl-dev mysql-dev net-snmp-dev help2man

# Move all the default configs into a backup location,
# from where they will be restored later in the container startup process
# Also sets up a few locations, resources and permisions
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

# Download and install spine.
# https://www.cacti.net/downloads/docs/html/unix_configure_spine.html
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

# Get rid of the tools used to build spine. We don't need them any longer.
#RUN /sbin/apk --no-cache del automake libtool autoconf make gawk gcc g++ distcc binutils libressl-dev mysql-dev net-snmp-dev help2man

# Apply a bug fix caused by PHP 7.2
RUN sed -i "s|\$ids = array()\;|\$ids = \'\'\;|" /usr/share/webapps/cacti/lib/utility.php && \
	sed -i "s|if (sizeof(\$ids))|if (strlen(\$ids))|" /usr/share/webapps/cacti/lib/utility.php

# Add our stuff
ADD container-prep.sh /
ADD init-services.sh /

ENTRYPOINT ["/bin/sh", "-c", "/container-prep.sh"]