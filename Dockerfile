FROM alpine:latest

ENV CACTI_VERSION latest

# Install all the things we need to do everything.
RUN /sbin/apk --no-cache upgrade && \
	/sbin/apk --no-cache add apache2 mariadb mariadb-client php7 cacti cacti-php7 vim php7-apache2 net-snmp curl tzdata openrc cacti-setup wget patch gd php7-dom automake libtool autoconf make gawk gcc g++ distcc binutils libressl-dev mysql-dev net-snmp-dev help2man

# Move all the default configs into a backup location,
# from where they _might_ be restored later in the container startup process
# Startup scripts check for existing resources and copy in defauts if none are found
# Also sets up a few locations, resources and permisions
RUN BACKUPDIR="/root/default-configs" && \
	mkdir -p ${BACKUPDIR}/mysql && \
	mv /etc/mysql/my.cnf ${BACKUPDIR}/mysql/ && \
	mkdir -p ${BACKUPDIR}/apache && \
	mv /etc/apache2/* ${BACKUPDIR}/apache/ && \
	mkdir ${BACKUPDIR}/php7 && \
	mv /etc/php7/* ${BACKUPDIR}/php7/ && \
	mkdir -p /run/apache2 && \
	mkdir -p /run/openrc && \
	mkdir -p /usr/share/webapps/cacti/log && \
	touch /run/openrc/softlevel && \
	touch /usr/share/webapps/cacti/log/cacti.log && \
	mkdir -p /var/lib/spine/src && \
	ln -s /usr/share/webapps/cacti /var/www/localhost/htdocs/cacti && \
	mkdir -p /var/backups

# Update Cacti
# We start off with the in-distro version, in order to set up dependencies and stuff.
# Then we download and install the ${CACTI_VERSION} version of cacti on top of that.
RUN wget https://www.cacti.net/downloads/cacti-${CACTI_VERSION}.tar.gz && \
    PACKAGE_VERSION=$(tar -tf cacti-${CACTI_VERSION}.tar.gz | head -n1 | tr -d /) && \
	ln -s /usr/share/webapps/cacti /usr/share/webapps/${PACKAGE_VERSION} && \
	tar -xvf cacti-${CACTI_VERSION}.tar.gz -C /usr/share/webapps && \
	chown -R cacti:cacti /usr/share/webapps/cacti/ && \
	chown -R cacti:cacti /var/lib/cacti/ && \
	chown -R apache:apache /usr/share/webapps/cacti/cache/ && \
	chown -R apache:apache /usr/share/webapps/cacti/resource/ && \
	chown -R apache:apache /usr/share/webapps/cacti/scripts/ && \
	chown -R apache:apache /var/log/cacti/

# Download and install spine.
# Naturally, spine's version is locked to cacti's version
# https://www.cacti.net/downloads/docs/html/unix_configure_spine.html
RUN cd /var/lib/spine/src && \
	wget http://www.cacti.net/downloads/spine/cacti-spine-${CACTI_VERSION}.tar.gz && \
	PACKAGE_VERSION=$(tar -tf cacti-spine-${CACTI_VERSION}.tar.gz | head -n1 | tr -d /) && \
	tar -zxvf cacti-spine-${CACTI_VERSION}.tar.gz && \
	cd /var/lib/spine/src/${PACKAGE_VERSION}/ && \
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

# Apply a bug fix caused by PHP 7.2
RUN sed -i "s|\$ids = array()\;|\$ids = \'\'\;|" /usr/share/webapps/cacti/lib/utility.php && \
	sed -i "s|if (sizeof(\$ids))|if (strlen(\$ids))|" /usr/share/webapps/cacti/lib/utility.php

# Add our stuff
ADD container-prep /
ADD init-services /
ADD backup /
ADD restore /

ENTRYPOINT ["/container-prep"]